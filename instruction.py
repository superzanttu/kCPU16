"""Instruction metadata and decode result models."""

from dataclasses import dataclass, field


@dataclass
class DecodedInstruction:
    mnemonic: str
    operands: list[int] = field(default_factory=list)
    size_words: int = 1
    privileged: bool = False


# Simple skeleton opcode map. Expand as you implement full ISA encoding.
# opcode_word -> (mnemonic, operand_count, privileged)
OPCODE_TABLE: dict[int, tuple[str, int, bool]] = {
    0x0001: ("LOAD", 2, False),
    0x0002: ("CPY", 2, False),
    0x0003: ("READ", 2, False),
    0x0004: ("STORE", 2, False),
    0x0005: ("READ_IND", 2, False),
    0x0006: ("STORE_IND", 2, False),
    0x0010: ("ADD", 2, False),
    0x0011: ("SUB", 2, False),
    0x0012: ("MUL", 2, False),
    0x0013: ("DIV", 2, False),
    0x0014: ("CMP", 2, False),
    0x0020: ("PUSH", 1, False),
    0x0021: ("POP", 1, False),
    0x0030: ("JUMP", 1, False),
    0x0031: ("CALL", 1, False),
    0x0032: ("RET", 0, False),
    0x0033: ("JZ", 1, False),
    0x0034: ("JNZ", 1, False),
    0x0035: ("JLT", 1, False),
    0x0040: ("INT", 1, False),
    0x0041: ("IRET", 0, True),
    0x0042: ("STI", 0, True),
    0x0043: ("CLI", 0, True),
    0x0044: ("HALT", 0, True),
    0x0045: ("DREAD", 2, True),
    0x0046: ("DWRITE", 2, True),
    0x0047: ("SMPR", 1, True),
    0x0048: ("STMR", 1, True),
    0x0049: ("EXIT", 0, False),
}
