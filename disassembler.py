"""Disassembler skeleton for kCPU16 machine words."""

from __future__ import annotations

from .instruction import OPCODE_TABLE

REVERSE_TABLE = {opcode: meta for opcode, meta in OPCODE_TABLE.items()}


class Disassembler:
    def disassemble(self, words: list[int], start_addr: int = 0) -> str:
        lines: list[str] = []
        i = 0
        pc = start_addr

        while i < len(words):
            opcode = words[i] & 0xFFFF
            meta = REVERSE_TABLE.get(opcode)
            if meta is None:
                lines.append(f"{pc:04X}: .word 0x{opcode:04X}")
                i += 1
                pc += 1
                continue

            mnemonic, operand_count, _ = meta
            operands = []
            for j in range(operand_count):
                if i + 1 + j >= len(words):
                    break
                operands.append(f"0x{(words[i + 1 + j] & 0xFFFF):04X}")

            line = f"{pc:04X}: {mnemonic}"
            if operands:
                line += " " + ", ".join(operands)
            lines.append(line)

            i += 1 + operand_count
            pc += 1 + operand_count

        return "\n".join(lines)
