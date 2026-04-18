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
Bitti 15:     Varattu (kirjoittaminen sallittu, lukeminen ignorataan)

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

from dataclasses import dataclass, field

from ...constants import (
    COLOR_BLACK,
    COLOR_BLUE,
    COLOR_CYAN,
    COLOR_GREEN,
    COLOR_MAGENTA,
    COLOR_RED,
    COLOR_WHITE,
    COLOR_YELLOW,
    GFX_MODE_REG,
    GFX_MODE_B,
    GFX_MODE_C,
    SCREEN_COLS,
    SCREEN_ROWS,
    VRAM_START,
    VRAM_WORDS,
    VRAM_CHAR_MASK,
    VRAM_FG_MASK,
    VRAM_FG_SHIFT,
    VRAM_BG_MASK,
    VRAM_BG_SHIFT,
    VRAM_ATTR_BOLD,
    WORD_MASK,
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

_GFX_SCROLL_DIR_UP = 0
_GFX_SCROLL_DIR_DOWN = 1
_GFX_SCROLL_DIR_LEFT = 2
_GFX_SCROLL_DIR_RIGHT = 3


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

    # Kaksoisbufferointi: etupuskuri (front buffer)
    # Kun ohjelma kirjoittaa GFX_FLIP_REG:iin, TUI renderöi VRAMin ja tallentaa
    # tuloksen tähän puskuriin. Seuraavissa päivityksissä näytetään puskurin sisältö
    # (näyttö ei välky). Puskuri tyhjennetään cold_reset/reset_for_test:ssä.
    _front_rendered: str = field(default="", init=False, repr=False)
    _has_front_buffer: bool = field(default=False, init=False, repr=False)
    _front_vram_words: list[int] = field(default_factory=list, init=False, repr=False)
    _front_vram_mode: int = field(default=0, init=False, repr=False)

    # VRAM dirty-flag: version counter joka inkrementoidaan aina kun VRAM kirjoitetaan.
    # TUI voi näin välttyä turhilta renderöinneiltä vertaamalla versiota edelliseen.
    _vram_version: int = field(default=0, init=False, repr=False)
    _dirty_min: int = field(default=-1, init=False, repr=False)
    _dirty_max: int = field(default=-1, init=False, repr=False)

    def set_front_buffer(self, rendered: str) -> None:
        """Tallenna renderöintitulos etupuskuriin (kutsutaan flip-rekisterin kirjoituksessa)."""
        self._front_rendered = rendered
        self._has_front_buffer = True

    def get_front_buffer(self) -> str:
        """Palauta etupuskurin sisältö."""
        return self._front_rendered

    @property
    def has_front_buffer(self) -> bool:
        """True, jos etupuskurissa on sisältöä (flip on tapahtunut ainakin kerran)."""
        return self._has_front_buffer

    def clear_front_buffer(self) -> None:
        """Tyhjennä etupuskuri (kutsutaan resetissä)."""
        self._front_rendered = ""
        self._has_front_buffer = False
        self._front_vram_words.clear()
        self._front_vram_mode = 0

    def capture_front_vram(self, memory: Memory) -> None:
        """Tallenna nykyinen VRAM näkyvän etupuskurin raakakuvaksi."""
        self._front_vram_words = list(memory.words[VRAM_START : VRAM_START + VRAM_WORDS])
        self._front_vram_mode = memory.read(GFX_MODE_REG)

    def reset_vram_version(self) -> None:
        """Nollaa VRAM-versio (kutsutaan cold_reset/reset_for_test:ssä)."""
        self._vram_version = 0
        self._dirty_min = -1
        self._dirty_max = -1

    def mark_vram_dirty_range(self, start_idx: int, end_idx: int) -> None:
        """Merkitse lineaarinen VRAM-alue muuttuneeksi yhdellä versiopäivityksellä."""
        self._vram_version = (self._vram_version + 1) & 0x7FFFFFFF
        if start_idx > end_idx:
            return
        if self._dirty_min < 0:
            self._dirty_min = start_idx
            self._dirty_max = end_idx
            return
        if start_idx < self._dirty_min:
            self._dirty_min = start_idx
        if end_idx > self._dirty_max:
            self._dirty_max = end_idx

    def mark_vram_dirty(self, addr: int | None = None) -> None:
        """Merkitse VRAM muuttuneeksi (kutsutaan VRAM-kirjoituksessa)."""
        self._vram_version = (self._vram_version + 1) & 0x7FFFFFFF  # prevent overflow
        if addr is None:
            return
        if addr < VRAM_START or addr >= VRAM_START + (self.cols * self.rows):
            return
        idx = addr - VRAM_START
        if self._dirty_min < 0:
            self._dirty_min = idx
            self._dirty_max = idx
            return
        if idx < self._dirty_min:
            self._dirty_min = idx
        if idx > self._dirty_max:
            self._dirty_max = idx

    def get_vram_version(self) -> int:
        """Palauta nykyisen VRAM-version (käytetään dirty-checkissa)."""
        return self._vram_version

    def consume_dirty_span(self) -> tuple[int, int] | None:
        """Palauta ja nollaa viimeisin VRAM dirty-span (lineaarinen indeksi)."""
        if self._dirty_min < 0:
            return None
        span = (self._dirty_min, self._dirty_max)
        self._dirty_min = -1
        self._dirty_max = -1
        return span

    def scroll_visible_to_vram(self, memory: Memory, command: int) -> None:
        """Kopioi näkyvä etupuskuri VRAMiin siirrettynä annetun komennon mukaan."""
        mode = memory.read(GFX_MODE_REG)
        if mode == GFX_MODE_B:
            width, height = 80, 48
        elif mode == GFX_MODE_C:
            width, height = 160, 96
        else:
            return

        direction = (command >> 8) & 0x00FF
        amount = command & 0x00FF
        if amount <= 0:
            return
        amount = min(amount, 15)

        if direction == _GFX_SCROLL_DIR_UP:
            dx = 0
            dy = amount
            axis_limit = height
        elif direction == _GFX_SCROLL_DIR_DOWN:
            dx = 0
            dy = -amount
            axis_limit = height
        elif direction == _GFX_SCROLL_DIR_LEFT:
            dx = amount
            dy = 0
            axis_limit = width
        elif direction == _GFX_SCROLL_DIR_RIGHT:
            dx = -amount
            dy = 0
            axis_limit = width
        else:
            return

        dest_words = [0] * VRAM_WORDS
        if amount >= axis_limit:
            self._write_vram_words(memory, dest_words)
            return

        if len(self._front_vram_words) == VRAM_WORDS and self._front_vram_mode == mode:
            source_words = self._front_vram_words
        else:
            source_words = self._snapshot_vram_words(memory)

        for y in range(height):
            src_y = y + dy
            if src_y < 0 or src_y >= height:
                continue
            for x in range(width):
                src_x = x + dx
                if src_x < 0 or src_x >= width:
                    continue
                if self._get_pixel_from_words(source_words, mode, src_x, src_y):
                    self._set_pixel_in_words(dest_words, mode, x, y, 1)

        self._write_vram_words(memory, dest_words)

    def _snapshot_vram_words(self, memory: Memory) -> list[int]:
        """Palauta nykyinen VRAM raakasanalistana."""
        return list(memory.words[VRAM_START : VRAM_START + VRAM_WORDS])

    def _write_vram_words(self, memory: Memory, words: list[int]) -> None:
        """Kirjoita koko grafiikka-VRAM yhdestä sanalistasta."""
        for idx, word in enumerate(words[:VRAM_WORDS]):
            memory.write(VRAM_START + idx, word & WORD_MASK)
        self.mark_vram_dirty_range(0, VRAM_WORDS - 1)

    def _get_pixel_from_words(
        self,
        words: list[int],
        mode: int,
        x: int,
        y: int,
    ) -> int:
        """Lue yksi grafiikkapikseli raakasta VRAM-sanataulukosta."""
        if mode == GFX_MODE_B:
            idx = (y // 2) * self.cols + x
            mask = 0x0002 if (y & 1) == 0 else 0x0001
            return 1 if (words[idx] & mask) != 0 else 0

        idx = (y // 4) * self.cols + (x // 2)
        pt_col = x & 1
        pt_row = y & 0x0003
        bit_num = 6 + pt_col if pt_row == 3 else pt_col * 3 + pt_row
        return 1 if (words[idx] & (1 << bit_num)) != 0 else 0

    def _set_pixel_in_words(
        self,
        words: list[int],
        mode: int,
        x: int,
        y: int,
        value: int,
    ) -> None:
        """Kirjoita yksi grafiikkapikseli raakasanataulukkoon."""
        if mode == GFX_MODE_B:
            idx = (y // 2) * self.cols + x
            mask = 0x0002 if (y & 1) == 0 else 0x0001
        else:
            idx = (y // 4) * self.cols + (x // 2)
            pt_col = x & 1
            pt_row = y & 0x0003
            bit_num = 6 + pt_col if pt_row == 3 else pt_col * 3 + pt_row
            mask = 1 << bit_num

        if value:
            words[idx] = (words[idx] | mask) & WORD_MASK
        else:
            words[idx] = words[idx] & (~mask & WORD_MASK)

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

    def extract_char_with_attrs(self, word: int) -> tuple[str, int, int, bool]:
        """
        Erota VRAM-sanasta merkki, värit ja attribuutit.

        Args:
            word: 16-bittinen VRAM-sana

        Returns:
            Tuple: (merkki, fg_väri, bg_väri, bold)
                - merkki: str (ASCII-merkki)
                - fg_väri: int (0-7)
                - bg_väri: int (0-7)
                - bold: bool
        """
        ch = chr(word & VRAM_CHAR_MASK)
        fg = (word & VRAM_FG_MASK) >> VRAM_FG_SHIFT
        bg = (word & VRAM_BG_MASK) >> VRAM_BG_SHIFT
        bold = bool(word & VRAM_ATTR_BOLD)
        return ch, fg, bg, bold

    def render_with_rich_colors(self, memory: Memory) -> str:
        """
        Renderoi VRAM Rich-tekstiksi väreillä ja attribuuteilla.

        Optimoitu: yhdistää peräkkäiset saman tyylin merkit yhteen
        Rich-tagiin (esim. 80 tyhjää merkkiä → 1 tagi, ei 80).

        Args:
            memory: Muistiolio, josta VRAM luetaan

        Returns:
            Rich-muotoiltu merkkijono väreillä
        """
        lines: list[str] = []
        addr = VRAM_START

        for _ in range(self.rows):
            row_parts: list[str] = []
            run_chars: list[str] = []
            run_tag = ""

            for _ in range(self.cols):
                word = memory.read(addr)
                ch, fg, bg, bold = self.extract_char_with_attrs(word)

                if not (32 <= ord(ch) < 127):
                    ch = " "

                if fg == 0 and bg == 0 and ch != " ":
                    fg = COLOR_WHITE

                fg_color = _COLOR_MAP.get(fg, "white")
                bg_color = _COLOR_MAP.get(bg, "black")
                style_prefix = "bold " if bold else ""
                tag = f"[{style_prefix}{fg_color} on {bg_color}]"

                if tag == run_tag:
                    run_chars.append(ch)
                else:
                    if run_chars:
                        row_parts.append(f"{run_tag}{''.join(run_chars)}[/]")
                    run_tag = tag
                    run_chars = [ch]

                addr += 1

            if run_chars:
                row_parts.append(f"{run_tag}{''.join(run_chars)}[/]")
            lines.append("".join(row_parts))

        return "\n".join(lines)

    # Tila B: puoliblokkipikseli (80 × 48 pikseliä)
    # bitti 1 = ylempi pikseli, bitti 0 = alempi pikseli
    _MODE_B_CHARS = [" ", "▄", "▀", "█"]  # indeksi = word & 0x03

    def render_mode_b(self, memory: Memory) -> str:
        """Renderoi tila B (puoliblokkipikseli 80 × 48) Rich-tekstiksi.

        Jokainen VRAM-sana tuottaa yhden terminaalimerkin (80 × 24 merkkiä).
        Merkki valitaan word & 0x03 perusteella:
          0b00 → ' '  (molemmat pikselit pois)
          0b01 → '▄'  (alempi pikseli päällä)
          0b10 → '▀'  (ylempi pikseli päällä)
          0b11 → '█'  (molemmat pikselit päällä)
        """
        lines: list[str] = []
        addr = VRAM_START
        for _ in range(self.rows):
            row = "".join(
                self._MODE_B_CHARS[memory.read(addr + c) & 0x03]
                for c in range(self.cols)
            )
            lines.append(f"[white on black]{row}[/]")
            addr += self.cols
        return "\n".join(lines)

    def render_mode_c(self, memory: Memory) -> str:
        """Renderoi tila C (braille 160 × 96) Rich-tekstiksi.

        Jokainen VRAM-sana tuottaa yhden braille-merkin (80 × 24 merkkiä
        terminaalissa, mutta 160 × 96 kCPU16-pikseliä).

        Braille-bittijärjestys (word & 0xFF):
          bitti 0 = piste 1 (vasen ylä)    bitti 3 = piste 4 (oikea ylä)
          bitti 1 = piste 2 (vasen keski)  bitti 4 = piste 5 (oikea keski)
          bitti 2 = piste 3 (vasen ala)    bitti 5 = piste 6 (oikea ala)
          bitti 6 = piste 7 (vasen pohja)  bitti 7 = piste 8 (oikea pohja)

        Tämä vastaa suoraan Unicode braille -koodipisteiden bittijärjestystä
        (U+2800–U+28FF), joten chr(0x2800 | (word & 0xFF)) antaa oikean merkin.
        """
        lines: list[str] = []
        addr = VRAM_START
        for _ in range(self.rows):
            row = "".join(
                chr(0x2800 | (memory.read(addr + c) & 0xFF)) for c in range(self.cols)
            )
            lines.append(f"[white on black]{row}[/]")
            addr += self.cols
        return "\n".join(lines)

    def render_auto(self, memory: Memory) -> str:
        """Valitse renderöintitapa GFX_MODE_REG:n (0xFF80) mukaan.

        Tila A (0): tekstitila väreillä
        Tila B (1): puoliblokkipikseli
        Tila C (2): braille
        """
        mode = memory.read(GFX_MODE_REG)
        if mode == GFX_MODE_B:
            return self.render_mode_b(memory)
        if mode == GFX_MODE_C:
            return self.render_mode_c(memory)
        return self.render_with_rich_colors(memory)
