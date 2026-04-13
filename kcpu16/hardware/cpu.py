"""
CPU-ydin kCPU16-prosessorille.

Toteuttaa prosessorin Fetch-Decode-Execute -syklin ja kaikkien
kaskyjen suorituslogiikan.

SUORITUSSYKLI:
--------------
1. FETCH: Lue kasky muistista PC:n osoitteesta
2. PRIVILEGE CHECK: Tarkista kaskyoikeudet (Kernel vs. User)
3. MEMORY CHECK: Tarkista muistiviittausten laillisuus
4. EXECUTE: Suorita kasky
5. PC UPDATE: Siirra PC seuraavaan kaskyyn

KESKEYTUSTEN KASITTELY:
-----------------------
Kun virhe tapahtuu (esim. InvalidOpcode), CPU:
1. Tallentaa PC:n ja SR:n pinoon (PUSH PC, PUSH SR)
2. Siirtyy Kernel-tilaan (P=1)
3. Estaa keskeytykset (I=0)
4. Hakee kasittelijan osoitteen vektorista ja hyppaa sinne

REKISTERIEN KOODAUS:
--------------------
Operandeissa rekisterit koodataan indekseilla 0-5:
    0 = R0, 1 = R1, 2 = R2, 3 = R3, 4 = FP, 5 = SP
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from ..constants import (
    INT_CLOCK,
    INT_KEYBOARD,
    INT_TIMER,
    INT_VECTOR_COUNT,
    INT_VECTOR_BASE,
    RAND_LFSR_SEED,
    REG_IDX_MASK,
    SR_FLAG_I,
    SR_FLAG_P,
    MODE_KERNEL,
    WORD_MASK,
)
from ..exceptions import (
    InvalidOpcodeError,
    ReadOnlyMemoryError,
    StackOverflowError,
)
from .cpu_core import CPUCoreMixin, _TMR_DISABLED
from .cpu_exec import CPUEXecMixin
from .cpu_memcheck import CPUMemCheckMixin
from .cpu_mmio import CPUMMIOMixin
from .memory import Memory


from .registers import RegisterFile

# TYPE_CHECKING-lohko estaa syklisen importin ajonaikana
if TYPE_CHECKING:
    from .devices.storage import BlockStorageDevice
    from .devices.keyboard import KeyboardDevice
    from .devices.screen import ScreenDevice


@dataclass
class CPU(CPUCoreMixin, CPUEXecMixin, CPUMemCheckMixin, CPUMMIOMixin):
    """
    kCPU16-prosessorin ydin.

    Toteuttaa suoritussyklin ja kaikkien kaskyjen logiikan.

    Attributes:
        memory: Muistiolio (65536 sanaa)
        regs: Rekisteritiedosto (R0-R3, FP, SP, PC, SR, MPR, TMR)
        storage: Tallennuslaite DREAD/DWRITE-kaskyjä varten (valinnainen)
        halted: True jos HALT-kasky suoritettu
        instruction_counter: Suoritettujen kaskyjen laskuri
        process_exit_requested: True jos EXIT-kasky suoritettu
    """

    memory: Memory  # Paamuisti
    regs: RegisterFile  # Rekisterit
    storage: "BlockStorageDevice | None" = None  # Tallennuslaite (valinnainen)
    keyboard: "KeyboardDevice | None" = None  # Nappaimistolaite (valinnainen)
    screen: "ScreenDevice | None" = None  # Nayttolaite (valinnainen)

    halted: bool = False  # Onko kone pysahtynyt (HALT)?
    instruction_counter: int = 0  # Suoritettujen kaskyjen maara
    process_exit_requested: bool = False  # Onko EXIT kutsuttu?

    # Valinnainen hook: kutsutaan atomisesti kun CPU kirjoittaa GFX_FLIP_REG:iin
    # (arvo != 0). Machine asettaa tämän renderoimaan VRAMin etupuskuriin
    # juuri sillä hetkellä kun kehys on valmis — ennen kuin gfx_clear tyhjentää sen.
    flip_callback: object = field(default=None, init=False, repr=False)

    _uptime_counter: int = field(default=0, init=False)

    # Simuloitu suoritusaika mikrosekunteina (kertyy käskyjen suoritussykleistä)
    _simulated_time_us: int = field(default=0, init=False)
    # Seuraava simuloitu aika (µs) jolloin TMR-keskeytys laukeaa
    # (_TMR_DISABLED = ajastin poissa päältä, ei koskaan laukea)
    _next_tmr_time_us: int = field(default=_TMR_DISABLED, init=False)
    # Seuraava simuloitu aika (µs) jolloin CTMR-keskeytys laukeaa
    _next_ctmr_time_us: int = field(default=_TMR_DISABLED, init=False)

    # 16-bittinen Galois LFSR satunnaislukugeneraattorille ($0022)
    _lfsr: int = field(default=RAND_LFSR_SEED, init=False)
    _clock_snapshot: datetime | None = field(default=None, init=False)
    _clock_snapshot_sim_us: int = field(default=-1, init=False)

    # ==========================================================================
    # MUISTITARKISTUSMETODIT (yhdistetty handler-metadataan, Task 3)
    # Kukin metodi tarkistaa yhden käskytyypin muistiviittauksen.
    # Privilege-tarkistus tehdään step():ssä opcode-bitin perusteella.
    # ==========================================================================

    @staticmethod
    def _iter_fill_ranges(start: int, end: int) -> tuple[tuple[int, int], ...]:
        """Palauta FILL-alue 1-2 lineaarisena [start,end]-jaksona (sis. rajat)."""
        if start <= end:
            return ((start, end),)
        return ((start, WORD_MASK), (0, end))

    @staticmethod
    def _iter_copy_dest_ranges(
        dst_start: int, length: int
    ) -> tuple[tuple[int, int], ...]:
        """Palauta COPY-kohdealue lineaarisina [start,end]-jaksoina (sis. rajat)."""
        dst_start &= WORD_MASK
        length &= WORD_MASK
        if length <= 0:
            return ()
        dst_end = (dst_start + length - 1) & WORD_MASK
        if dst_start <= dst_end:
            return ((dst_start, dst_end),)
        return ((dst_start, WORD_MASK), (0, dst_end))

    # ==========================================================================
    # KESKEYTYSTEN KASITTELY
    # ==========================================================================

    def _trigger_interrupt(self, int_no: int) -> None:
        """
        Aktivoi keskeytys.

        Keskeytyksen aktivointi (atominen operaatio):
        1. PUSH PC (nykyinen ohjelmalaskuri)
        2. PUSH SR (nykyiset tilaliput)
        3. P = 1 (siirry Kernel-tilaan)
        4. I = 0 (esta lisäkeskeytykset)
        5. PC = [vektori] (hae kasittelijan osoite)

        Args:
            int_no: Keskeytyksen numero (0-8)
        """
        int_no &= WORD_MASK

        # Laske vektoriosoite (kierrattamalla jos numero liian iso)
        vector_addr = (INT_VECTOR_BASE + (int_no % INT_VECTOR_COUNT)) & WORD_MASK

        # Tallenna nykyinen tila pinoon
        self._push(self.regs.pc)
        self._push(self.regs.sr)

        # Siirry Kernel-tilaan ja esta keskeytykset
        self.regs.set_flag(SR_FLAG_P, MODE_KERNEL)  # P = 1 (Kernel Mode)
        self.regs.set_flag(SR_FLAG_I, 0)  # I = 0 (keskeytykset pois)

        # Hae kasittelijan osoite vektorista ja aseta PC
        self.regs.pc = self.memory.read(vector_addr)

    def _handle_timer_interrupt_if_needed(self) -> None:
        """
        Tarkista ja laukaise ajastinkeskeytys tarvittaessa.

        Ajastinkeskeytys (INT 7) laukeaa kun:
        - TMR > 0 (ajastin on paalla)
        - I = 1 (keskeytykset ovat sallitut)
        - Simuloitu aika on saavuttanut seuraavan laukaisuhetken
        """
        # TMR = 0 tarkoittaa etta ajastin on pois paalta
        if self.regs.tmr == 0:
            return

        # Keskeytykset on estettava ->  ei laukaista
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return

        # Laukaise kun simuloitu aika on ylittanyt seuraavan laukaisuhetken
        if self._simulated_time_us >= self._next_tmr_time_us:
            # Etene tarkasti TMR µs eteenpain (ei ajaudu hyvalla)
            self._next_tmr_time_us += self.regs.tmr
            self._trigger_interrupt(INT_TIMER)

    def _update_uptime_if_needed(self) -> None:
        """Paivita 32-bittinen sekuntilaskuri simuloidun ajan perusteella."""
        self._uptime_counter = (self._simulated_time_us // 1_000_000) & 0xFFFFFFFF

    def _handle_keyboard_interrupt_if_needed(self) -> None:
        """
        Tarkista ja laukaise nappaimistokeskeytys tarvittaessa.

        Nappaimistokeskeytys (INT 6) laukeaa kun:
        - Nappaimistolaitteella on odottava keskeytys (take_interrupt() == True)
        - I = 1 (keskeytykset ovat sallitut)

        Keskeytysrutiini lukee tapahtuman KBD_DATA ($0020) MMIO-osoitteesta.
        """
        if self.keyboard is None:
            return
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return
        if self.keyboard.take_interrupt():
            self._trigger_interrupt(INT_KEYBOARD)

    def _handle_clock_interrupt_if_needed(self) -> None:
        """Laukaise kellokeskeytys (INT 9) jos CTMR > 0 ja simuloitu aika on saavutettu.

        Kellokeskeytys laukeaa kun:
        - CTMR > 0 (ms-ajastin paalla)
        - I = 1 (keskeytykset sallittu)
        - Simuloitu aika on saavuttanut seuraavan laukaisuhetken
        """
        if self.regs.ctmr == 0:
            return
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return
        if self._simulated_time_us >= self._next_ctmr_time_us:
            # Etene tarkasti CTMR ms eteenpain (ei ajaudu hyvan)
            self._next_ctmr_time_us += self.regs.ctmr * 1000
            self._trigger_interrupt(INT_CLOCK)

    # ==========================================================================
    # PINOOPERAATIOT
    # ==========================================================================

    def _push(self, value: int) -> None:
        """
        Tallenna arvo pinoon.

        Pino kasvaa alaspain (push vahentaa SP:ta):
        1. [SP] = value (kirjoita nykyinen arvo)
        2. SP = SP - 1 (siirra osoitinta alas)

        Args:
            value: Tallennettava 16-bittinen arvo

        Raises:
            StackOverflowError: Jos SP menee MPR:n alle User-tilassa
        """
        try:
            self.memory.write(self.regs.sp, value)
        except ReadOnlyMemoryError:
            raise StackOverflowError(
                f"Pino törmäsi kirjoitussuojattuun osoitteeseen SP=0x{self.regs.sp:04X}"
            )
        self.regs.sp = (self.regs.sp - 1) & WORD_MASK

        # Tarkista pinon ylivuoto User-tilassa
        if not self.regs.in_kernel_mode and self.regs.sp < self.regs.mpr:
            raise StackOverflowError("User stack overflow")

    def _pop(self) -> int:
        """
        Hae arvo pinosta.

        Pino pienenee ylospain (pop kasvattaa SP:ta):
        1. SP = SP + 1 (siirra osoitinta ylos)
        2. Palauta [SP] (lue arvo)

        Returns:
            16-bittinen arvo pinon huipulta
        """
        self.regs.sp = (self.regs.sp + 1) & WORD_MASK
        return self.memory.read(self.regs.sp)

    # ==========================================================================
    # REKISTERIEN KASITTELY
    # ==========================================================================

    def _get_reg(self, encoded: int) -> int:
        """
        Lue rekisterin arvo koodatun indeksin perusteella.

        Rekisterikoodaus (5 alinta bittia):
            0-15 = R0-R15, 16 = FP, 17 = SP

        Args:
            encoded: Koodattu rekisteri-indeksi

        Returns:
            Rekisterin 16-bittinen arvo

        Raises:
            InvalidOpcodeError: Jos indeksi on 18-31 (varattu)
        """
        idx = encoded & REG_IDX_MASK
        if idx < 18:
            return self._reg_array[idx]
        raise InvalidOpcodeError(f"Invalid register index: {idx}")

    def _set_reg(self, encoded: int, value: int) -> None:
        """
        Aseta rekisterin arvo koodatun indeksin perusteella.

        Args:
            encoded: Koodattu rekisteri-indeksi (0-17)
            value: Asetettava arvo (maskataan 16-bittiseksi)

        Raises:
            InvalidOpcodeError: Jos indeksi on 18-31 (varattu)
        """
        idx = encoded & REG_IDX_MASK
        if idx < 18:
            self._reg_array[idx] = value & WORD_MASK
            return
        raise InvalidOpcodeError(f"Invalid register index: {idx}")
