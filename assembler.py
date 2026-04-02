"""Assembler for kCPU16.

Two-pass assembler with label support:
- Pass 1: scan lines, record label -> word address mapping
- Pass 2: emit opcodes and resolve operands (registers, literals, labels)

Syntax:
  - One instruction per line
  - Labels on their own line, ending with colon: "loop:"
  - Tokens separated by whitespace and/or comma
  - Register names: R0, R1, R2, R3, FP, SP  (case insensitive)
  - Numeric literals: 42  /  0xFF  /  #42  /  #0xFF
  - Label references used directly as operand: "JUMP loop"
  - Comments start with semicolon, rest of line is ignored
"""

from __future__ import annotations

from .instruction import OPCODE_TABLE


REGISTER_TO_ID: dict[str, int] = {
    "R0": 0,
    "R1": 1,
    "R2": 2,
    "R3": 3,
    "FP": 4,
    "SP": 5,
}

MNEMONIC_TO_OPCODE: dict[str, int] = {v[0]: k for k, v in OPCODE_TABLE.items()}


class Assembler:
    def assemble(self, source: str, start_addr: int = 0x0100) -> list[int]:
        labels = self._pass1_collect_labels(source, start_addr)
        return self._pass2_emit(source, labels)

    def _pass1_collect_labels(self, source: str, start_addr: int) -> dict[str, int]:
        labels: dict[str, int] = {}
        addr = start_addr
        for raw_line in source.splitlines():
            line = raw_line.split(";", 1)[0].strip()
            if not line:
                continue
            if line.endswith(":"):
                label_name = line[:-1].strip().upper()
                if label_name in labels:
                    raise ValueError(f"Duplicate label: {label_name}")
                labels[label_name] = addr
                continue
            mnemonic = line.replace(",", " ").split()[0].upper()
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")
            _, operand_count, _ = OPCODE_TABLE[opcode]
            addr += 1 + operand_count
        return labels

    def _pass2_emit(self, source: str, labels: dict[str, int]) -> list[int]:
        words: list[int] = []
        for raw_line in source.splitlines():
            line = raw_line.split(";", 1)[0].strip()
            if not line or line.endswith(":"):
                continue
            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()
            opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
            if opcode is None:
                raise ValueError(f"Unknown mnemonic: {mnemonic}")
            words.append(opcode)
            for token in parts[1:]:
                words.append(self._parse_operand(token, labels))
        return [w & 0xFFFF for w in words]

    def _parse_operand(self, token: str, labels: dict[str, int]) -> int:
        upper = token.upper()
        if upper in REGISTER_TO_ID:
            return REGISTER_TO_ID[upper]
        if upper in labels:
            return labels[upper]
        if upper.startswith("#"):
            upper = upper[1:]
        return int(upper, 0)
