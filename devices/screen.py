# FIXME: varmista että näyttömuistin sisältö päivitetään käyttäjän näkyville ajasimella.
# FIXME: varmista että kirjoitettaessa näyttömuistiin ascii arvo, se näytetään oletuksena valkoisena tekstinä mustalla pohjalla
# FIXME: muuta värimäärittely niin, että edustavärin ja taustavärin määrittelyyn käytetään molempiin 2 bittiä.
"""
Virtuaalinen tekstinaytto kCPU16-emulaattorille.

Naytto on muistikartattu (Memory-Mapped I/O) laite, joka lukee
sisaltonsa VRAM-muistista (Video RAM).

NAYTÖN MAARITYKSET:
-------------------
- Koko: 80 saraketta x 25 rivia = 2000 merkkia
- VRAM-alue: $F800 - $FD0F
- Jokainen sana = yksi merkki + attribuutit + värit

SANAN RAKENNE (16-bittia):
-------------------------
Bitit 0-7:    ASCII-merkki (0-127)
Bitit 8-11:   Attribuutit:
              Bitti 8:   Lihavointi (1 = paalla)
              Bitti 9:   Kursiivi (1 = paalla)
              Bitti 10:  Vilkku (1 = paalla)
              Bitti 11:  Alleviivaus (1 = paalla)
Bitti 12:     Yliviivaus (1 = paalla)
Bitit 13-15:  VARATTU TULEVAISUUDELLE
Bitit 12-14:  Edusta-väri (FG, 0-7, 3 bittiä)
    0 = Musta
    1 = Punainen
    2 = Vihrea
    3 = Keltainen
    4 = Sininen
    5 = Magenta
    6 = Syaani
    7 = Valkoinen
Bitti 15:     Tausta-väri (BG, 1-bittinen)
    0 = Musta
    1 = Valkoinen

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
    VRAM_ATTR_ITALIC,
    VRAM_ATTR_BLINK,
    VRAM_ATTR_UNDERLINE,
    VRAM_ATTR_STRIKETHROUGH,
)
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
        Renderoi nayttomuisti tekstiksi ilman värejä (backwards compatibility).

        Lukee VRAMin ja muuntaa jokaisen sanan ASCII-merkkiksi.
        Tulostuskelvoittomat merkit (kontrollimerkit) korvataan valilyonnilla.

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Monirivinen merkkijono (25 rivia, 80 merkkia kukin)

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
                ch = chr(word & VRAM_CHAR_MASK)

                # Nayta vain tulostuskelpoiset merkit (32-126)
                # Muut korvataan valilyonnilla
                chars.append(ch if 32 <= ord(ch) < 127 else " ")

                addr += 1

            # Yhdista rivin merkit ja lisaa listaan
            lines.append("".join(chars))

        # Yhdista rivit rivinvaihdoilla
        return "\n".join(lines)

    def extract_char_with_attrs(self, word: int) -> tuple[str, int, int, int]:
        """
        Erota VRAM-sanasta merkki, värit ja attribuutit.

        Args:
            word: 16-bittinen VRAM-sana

        Returns:
            Tuple: (merkki, fg_väri, bg_väri, attribuutit)
                - merkki: str (ASCII-merkki)
                - fg_väri: int (0-7)
                - bg_väri: int (0-1)
                - attribuutit: int (bittikentät 8-11)
        """
        # ASCII-merkki
        ch = chr(word & VRAM_CHAR_MASK)

        # Värit
        fg = (word & VRAM_FG_MASK) >> VRAM_FG_SHIFT  # Bitit 12-14
        bg = (word & VRAM_BG_MASK) >> VRAM_BG_SHIFT  # Bitti 15

        # Attribuutit (bittikentat 8-12 - kaikki 5 attribuuttibittia)
        attrs = (word >> 8) & (VRAM_ATTR_MASK >> 8)

        return ch, fg, bg, attrs

    def render_with_rich_colors(self, memory: Memory) -> str:
        """
        Renderoi VRAM Rich-tekstiksi väreillä ja attribuuteilla (Textual/Rich-integraatio).

        Käyttää Rich-kirjaston color codes HTML-väreille ja attribuuteille.
        Tämä metodi on suunniteltu Textual TUI:n käytölle.

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Rich-muotoiltu merkkijono väreillä

        Example:
            >>> screen.render_with_rich_colors(memory)
            '[blue]H[/blue]ello...'
        """
        # Värien mappaus Rich-värikoodeihin
        color_map = {
            COLOR_BLACK: "black",
            COLOR_RED: "red",
            COLOR_GREEN: "green",
            COLOR_YELLOW: "yellow",
            COLOR_BLUE: "blue",
            COLOR_MAGENTA: "magenta",
            COLOR_CYAN: "cyan",
            COLOR_WHITE: "white",
        }

        lines: list[str] = []
        addr = VRAM_START

        for _ in range(self.rows):
            row_text = ""

            for _ in range(self.cols):
                word = memory.read(addr)
                ch, fg, bg, attrs = self.extract_char_with_attrs(word)

                # Korvaa tulostuskelvoittomat merkit
                if not (32 <= ord(ch) < 127):
                    ch = " "

                # Rakenna Rich-tag väreillä
                fg_color = color_map.get(fg, "white")
                # BG on 1-bittinen (0=musta, 1=valkoinen), mappaa Rich:lle
                bg_color = "white" if bg else "black"

                # Attribuutit
                style_attrs = []
                if attrs & (VRAM_ATTR_BOLD >> 8):  # BOLD (bitti 8)
                    style_attrs.append("bold")
                if attrs & (VRAM_ATTR_ITALIC >> 8):  # ITALIC (bitti 9)
                    style_attrs.append("italic")
                if attrs & (
                    VRAM_ATTR_BLINK >> 8
                ):  # BLINK (bitti 10) - ei suoraan Rich-tuettu
                    pass
                if attrs & (VRAM_ATTR_UNDERLINE >> 8):  # UNDERLINE (bitti 11)
                    style_attrs.append("underline")
                if attrs & (VRAM_ATTR_STRIKETHROUGH >> 8):  # STRIKETHROUGH (bitti 12)
                    style_attrs.append("strike")

                # Rakenna tag
                style_str = " ".join(style_attrs) if style_attrs else "normal"
                rich_tag = f"[{style_str} on {bg_color} {fg_color}]"
                close_tag = "[/]"

                row_text += f"{rich_tag}{ch}{close_tag}"

                addr += 1

            lines.append(row_text)

        return "\n".join(lines)
