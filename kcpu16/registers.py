"""
Rekisteritiedosto (Register File) kCPU16-prosessorille.

Sisaltaa kaikki prosessorin rekisterit ja niiden kasittelymetodit.

REKISTERIT:
-----------
Yleiskayttoiset (General Purpose Registers, GPR):
    R0, R1, R2, R3  - 16-bittiset datarekisterit laskutoimituksiin

Erikoisrekisterit:
    FP  - Frame Pointer: Aliohjelman pinokehyksen pohja
    SP  - Stack Pointer: Osoittaa pinon huipulle (pino kasvaa alaspain)
    PC  - Program Counter: Seuraavan suoritettavan kaskyn osoite
    SR  - Status Register: Tilaliput (Z, N, C, V, I, P)

Jarjestelmarekisterit:
    MPR - Memory Protection Register: User-muistin alaraja
    TMR - Timer Register: Ajastinkeskeytyksen vali (0 = pois)

TILAREKISTERIN (SR) RAKENNE:
----------------------------
Bitti 0 (Z): Zero      - 1 jos tulos = 0
Bitti 1 (N): Negative  - 1 jos tuloksen ylin bitti = 1
Bitti 2 (C): Carry     - 1 jos etumerkiton ylivuoto
Bitti 3 (V): Overflow  - 1 jos etumerkillinen ylivuoto
Bitti 4 (I): Interrupt - 1 = keskeytykset sallittu
Bitti 5 (P): Privilege - 1 = Kernel Mode, 0 = User Mode
"""

from dataclasses import dataclass, field

from .constants import (
    BOOT_RAM_START,
    DEFAULT_CLOCK_INT_INTERVAL,
    DEFAULT_MPR,
    DEFAULT_TIMER_INTERVAL,
    KERNEL_STACK_END,
    MODE_KERNEL,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    WORD_MASK,
    WORD_SIGN_BIT,
)


def _make_default_regs() -> list:
    """Luo oletusarvoinen 18-alkioisma rekisterilista (r0-r15=0, fp=0, sp=KERNEL_STACK_END)."""
    regs = [0] * 18
    regs[17] = KERNEL_STACK_END  # sp alkuarvo
    return regs


@dataclass
class RegisterFile:
    """
    Prosessorin rekisteritiedosto.

    Sisaltaa kaikki rekisterit ja metodit niiden kasittelyyn.
    Kaynnistyksen yhteydessa reset()-metodi asettaa oletusarvot.

    Attributes:
        r0, r1, r2, r3: Yleiskayttoiset datarekisterit (0-0xFFFF)
        fp: Frame Pointer - alijohjelmakutsun pinokehyksen pohja
        sp: Stack Pointer - pinon huipun osoite (alkaa 0xFFFF, kasvaa alas)
        pc: Program Counter - seuraavan kaskyn osoite (oletus: 0x0100)
        sr: Status Register - tilaliput bittikentassa
        mpr: Memory Protection Register - User-muistin alaraja
        tmr: Timer Register - ajastinkeskeytyksen vali kaskyina
    """

    # Sisäinen lista: r0-r15 (indeksit 0-15), fp (16), sp (17)
    # CPU saa suoran viitteen tähän listaan _post_init__:ssa (_reg_array)
    _regs: list = field(default_factory=_make_default_regs, repr=False)

    # Erikoisrekisterit (eivät ole _regs-taulukossa)
    pc: int = BOOT_RAM_START  # Program Counter alkaa bootloader-alueelta
    sr: int = 0  # Status Register (liput nollaa)

    # Järjestelmärekisterit
    mpr: int = DEFAULT_MPR  # Memory Protection Register
    tmr: int = DEFAULT_TIMER_INTERVAL  # Timer Register (käskyvälikeskeytys)
    ctmr: int = DEFAULT_CLOCK_INT_INTERVAL  # Clock Timer Register (ms-väli, 0=pois)

    # Yleiskäyttöisten rekistereiden nimet (indeksitaulukon järjestyksessä)
    _gpr_names: tuple = field(
        default=(
            "R0",
            "R1",
            "R2",
            "R3",
            "R4",
            "R5",
            "R6",
            "R7",
            "R8",
            "R9",
            "R10",
            "R11",
            "R12",
            "R13",
            "R14",
            "R15",
        ),
        init=False,
    )

    # --- Properties: julkinen rajapinta r0-r15, fp, sp ---
    # Kaikki lukevat/kirjoittavat suoraan _regs-listaan.
    # CPU käyttää samaa listaa _reg_array-viitteen kautta (O(1)-indeksointi).

    @property
    def r0(self) -> int:
        return self._regs[0]

    @r0.setter
    def r0(self, v: int) -> None:
        self._regs[0] = v

    @property
    def r1(self) -> int:
        return self._regs[1]

    @r1.setter
    def r1(self, v: int) -> None:
        self._regs[1] = v

    @property
    def r2(self) -> int:
        return self._regs[2]

    @r2.setter
    def r2(self, v: int) -> None:
        self._regs[2] = v

    @property
    def r3(self) -> int:
        return self._regs[3]

    @r3.setter
    def r3(self, v: int) -> None:
        self._regs[3] = v

    @property
    def r4(self) -> int:
        return self._regs[4]

    @r4.setter
    def r4(self, v: int) -> None:
        self._regs[4] = v

    @property
    def r5(self) -> int:
        return self._regs[5]

    @r5.setter
    def r5(self, v: int) -> None:
        self._regs[5] = v

    @property
    def r6(self) -> int:
        return self._regs[6]

    @r6.setter
    def r6(self, v: int) -> None:
        self._regs[6] = v

    @property
    def r7(self) -> int:
        return self._regs[7]

    @r7.setter
    def r7(self, v: int) -> None:
        self._regs[7] = v

    @property
    def r8(self) -> int:
        return self._regs[8]

    @r8.setter
    def r8(self, v: int) -> None:
        self._regs[8] = v

    @property
    def r9(self) -> int:
        return self._regs[9]

    @r9.setter
    def r9(self, v: int) -> None:
        self._regs[9] = v

    @property
    def r10(self) -> int:
        return self._regs[10]

    @r10.setter
    def r10(self, v: int) -> None:
        self._regs[10] = v

    @property
    def r11(self) -> int:
        return self._regs[11]

    @r11.setter
    def r11(self, v: int) -> None:
        self._regs[11] = v

    @property
    def r12(self) -> int:
        return self._regs[12]

    @r12.setter
    def r12(self, v: int) -> None:
        self._regs[12] = v

    @property
    def r13(self) -> int:
        return self._regs[13]

    @r13.setter
    def r13(self, v: int) -> None:
        self._regs[13] = v

    @property
    def r14(self) -> int:
        return self._regs[14]

    @r14.setter
    def r14(self, v: int) -> None:
        self._regs[14] = v

    @property
    def r15(self) -> int:
        return self._regs[15]

    @r15.setter
    def r15(self, v: int) -> None:
        self._regs[15] = v

    @property
    def fp(self) -> int:
        return self._regs[16]

    @fp.setter
    def fp(self, v: int) -> None:
        self._regs[16] = v

    @property
    def sp(self) -> int:
        return self._regs[17]

    @sp.setter
    def sp(self, v: int) -> None:
        self._regs[17] = v

    def reset(self) -> None:
        """
        Nollaa kaikki rekisterit kaynnistysarvoihin.

        Tama simuloi kylmakaynnistysta (cold boot):
        - Kaikki GPR:t nollataan
        - SP -> 0xFFFF (pinon pohja)
        - PC -> 0x0100 (bootloaderin alku)
        - Kernel Mode paalle (P=1), keskeytykset pois (I=0)
        """
        # Nollaa kaikki yleiskäyttörekisterit ja erikoisrekisterit in-place
        # (slice-sijoitus säilyttää listan identiteetin, joten CPU._reg_array-viite pysyy voimassa)
        self._regs[:] = [0] * 16 + [0, KERNEL_STACK_END]  # r0-r15=0, fp=0, sp
        self.pc = BOOT_RAM_START
        self.sr = 0
        self.mpr = DEFAULT_MPR
        self.tmr = DEFAULT_TIMER_INTERVAL
        self.ctmr = DEFAULT_CLOCK_INT_INTERVAL
        # Aseta Kernel Mode (P=1) ja deaktivoi keskeytykset (I=0)
        self.set_flag(SR_FLAG_P, MODE_KERNEL)
        self.set_flag(SR_FLAG_I, 0)

    def get_flag(self, bit: int) -> int:
        """
        Lue yksittaisen lipun arvo SR-rekisterista.

        Args:
            bit: Lipun bitti-indeksi (0-5, ks. SR_FLAG_* vakiot)

        Returns:
            1 jos lippu on asetettu, 0 muuten

        Example:
            >>> regs.get_flag(SR_FLAG_Z)  # Onko Zero-lippu paalla?
            0
        """
        return 1 if (self.sr & (1 << bit)) else 0

    def set_flag(self, bit: int, value: int) -> None:
        """
        Aseta yksittaisen lipun arvo SR-rekisteriin.

        Args:
            bit: Lipun bitti-indeksi (0-5)
            value: 0 = nollaa lippu, ei-0 = aseta lippu

        Example:
            >>> regs.set_flag(SR_FLAG_Z, 1)  # Aseta Zero-lippu
        """
        if value:
            # Aseta bitti: OR lipun maskin kanssa
            self.sr |= 1 << bit
        else:
            # Nollaa bitti: AND kaanteismaskin kanssa
            self.sr &= ~(1 << bit)
        # Varmista etta SR pysyy 16-bittisena
        self.sr &= WORD_MASK

    @property
    def in_kernel_mode(self) -> bool:
        """
        Tarkista onko CPU Kernel-tilassa.

        Returns:
            True jos P-lippu = 1 (Kernel Mode)
            False jos P-lippu = 0 (User Mode)
        """
        return bool(self.get_flag(SR_FLAG_P))

    def set_zn_flags(self, value: int) -> None:
        """
        Paivita Zero- ja Negative-liput arvon perusteella.

        Kutsutaan useimpien aritmeettisten operaatioiden jalkeen.

        Args:
            value: Operaation tulos (maskataan 16-bittiseksi)

        Toiminta:
            Z = 1 jos value == 0
            N = 1 jos value:n ylin bitti (bitti 15) = 1
        """
        value &= WORD_MASK  # Varmista 16-bittisyys
        # Zero: onko arvo nolla?
        self.set_flag(SR_FLAG_Z, 1 if value == 0 else 0)
        # Negative: onko ylin bitti 1? (bitti 15 = 0x8000)
        self.set_flag(SR_FLAG_N, 1 if (value & WORD_SIGN_BIT) else 0)

    def set_carry_overflow(self, carry: bool, overflow: bool) -> None:
        """
        Paivita Carry ja Overflow -liput.

        Args:
            carry: True jos tapahtui etumerkiton ylivuoto
                   (summa ylitti 0xFFFF tai vahennys meni negatiiviseksi)
            overflow: True jos tapahtui etumerkillinen ylivuoto
                   (positiivinen + positiivinen = negatiivinen jne.)
        """
        self.set_flag(SR_FLAG_C, 1 if carry else 0)
        self.set_flag(SR_FLAG_V, 1 if overflow else 0)
