"""
Virtuaalinen tekstinaytto kCPU16-emulaattorille.

Naytto on muistikartattu (Memory-Mapped I/O) laite, joka lukee
sisaltonsa VRAM-muistista (Video RAM).

NAYTÖN MAARITYKSET:
-------------------
- Koko: 80 saraketta x 24 rivia = 1920 merkkia
- VRAM-alue: $F800 - $FF7F
- Jokainen sana = yksi merkki + attribuutit

SANAN RAKENNE (16-bittia):
-------------------------
Bitit 0-7:   ASCII-merkki (0-127)
Bitti 8:     Lihavointi (1 = paalla)
Bitti 9:     Kursiivi (1 = paalla)
Bitti 10:    Vilkku (1 = paalla)
Bitti 11:    Alleviivaus (1 = paalla)
Bitti 12:    Yliviivaus (1 = paalla)
Bitit 13-15: Varikoodi (0-7)
    0 = Musta
    1 = Punainen
    2 = Vihrea
    3 = Keltainen
    4 = Sininen
    5 = Magenta
    6 = Syaani
    7 = Valkoinen

MUISTIJARJESTYS:
----------------
Osoite $F800 = ruudun vasen ylanurkka (rivi 0, sarake 0)
Osoite $F801 = rivi 0, sarake 1
...
Osoite $F84F = rivi 0, sarake 79 (rivin loppu)
Osoite $F850 = rivi 1, sarake 0 (seuraava rivi)
...

Kaava: osoite = VRAM_START + (rivi * 80) + sarake
"""

from __future__ import annotations

from dataclasses import dataclass

from ..constants import SCREEN_COLS, SCREEN_ROWS, VRAM_START
from ..memory import Memory


@dataclass
class ScreenDevice:
    """
    Virtuaalinen tekstinaytto.

    Lukee VRAM-muistista merkkeja ja muuntaa ne luettavaksi tekstiksi.
    Talla hetkella toteutus nayttaa vain ASCII-merkit ilman attribuutteja.

    Attributes:
        cols: Sarakkeiden maara (oletus: 80)
        rows: Rivien maara (oletus: 24)

    Note:
        Attribuutit (vari, lihavointi jne.) eivat ole toteutettuna
        render_text-metodissa - vain merkit nakyvan.
    """

    cols: int = SCREEN_COLS  # Sarakkeet (80)
    rows: int = SCREEN_ROWS  # Rivit (24)

    def render_text(self, memory: Memory) -> str:
        """
        Renderoi nayttomuisti tekstiksi.

        Lukee VRAMin ja muuntaa jokaisen sanan ASCII-merkkiksi.
        Tulostuskelvoittomat merkit (kontrollimerkit) korvataan valilyonnilla.

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Monirivinen merkkijono (24 rivia, 80 merkkia kukin)

        Example:
            >>> screen = ScreenDevice()
            >>> mem = Memory()
            >>> mem.write(0xF800, ord('H'))  # Kirjoita 'H' vasempaan yläkulmaan
            >>> screen.render_text(mem)
            'H                                                                               \\n...'
        """
        lines: list[str] = []
        addr = VRAM_START  # Aloita nayttomuistin alusta

        # Kaydaan lapi jokainen rivi
        for _ in range(self.rows):
            chars: list[str] = []

            # Kaydaan lapi jokainen sarake rivilla
            for _ in range(self.cols):
                # Lue sana muistista
                word = memory.read(addr)

                # Pura ASCII-merkki (alimmat 8 bittia)
                ch = chr(word & 0x00FF)

                # Nayta vain tulostuskelpoiset merkit (32-126)
                # Muut korvataan valilyonnilla
                chars.append(ch if 32 <= ord(ch) < 127 else " ")

                addr += 1

            # Yhdista rivin merkit ja lisaa listaan
            lines.append("".join(chars))

        # Yhdista rivit rivinvaihdoilla
        return "\n".join(lines)
