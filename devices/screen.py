"""Virtual text mode screen backed by VRAM."""

from __future__ import annotations

from dataclasses import dataclass

from ..constants import SCREEN_COLS, SCREEN_ROWS, VRAM_START
from ..memory import Memory


@dataclass
class ScreenDevice:
    cols: int = SCREEN_COLS
    rows: int = SCREEN_ROWS

    def render_text(self, memory: Memory) -> str:
        lines: list[str] = []
        addr = VRAM_START
        for _ in range(self.rows):
            chars: list[str] = []
            for _ in range(self.cols):
                word = memory.read(addr)
                ch = chr(word & 0x00FF)
                chars.append(ch if 32 <= ord(ch) < 127 else " ")
                addr += 1
            lines.append("".join(chars))
        return "\n".join(lines)
