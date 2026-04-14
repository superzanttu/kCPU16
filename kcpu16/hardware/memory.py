"""
Muistimalli kCPU16-prosessorille.

Toteuttaa 16-bittisen sana-osoitetun muistin (word-addressed memory).

MUISTIAVARUUS:
--------------
- Kokonaiskoko: 65536 sanaa (0x0000 - 0xFFFF)
- Jokainen sana on 16 bitin kokoinen
- Von Neumann -arkkitehtuuri: koodi ja data samassa muistissa

MUISTIKARTTA:
-------------
$0000 - $000F   Keskeytysvektoritaulukko (16 vektoria)
$0010 - $001A   Kello-MMIO, lue-vain (vuosi, kk, pv, tunti, min, sek, ms, uptime)
$001B           CLOCK_INT_INTERVAL: kello-MMIO, kirjoitettavissa (SCTMR-kasky)
$001C - $001F   Kello-MMIO, varattua, lue-vain
$0020           KBD_DATA:   nappaimisto-MMIO, lue-vain (pops puskurista)
$0021           KBD_STATUS: nappaimisto-MMIO, lue-vain (puskurin koko)
$0022 - $00FF   Varattu kayttojarjestelmalle
$0100 - $01FF   Bootloaderin latausalue
$0200 - $F7FF   Vapaa RAM (ohjelmat ja data)
$F800 - $FF7F   Video RAM (nayttomuisti, 80x24 = 1920 sanaa)
$FF80 - $FFFF   Kernel Stack

MUISTISUOJAUS:
--------------
Kaksi erillistako kirjoitussuojaustasoa:

1. Kayttajatilan MPR-suojaus (User mode):
   - Luku/kirjoitus sallittu vain osoitteisiin >= MPR
   - POIKKEUS: VRAM ($F800-$FF7F) on aina kirjoitettavissa
   - Rikkomus -> MemoryAccessFaultError -> INT 5

2. Kirjoitussuojatut MMIO-alueet (kaikki tilat):
   - Listattu Memory.read_only_regions -listalla
   - Sisaltaa oletuksena kello-MMIO ja nappaimisto-MMIO
   - Extensible: ROM-alueet lisataan samaan listaan
   - Rikkomus -> ReadOnlyMemoryError -> INT 5

HUOM: KBD_DATA ($0020) ja KBD_STATUS ($0021) ovat lue-vain.
Kirjoittaminen niihin ei vaikuta laitteen tilaan ja laukaisee
ReadOnlyMemoryError -> INT 5. Nappaimiston hallinta tapahtuu
ainoastaan keskeytyksen (INT 6) kautta lukemalla KBD_DATA.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ..constants import (
    CLOCK_INT_INTERVAL,
    CLOCK_MMIO_END,
    CLOCK_MMIO_START,
    GFX_FLIP_REG,
    KBD_MMIO_END,
    KBD_MMIO_START,
    MEMORY_WORDS,
    RAND_MMIO,
    VRAM_END,
    VRAM_START,
    WORD_MASK,
)
from ..exceptions import MemoryAccessFaultError, ReadOnlyMemoryError


@dataclass
class Memory:
    """
    Sana-osoitettu muisti kCPU16-prosessorille.

    Muisti on yksinkertainen lista 16-bittisia arvoja. Osoitteet
    kierrautyvat automaattisesti (0xFFFF + 1 = 0x0000).

    Attributes:
        words: Lista 65536 sanaa, kukin 16-bittinen (0-0xFFFF)
    """

    # Muistitaulukko: 65536 sanaa, alustetaan nollilla
    words: list[int] = field(default_factory=lambda: [0] * MEMORY_WORDS)

    # Kirjoitussuojatut muistialueet: lista (alkuosoite, loppuosoite) -pareista.
    # Kirjoitus naalle alueille laukaisee ReadOnlyMemoryError -> INT 5.
    #
    # Oletuksena sisaltaa laitteiston MMIO-alueet:
    #   $0010-$001A  Kello-MMIO (lue-vain reaaliaikakellorekisterit)
    #   $001C-$001F  Kello-MMIO (varattua, lue-vain)
    #   $0020-$0021  Nappaimisto-MMIO (KBD_DATA, KBD_STATUS - lue-vain)
    #
    # ROM-emulointi: Lisaa ROM-alue listaan kasin latauksen jalkeen:
    #   mem.read_only_regions.append((ROM_START, ROM_END))
    #   mem.rebuild_write_mask()  # Pakollinen kutsu muutoksen jalkeen!
    # Lataus ennen suojausta: kirjoita suoraan mem.words[addr] = value
    read_only_regions: list[tuple[int, int]] = field(
        default_factory=lambda: [
            (CLOCK_MMIO_START, CLOCK_INT_INTERVAL - 1),  # $0010-$001A, kello (lue-vain)
            (CLOCK_INT_INTERVAL + 1, CLOCK_MMIO_END),  # $001C-$001F, kello varattua
            (KBD_MMIO_START, KBD_MMIO_END),  # $0020-$0021, nappaimisto (lue-vain)
        ]
    )

    # O(1)-kirjoitussuojataulukko: indeksoitu muistiosoitteella,
    # epanolla = kirjoitussuojattu. Rakennetaan __post_init__:ssa ja
    # paivitetaan rebuild_write_mask():lla aina kun read_only_regions muuttuu.
    _write_mask: bytearray = field(
        init=False,
        repr=False,
        compare=False,
        default_factory=lambda: bytearray(MEMORY_WORDS),
    )

    # MMIO-alueet, joiden yli bulk-optimoinnit eivät saa kirjoittaa/lukea
    # suoraan self.words-taulukosta, koska semantiikka kulkee CPU._read/_write_word
    # kautta (sivuvaikutukset tai laitepohjainen arvo).
    _mmio_regions: tuple[tuple[int, int], ...] = field(
        init=False,
        repr=False,
        compare=False,
        default=((CLOCK_MMIO_START, CLOCK_MMIO_END), (KBD_MMIO_START, KBD_MMIO_END)),
    )

    def __post_init__(self) -> None:
        """Initialize derived write-protection mask from configured regions."""
        self.rebuild_write_mask()

    def rebuild_write_mask(self) -> None:
        """
        Rakentaa O(1)-kirjoitussuojataulukon read_only_regions-listan perusteella.

        Kutsuttava aina, kun read_only_regions-listaa muutetaan manuaalisesti
        (esim. ROM-alueen lisaamisen jalkeen). Dataclass kutsuu tata automaattisesti
        olion luonnin yhteydessa __post_init__:ssa.
        """
        mask = self._write_mask
        mask[:] = bytearray(MEMORY_WORDS)  # Nollaa kaikki (kirjoitettavissa)
        for start, end in self.read_only_regions:
            mask[start : end + 1] = b"\x01" * (end - start + 1)

    def reset(self) -> None:
        """
        Nollaa koko muisti.

        Kaytetaan koneen kylmakaynnistyksessa. Kaikki muistipaikat
        asetetaan arvoon 0.
        """
        self.words = [0] * MEMORY_WORDS

    def read(self, addr: int) -> int:
        """
        Lue sana muistista.

        Args:
            addr: Muistiosoite (0x0000 - 0xFFFF)

        Returns:
            16-bittinen sana kyseisesta osoitteesta

        Note:
            Osoite maskataan automaattisesti 16-bittiseksi,
            joten ylivuodot kierrautyvat.
        """
        return self.words[addr & WORD_MASK]

    def write(self, addr: int, value: int) -> None:
        """
        Kirjoita sana muistiin.

        Args:
            addr: Muistiosoite (0x0000 - 0xFFFF)
            value: Kirjoitettava arvo (maskataan 16-bittiseksi)

        Raises:
            ReadOnlyMemoryError: Jos osoite on kirjoitussuojattu
                (MMIO-rekisteri tai ROM-alue, lisatty read_only_regions:iin)

        Note:
            Seka osoite etta arvo maskataan automaattisesti,
            joten ylivuodot kierrataan.
        """
        self.check_write_protected(addr)
        self.words[addr & WORD_MASK] = value & WORD_MASK

    def check_write_protected(self, addr: int) -> None:
        """
        Tarkista onko osoite kirjoitussuojattu.

        Kayttaa O(1)-maskitaulukkoa (_write_mask) nopeaan tarkistukseen.
        Virheviestin rakentamisessa kaydaan read_only_regions lapi vain
        kun rikkomus on jo havaittu (harvinainen polku).

        Args:
            addr: Tarkistettava muistiosoite

        Raises:
            ReadOnlyMemoryError: Jos osoite on kirjoitussuojattu

        Example:
            >>> mem = Memory()
            >>> mem.check_write_protected(0x0020)  # KBD_DATA -> ReadOnlyMemoryError
            >>> mem.check_write_protected(0x0200)  # RAM -> OK
        """
        masked = addr & WORD_MASK
        if not self._write_mask[masked]:
            return  # Kirjoitettavissa – normaali O(1)-polku
        # Kirjoitussuojattu – etsi alue virheviestiä varten
        for start, end in self.read_only_regions:
            if start <= masked <= end:
                raise ReadOnlyMemoryError(
                    f"Kirjoitus kirjoitussuojattuun osoitteeseen ${masked:04X} "
                    f"(suojattu alue ${start:04X}-${end:04X})"
                )
        # Fallback (ei pitaisi tapahtua jos rebuild_write_mask on kutsuttu)
        raise ReadOnlyMemoryError(
            f"Kirjoitus kirjoitussuojattuun osoitteeseen ${masked:04X}"
        )

    @staticmethod
    def check_user_access(addr: int, mpr: int) -> None:
        """
        Tarkista onko User-tilalla oikeus kayttaa annettua osoitetta.

        User-tilassa (P=0) muistikaytto on rajoitettua:
        - Osoitteet >= MPR ovat sallittuja
        - VRAM ($F800-$FF7F) on AINA sallittu (poikkeus)
        - Osoitteet < MPR aiheuttavat virheen

        Args:
            addr: Tarkistettava muistiosoite
            mpr: MPR-rekisterin nykyinen arvo (muistin alaraja)

        Raises:
            MemoryAccessFaultError: Jos osoite on suojattu

        Example:
            >>> Memory.check_user_access(0x0050, 0x0100)  # heittaa virheen
            >>> Memory.check_user_access(0xF800, 0x0100)  # OK (VRAM)
            >>> Memory.check_user_access(0x1000, 0x0100)  # OK (>= MPR)
        """
        addr &= WORD_MASK

        # Poikkeus: VRAM on aina sallittu kayttajaohjelmille
        # (mahdollistaa nayton paivittamisen ilman syscallia)
        if VRAM_START <= addr <= VRAM_END:
            return

        # Suojattu alue: osoitteet alle MPR:n
        if addr < (mpr & WORD_MASK):
            raise MemoryAccessFaultError(f"User mode memory fault at {addr:04X}")

    def load_words(self, start_addr: int, data: list[int]) -> None:
        """
        Lataa sanalista muistiin perakkaisiin osoitteisiin.

        Kaytetaan tyypillisesti ohjelman lataamiseen muistiin
        (esim. assembler-tuloste tai bootloaderin data).

        Args:
            start_addr: Ensimmaisen sanan osoite
            data: Lista 16-bittisia sanoja ladattavaksi

        Example:
            >>> mem = Memory()
            >>> mem.load_words(0x0100, [0x0001, 0x0000, 0x000A])  # LOAD R0, 10
            >>> mem.read(0x0100)
            1  # opcode: LOAD
            >>> mem.read(0x0102)
            10  # operandi: 10
        """
        addr = start_addr & WORD_MASK
        for word in data:
            self.write(addr, word)
            addr = (addr + 1) & WORD_MASK  # Kierratetaan osoite

    # ------------------------------------------------------------------
    # MMIO-aware aluekyselyt (Vaihe 4 memory API clarity layer)
    # ------------------------------------------------------------------

    def is_mmio_address(self, addr: int) -> bool:
        """Tarkista kuuluuko osoite MMIO-semanttiseen alueeseen.

        Huomaa: `RAND_MMIO` ja `GFX_FLIP_REG` ovat yksittäisosoitteita,
        jotka käsitellään myös MMIO-semanttisina osoitteina.
        """
        masked = addr & WORD_MASK
        if masked == RAND_MMIO or masked == GFX_FLIP_REG:
            return True
        for start, end in self._mmio_regions:
            if start <= masked <= end:
                return True
        return False

    def ranges_overlap_mmio(self, ranges: tuple[tuple[int, int], ...]) -> bool:
        """Tarkista leikkaako jokin lineaarinen [start,end]-jakso MMIO-osoitteita.

        Tämä on tarkoitettu COPY/FILL-fastpathien suojaksi: jos alue osuu MMIO:hon,
        pitää käyttää MMIO-aware luku/kirjoituspolkua eikä suoraa words-sliceä.
        """
        for seg_start, seg_end in ranges:
            for mmio_start, mmio_end in self._mmio_regions:
                if seg_start <= mmio_end and seg_end >= mmio_start:
                    return True
            if seg_start <= RAND_MMIO <= seg_end:
                return True
            if seg_start <= GFX_FLIP_REG <= seg_end:
                return True
        return False
