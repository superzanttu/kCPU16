"""
Korkeantason konewrapper kCPU16-emulaattorille.

Yhdistaa kaikki komponentit (CPU, muisti, laitteet) yhdeksi
helppokattoiseksi rajapinnaksi. Tama on paaluokka, jota
komentoriviliittyma ja muut ulkoiset kutsujat kayttavat.

KAYTTOTAPA:
-----------
    from kcpu16 import KCPU16Machine

    machine = KCPU16Machine()
    machine.cold_reset()
    machine.load_program([0x0001, 0x0000, 0x002A])  # LOAD R0, 42
    machine.run()
    print(machine.dump_registers())

KOMPONENTIT:
------------
- Memory: 64K sanan paamuisti
- RegisterFile: CPU:n rekisterit
- CPU: Fetch-Decode-Execute -ydin
- ScreenDevice: Tekstinaytto (VRAM)
- KeyboardDevice: Nappaimistopuskuri
- BlockStorageDevice: Levylaite (boot + tallennua)

BOOT-PROSESSI:
--------------
1. cold_reset(): Nollaa muisti ja rekisterit
2. boot_from_storage(): Kopioi sektori 0 -> RAM 0x0100
3. run(): Aloita suoritus PC:n osoitteesta
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ..constants import BOOT_RAM_START, VRAM_END, VRAM_START, WORD_MASK
from .cpu import CPU
from .devices import BlockStorageDevice, KeyboardDevice, ScreenDevice
from .memory import Memory
from .registers import RegisterFile


@dataclass
class KCPU16Machine:
    """
    kCPU16 virtuaalikone - yhdistää kaikki komponentit.

    KCPU16Machine on "taysi tietokone": CPU, muisti, naytto,
    nappaimisto ja levylaite yhdessa. Tarjoaa helpon rajapinnan
    ohjelmien lataamiseen ja ajamiseen.

    Attributes:
        memory: Paamuisti (65536 sanaa)
        regs: Rekisteritiedosto
        storage: Tallennuslaite (boot + data)
        keyboard: Nappaimistolaite
        screen: Nayttolaite
        cpu: Prosessoriydin (luodaan automaattisesti)

    Example:
        >>> machine = KCPU16Machine()
        >>> machine.load_program([0x0044])  # HALT
        >>> machine.run()
        >>> machine.cpu.halted
        True
    """

    # Komponentit (luodaan oletusarvoisina)
    memory: Memory = field(default_factory=Memory)
    regs: RegisterFile = field(default_factory=RegisterFile)
    storage: BlockStorageDevice = field(default_factory=BlockStorageDevice)
    keyboard: KeyboardDevice = field(default_factory=KeyboardDevice)
    screen: ScreenDevice = field(default_factory=ScreenDevice)

    # CPU luodaan __post_init__:ssa koska se tarvitsee memory ja regs
    cpu: CPU = field(init=False)

    def __post_init__(self) -> None:
        """
        Alustus dataclassin luonnin jalkeen.

        Luo CPU:n ja yhadistaa sen muistiin, rekistereihin
        ja tallennuslaitteeseen.
        """
        self.cpu = CPU(
            memory=self.memory,
            regs=self.regs,
            storage=self.storage,
            keyboard=self.keyboard,
            screen=self.screen,
        )
        # Yhdistä kaksoisbufferoinnin flip-hook: renderoi VRAM → etupuskuri
        # välittömästi kun CPU kirjoittaa GFX_FLIP_REG:iin, jolloin VRAM
        # on vielä täysin piirretty eikä gfx_clear ole vielä päässyt poistamaan sitä.
        self.cpu.flip_callback = self._on_gfx_flip

    def _on_gfx_flip(self) -> None:
        """Atominen flip: renderoi nykyinen VRAM etupuskuriin.

        Kutsutaan suoraan CPU._write_word():stä samassa säikkeessä kuin CPU:n
        suoritus, juuri ennen kuin ohjelman seuraava käsky suoritetaan.
        Tämä takaa että VRAMissa on täydellinen kehys ilman repeytymiä.
        """
        self.screen.capture_front_vram(self.memory)
        rendered = self.screen.render_auto(self.memory)
        self.screen.set_front_buffer(rendered)

    def cold_reset(self) -> None:
        """
        Kylmakaynnista kone (cold boot).

        Nollaa kaiken:
        - Muisti nollataan (kaikki sanat = 0)
        - CPU nollataan (rekisterit, liput, tilat)
        - PC asetetaan 0x0100:een (bootloaderin alku)
        - Kernel Mode paalle, keskeytykset pois
        """
        self.memory.reset()
        self.cpu.reset()
        self.screen.clear_front_buffer()
        self.screen.reset_vram_version()

    def reset_for_test(self) -> None:
        """
        Alusta kone testiajon varten.

        Nollaa muistin ja rekisterit ilman boot-prosessia:
        - EI lue tallennuslaitteelta mitaan
        - EI kutsu boot_from_storage()
        - Muisti nollataan (kaikki sanat = 0)
        - CPU nollataan (rekisterit, liput, tilat)
        - Kernel Mode paalle, keskeytykset pois

        Kayta tata testrunnerissa cold_reset():in sijaan jotta
        boot-logiikka ei vahingossa kaynnisty.
        """
        self.memory.reset()
        self.cpu.reset()
        self.screen.clear_front_buffer()
        self.screen.reset_vram_version()

    def boot_from_storage(self) -> None:
        """
        Kaynnnista kone lataamalla bootloader tallennuslaitteelta.

        Simuloi todellista kaynnistysta:
        1. Lue tallennuslaitteen sektori 0 (256 sanaa)
        2. Kopioi se RAM-osoitteisiin $0100-$01FF
        3. Aseta PC = $0100 ja aloita suoritus

        Note:
            Tallennuslaitteelle pitaa ensin kirjoittaa bootloader-koodi!
        """
        # Lue ensimmainen blokki (sektori 0)
        boot_words = self.storage.read_block(0)
        # Kopioi boot-alueelle muistiin
        self.memory.load_words(BOOT_RAM_START, boot_words)
        # Aseta PC osoittamaan boot-alueen alkuun
        self.regs.pc = BOOT_RAM_START

    def load_program(self, words: list[int], start_addr: int = BOOT_RAM_START) -> None:
        """
        Lataa ohjelma muistiin ja aseta PC.

        Tama on suora tapa ladata ohjelmia ilman boot-prosessia.
        Kaytannollinen testaukseen ja REPL:n kayttoon.

        Args:
            words: Lista 16-bittisia sanoja (konekielikoodi)
            start_addr: Aloitusosoite muistissa (oletus: 0x0100)

        Example:
            >>> machine.load_program([0x0001, 0x0000, 0x000A])  # LOAD R0, 10
            >>> machine.run()
            >>> machine.regs.r0
            10
        """
        self.memory.load_words(start_addr, words)
        self.regs.pc = start_addr

    def load_segments(self, segments: list[tuple[int, list[int]]]) -> None:
        """
        Lataa useampi muistisegmentti kerralla ja aseta PC.

        Kayttotapaus: Assembler tuottaa useampia erillisia muistilohkoja
        .at-direktiivilla (esim. koodi RAM:iin, alustudata VRAMiin).
        PC asetetaan ensimmaisen segmentin aloitusosoitteeseen.

        Args:
            segments: Lista (aloitusosoite, sanat) -pareista.

        Example:
            >>> machine.load_segments([(0x0200, [0x0044]), (0xF800, [0xE041])])
        """
        if not segments:
            return
        for seg_addr, seg_words in segments:
            self.memory.load_words(seg_addr, seg_words)
        self.regs.pc = segments[0][0]

    def run(self, max_cycles: int | None = None) -> None:
        """
        Aja ohjelmaa kunnes pysaytysehto tayttyy.

        Pysaytysehdot:
        - HALT-kasky suoritettu
        - EXIT-kasky suoritettu
        - max_cycles-raja saavutettu (jos annettu)

        Args:
            max_cycles: Maksimi kaskyjen maara.
                        None (oletus) = ei rajaa, aja kunnes HALT tai EXIT.
        """
        self.cpu.run(max_cycles=max_cycles)

    def step(self) -> None:
        """
        Suorita yksi kasky.

        Kaytannollinen debuggaukseen - mahdollistaa kaskyn-kerrallaan
        suorituksen.
        """
        self.cpu.step()

    def dump_registers(self) -> dict[str, int]:
        """
        Palauta kaikkien rekisterien arvot sanakirjana.

        Returns:
            dict: Rekisterinimet avaimina, arvot 16-bittisina kokonaislukuina

        Example:
            >>> machine.dump_registers()
            {'R0': 0, 'R1': 0, 'R2': 0, 'R3': 0, 'FP': 0, 'SP': 65535,
             'PC': 256, 'SR': 0, 'MPR': 256, 'TMR': 0}
        """
        return {
            "R0": self.regs.r0,
            "R1": self.regs.r1,
            "R2": self.regs.r2,
            "R3": self.regs.r3,
            "R4": self.regs.r4,
            "R5": self.regs.r5,
            "R6": self.regs.r6,
            "R7": self.regs.r7,
            "R8": self.regs.r8,
            "R9": self.regs.r9,
            "R10": self.regs.r10,
            "R11": self.regs.r11,
            "R12": self.regs.r12,
            "R13": self.regs.r13,
            "R14": self.regs.r14,
            "R15": self.regs.r15,
            "FP": self.regs.fp,
            "SP": self.regs.sp,
            "PC": self.regs.pc,
            "SR": self.regs.sr,
            "MPR": self.regs.mpr,
            "TMR": self.regs.tmr,
            "CTMR": self.regs.ctmr,
        }

    @property
    def process_exited(self) -> bool:
        """
        Tarkista onko prosessi lopetettu EXIT-kaskylla.

        Returns:
            True jos EXIT suoritettu, False muuten
        """
        return self.cpu.process_exit_requested

    def render_screen(self) -> str:
        """
        Palauta naytan sisalto merkkijonona.

        Lukee VRAM-muistin ja muuntaa sen 80x24 tekstiruudukoksi.
        Jokainen sana tulkataan ASCII-merkkina (alimmat 8 bittia).

        Returns:
            str: 24 rivia, kukin 80 merkkia, erotettuna rivinvaihdoilla
        """
        return self.screen.render_text(self.memory)

    def clear_screen_memory(self, value: int = 0) -> None:
        """
        Tyhjenna nayttomuisti.

        Kirjoittaa annetun arvon kaikkiin VRAM-osoitteisiin.
        Oletus (0) nayttaa tyhjina valikoinneina.

        Args:
            value: Kirjoitettava arvo (oletus: 0, tyjha)
        """
        v = value & WORD_MASK
        for addr in range(VRAM_START, VRAM_END + 1):
            self.memory.write(addr, v)
