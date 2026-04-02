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

from .constants import BOOT_RAM_START, BOOT_RAM_END, VRAM_END, VRAM_START
from .cpu import CPU
from .devices import BlockStorageDevice, KeyboardDevice, ScreenDevice
from .memory import Memory
from .registers import RegisterFile


@dataclass
class KCPU16Machine:
    """
    kCPU16 virtuaalikone - yhddistaa kaikki komponentit.

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
        self.cpu = CPU(memory=self.memory, regs=self.regs, storage=self.storage)

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

    def run(self, max_cycles: int = 1000000) -> None:
        """
        Aja ohjelmaa kunnes pysaytysehto tayttyy.

        Pysaytysehdot:
        - HALT-kasky suoritettu
        - EXIT-kasky suoritettu
        - max_cycles-raja saavutettu

        Args:
            max_cycles: Maksimi kaskyjen maara (esto ikuisille silmukoille)
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
            "FP": self.regs.fp,
            "SP": self.regs.sp,
            "PC": self.regs.pc,
            "SR": self.regs.sr,
            "MPR": self.regs.mpr,
            "TMR": self.regs.tmr,
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
        v = value & 0xFFFF
        for addr in range(VRAM_START, VRAM_END + 1):
            self.memory.write(addr, v)
