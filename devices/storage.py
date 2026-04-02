"""Block storage device used by DREAD/DWRITE and boot loader.

Storage is internally modeled as fixed-size blocks (sectors), which is closer to
real hardware than a flat word array. Word-addressed operations still exist for
CPU instructions, but they are translated to block + offset accesses.
"""

from dataclasses import dataclass, field

from ..constants import WORD_MASK


@dataclass
class BlockStorageDevice:
    block_size_words: int = 0x0100
    block_count: int = 0x0100
    blocks: list[list[int]] = field(default_factory=list)

    def __post_init__(self) -> None:
        if self.block_size_words <= 0 or self.block_count <= 0:
            raise ValueError("Block size and block count must be positive")
        if not self.blocks:
            self.blocks = [[0] * self.block_size_words for _ in range(self.block_count)]

    @property
    def total_words(self) -> int:
        return self.block_size_words * self.block_count

    def read_word(self, word_addr: int) -> int:
        block_idx, offset = self._decode_word_address(word_addr)
        return self.blocks[block_idx][offset]

    def write_word(self, word_addr: int, value: int) -> None:
        block_idx, offset = self._decode_word_address(word_addr)
        self.blocks[block_idx][offset] = value & WORD_MASK

    def read_block(self, block_idx: int) -> list[int]:
        block_idx = self._normalize_block_index(block_idx)
        return list(self.blocks[block_idx])

    def write_block(self, block_idx: int, data: list[int]) -> None:
        block_idx = self._normalize_block_index(block_idx)
        if len(data) != self.block_size_words:
            raise ValueError(
                f"Block write size must be {self.block_size_words} words, got {len(data)}"
            )
        self.blocks[block_idx] = [word & WORD_MASK for word in data]

    def read_range(self, start_addr: int, count: int) -> list[int]:
        return [self.read_word(start_addr + i) for i in range(count)]

    def write_range(self, start_addr: int, data: list[int]) -> None:
        for i, word in enumerate(data):
            self.write_word(start_addr + i, word)

    def _decode_word_address(self, word_addr: int) -> tuple[int, int]:
        word_addr &= WORD_MASK
        if word_addr >= self.total_words:
            raise ValueError(
                f"Word address out of range: 0x{word_addr:04X} (capacity {self.total_words} words)"
            )
        return divmod(word_addr, self.block_size_words)

    def _normalize_block_index(self, block_idx: int) -> int:
        if block_idx < 0 or block_idx >= self.block_count:
            raise ValueError(f"Block index out of range: {block_idx}")
        return block_idx
