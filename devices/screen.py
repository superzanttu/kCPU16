"""
Virtuaalinen tekstinaytto kCPU16-emulaattorille.

Naytto on muistikartattu (Memory-Mapped I/O) laite, joka lukee
sisaltonsa VRAM-muistista (Video RAM).

NAYTON MAARITYKSET:
-------------------
- Koko: 80 saraketta x 24 rivia = 1920 merkkia
- VRAM-alue: $F800 - $FF7F
- Jokainen sana = yksi merkki + värit + attribuutit

SANAN RAKENNE (16-bittia):
-------------------------
Bitit 0-7:    ASCII-merkki (0-127)
Bitit 8-10:   Edusta-väri (FG, 3 bittiä = 8 väriä)
    0 = Musta       4 = Sininen
    1 = Punainen    5 = Magenta
    2 = Vihrea      6 = Syaani
    3 = Keltainen   7 = Valkoinen
Bitit 11-13:  Tausta-väri (BG, 3 bittiä = 8 väriä, sama paletti)
Bitti 14:     Lihavointi (1 = paalla)
Bitti 15:     Vilkkuminen (1 = paalla)

Oletusarvo: pelkkä ASCII-merkki (esim. 0x0041 = 'A') näytetään
valkoisena tekstinä mustalla pohjalla (FG=0 tulkitaan valkoisena
kun merkki on ei-tyhjä, jotta ohjelmoijan ei tarvitse asettaa väriä).

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

from ..constants import (
    COLOR_BLACK,
    COLOR_BLUE,
    COLOR_CYAN,
    COLOR_GREEN,
    COLOR_MAGENTA,
    COLOR_RED,
    COLOR_WHITE,
    COLOR_YELLOW,
    SCREEN_COLS,
    SCREEN_ROWS,
    VRAM_START,
    VRAM_CHAR_MASK,
    VRAM_FG_MASK,
    VRAM_FG_SHIFT,
    VRAM_BG_MASK,
    VRAM_BG_SHIFT,
    VRAM_ATTR_BOLD,
    VRAM_ATTR_BLINK,
)
from ..memory import Memory

# Värien mappaus Rich-värikoodeihin
_COLOR_MAP = {
    COLOR_BLACK: "black",
    COLOR_RED: "red",
    COLOR_GREEN: "green",
    COLOR_YELLOW: "yellow",
    COLOR_BLUE: "blue",
    COLOR_MAGENTA: "magenta",
    COLOR_CYAN: "cyan",
    COLOR_WHITE: "white",
}


@dataclass
class ScreenDevice:
    """
    Virtuaalinen tekstinaytto.

    Lukee VRAM-muistista merkkeja ja muuntaa ne luettavaksi tekstiksi.

    Attributes:
        cols: Sarakkeiden maara (oletus: 80)
        rows: Rivien maara (oletus: 24)
    """

    cols: int = SCREEN_COLS  # Sarakkeet (80)
    rows: int = SCREEN_ROWS  # Rivit (24)

    def render_text(self, memory: Memory) -> str:
        """
        Renderoi nayttomuisti tekstiksi ilman värejä.

        Lukee VRAMin ja muuntaa jokaisen sanan ASCII-merkkiksi.
        Tulostuskelvoittomat merkit (kontrollimerkit) korvataan valilyonnilla.

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Monirivinen merkkijono (24 rivia, 80 merkkia kukin)
        """
        lines: list[str] = []
        addr = VRAM_START

        for _ in range(self.rows):
            chars: list[str] = []
            for _ in range(self.cols):
                word = memory.read(addr)
                ch = chr(word & VRAM_CHAR_MASK)
                chars.append(ch if 32 <= ord(ch) < 127 else " ")
                addr += 1
            lines.append("".join(chars))

        return "\n".join(lines)

    def extract_char_with_attrs(self, word: int) -> tuple[str, int, int, bool, bool]:
        """
        Erota VRAM-sanasta merkki, värit ja attribuutit.

        Args:
            word: 16-bittinen VRAM-sana

        Returns:
            Tuple: (merkki, fg_väri, bg_väri, bold, blink)
                - merkki: str (ASCII-merkki)
                - fg_väri: int (0-7)
                - bg_väri: int (0-7)
                - bold: bool
                - blink: bool
        """
        ch = chr(word & VRAM_CHAR_MASK)
        fg = (word & VRAM_FG_MASK) >> VRAM_FG_SHIFT
        bg = (word & VRAM_BG_MASK) >> VRAM_BG_SHIFT
        bold = bool(word & VRAM_ATTR_BOLD)
        blink = bool(word & VRAM_ATTR_BLINK)
        return ch, fg, bg, bold, blink

    def render_with_rich_colors(self, memory: Memory) -> str:
        """
        Renderoi VRAM Rich-tekstiksi väreillä ja attribuuteilla.

        Kun pelkkä ASCII-merkki kirjoitetaan VRAM:iin (FG=0, BG=0),
        se näytetään oletuksena valkoisena mustalla pohjalla.

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Rich-muotoiltu merkkijono väreillä
        """
        lines: list[str] = []
        addr = VRAM_START

        for _ in range(self.rows):
            row_text = ""

            for _ in range(self.cols):
                word = memory.read(addr)
                ch, fg, bg, bold, blink = self.extract_char_with_attrs(word)

                # Korvaa tulostuskelvoittomat merkit
                if not (32 <= ord(ch) < 127):
                    ch = " "

                # Oletusväri: jos pelkkä ASCII ilman värimäärittelyä,
                # näytä valkoisena mustalla pohjalla
                if fg == 0 and bg == 0 and ch != " ":
                    fg = COLOR_WHITE

                fg_color = _COLOR_MAP.get(fg, "white")
                bg_color = _COLOR_MAP.get(bg, "black")

                # Attribuutit
                style = "bold" if bold else "normal"

                rich_tag = f"[{style} on {bg_color} {fg_color}]"
                row_text += f"{rich_tag}{ch}[/]"

                addr += 1

            lines.append(row_text)

        return "\n".join(lines)
