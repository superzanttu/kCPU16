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
$0000 - $0008   Keskeytysvektoritaulukko
$0009 - $00FF   Varattu kayttojarjestelmalle
$0100 - $01FF   Bootloaderin latausalue
$0200 - $F7FF   Vapaa RAM (ohjelmat ja data)
$F800 - $FFCF   Video RAM (nayttomuisti, 80x25)
$FFD0 - $FFFF   Kernel Stack

MUISTISUOJAUS:
--------------
User-tilassa (P=0) muistikaytto on rajoitettu:
- Luku/kirjoitus sallittu vain osoitteisiin >= MPR
- POIKKEUS: VRAM ($F800-$FF7F) on aina kirjoitettavissa
  (mahdollistaa kayttajan ohjelman paivittavan nayton)
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .constants import MEMORY_WORDS, VRAM_END, VRAM_START, WORD_MASK
from .exceptions import MemoryAccessFaultError


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

        Note:
            Seka osoite etta arvo maskataan automaattisesti,
            joten ylivuodot kierrataan.
        """
        self.words[addr & WORD_MASK] = value & WORD_MASK

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
