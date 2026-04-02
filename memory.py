"""Word-addressed memory implementation with protection checks."""

from __future__ import annotations

from dataclasses import dataclass, field

from .constants import MEMORY_WORDS, VRAM_END, VRAM_START, WORD_MASK
from .exceptions import MemoryAccessFaultError


@dataclass
class Memory:
    words: list[int] = field(default_factory=lambda: [0] * MEMORY_WORDS)

    def reset(self) -> None:
        self.words = [0] * MEMORY_WORDS

    def read(self, addr: int) -> int:
        return self.words[addr & WORD_MASK]

    def write(self, addr: int, value: int) -> None:
        self.words[addr & WORD_MASK] = value & WORD_MASK

    @staticmethod
    def check_user_access(addr: int, mpr: int) -> None:
        addr &= WORD_MASK
        if VRAM_START <= addr <= VRAM_END:
            return
        if addr < (mpr & WORD_MASK):
            raise MemoryAccessFaultError(f"User mode memory fault at {addr:04X}")

    def load_words(self, start_addr: int, data: list[int]) -> None:
        addr = start_addr & WORD_MASK
        for word in data:
            self.write(addr, word)
            addr = (addr + 1) & WORD_MASK
