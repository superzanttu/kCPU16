"""
Disassembler kCPU16-prosessorille.

Muuntaa konekielen (lista 16-bittisia sanoja) takaisin luettavaan
assembly-muotoon. Kaytetaan debuggaukseen ja ohjelmien analysointiin.

TULOSFORMAATTI:
---------------
Jokainen kasky tulostetaan muodossa:
    OSOITE: MNEMONIC OPERANDIT

Esimerkki:
    0100: LOAD 0x0000, 0x000A     ; LOAD R0, 10
    0103: ADD 0x0000, 0x0001      ; ADD R0, R1
    0106: HALT

TUNTEMATON DATA:
----------------
Jos opcode ei vastaa mitaan tunnettua kaskya, se tulostetaan:
    0100: .word 0x1234

Tama mahdollistaa myos dataosuuksien tarkastelun.
"""

from __future__ import annotations

from .instruction import OPCODE_TABLE
from .constants import WORD_MASK

# Kaanteinen hakutaulukko: opcode -> (mnemonic, operand_count, privileged)
# Kaytamme samaa formaattia kuin OPCODE_TABLE
REVERSE_TABLE = {opcode: meta for opcode, meta in OPCODE_TABLE.items()}

# Rekisteri-indeksi -> nimi muistikaskyjen formatointia varten
_REG_NAMES: dict[int, str] = {
    0: "R0", 1: "R1", 2: "R2", 3: "R3",
    4: "R4", 5: "R5", 6: "R6", 7: "R7",
    8: "R8", 9: "R9", 10: "R10", 11: "R11",
    12: "R12", 13: "R13", 14: "R14", 15: "R15",
    16: "FP", 17: "SP",
}


def _format_memory_instr(mnemonic: str, op_vals: list[int]) -> str | None:
    """Muotoile muistioperaatiot uudella [..] syntaksilla.

    Palauttaa muotoillun merkkijonon jos mnemoniikka on muistioperaatio,
    muuten None (jolloin kaytetaan vanhaa heksaformaattia).
    """

    def r(idx: int) -> str:
        return _REG_NAMES.get(idx, f"?{idx}")

    if mnemonic == "READ" and len(op_vals) >= 2:
        return f"LOAD {r(op_vals[0])}, [0x{op_vals[1]:04X}]"
    if mnemonic == "READ_IND" and len(op_vals) >= 2:
        return f"LOAD {r(op_vals[0])}, [{r(op_vals[1])}]"
    if mnemonic == "READ_REL" and len(op_vals) >= 2:
        return f"LOAD {r(op_vals[0])}, [FP+{op_vals[1]}]"
    if mnemonic == "STORE" and len(op_vals) >= 2:
        return f"STORE [0x{op_vals[1]:04X}], {r(op_vals[0])}"
    if mnemonic == "STOREI" and len(op_vals) >= 2:
        return f"STORE [0x{op_vals[1]:04X}], {op_vals[0]}"
    if mnemonic == "STORE_IND" and len(op_vals) >= 2:
        return f"STORE [{r(op_vals[0])}], {r(op_vals[1])}"
    if mnemonic == "STOREI_IND" and len(op_vals) >= 2:
        return f"STORE [{r(op_vals[0])}], {op_vals[1]}"
    if mnemonic == "STORE_REL" and len(op_vals) >= 2:
        return f"STORE [FP+{op_vals[1]}], {r(op_vals[0])}"
    if mnemonic == "STOREI_REL" and len(op_vals) >= 2:
        return f"STORE [FP+{op_vals[1]}], {op_vals[0]}"
    return None


class Disassembler:
    """
    kCPU16 Disassembler - muuntaa konekielen assembly-tekstiksi.

    Lukee sanoja jarjestyksessa ja tulkitsee ne kaskyina.
    Tuntemattomat opcodet tulostetaan .word-direktiiveina.

    Example:
        >>> dis = Disassembler()
        >>> words = [0x1080, 0x0000, 0x002A, 0xF000]
        >>> print(dis.disassemble(words))
        0000: LOAD 0x0000, 0x002A
        0003: HALT
    """

    def disassemble(self, words: list[int], start_addr: int = 0) -> str:
        """
        Muunna konekielisanat luettavaksi assembler-tekstiksi.

        Lukee sanoja listasta ja dekoodaa ne kaskyiksi.
        Operandit tulostetaan heksadesimaalimuodossa.

        Args:
            words: Lista 16-bittisia konekielisanoja
            start_addr: Ensimmaisen sanan oletettu muistiosoite (oletus: 0)

        Returns:
            Monirivinen merkkijono, yksi kasky per rivi

        Example:
            >>> dis.disassemble([0x0044], start_addr=0x0100)
            '0100: HALT'
        """
        lines: list[str] = []
        i = 0  # Indeksi words-listaan
        pc = start_addr  # Virtuaalinen osoite tulostetta varten

        while i < len(words):
            # Lue opcode-sana
            opcode = words[i] & WORD_MASK

            # Yrita etsia vastaava kasky taulukosta
            meta = REVERSE_TABLE.get(opcode)

            if meta is None:
                # Tuntematon opcode -> tulosta raakadata
                lines.append(f"{pc:04X}: .word 0x{opcode:04X}")
                i += 1
                pc += 1
                continue

            # Pura kaskyn metatiedot
            mnemonic, operand_count, _ = meta

            # Kerae operandit seuraavista sanoista
            op_vals = []
            for j in range(operand_count):
                # Tarkista ettei lueta yli listan
                if i + 1 + j >= len(words):
                    break
                op_vals.append(words[i + 1 + j] & WORD_MASK)

            # Rakenna tulostusrivi — muistioperaatiot uudella [..] syntaksilla
            mem_fmt = _format_memory_instr(mnemonic, op_vals)
            if mem_fmt is not None:
                lines.append(f"{pc:04X}: {mem_fmt}")
            else:
                operands = [f"0x{v:04X}" for v in op_vals]
                line = f"{pc:04X}: {mnemonic}"
                if operands:
                    line += " " + ", ".join(operands)
                lines.append(line)

            # Siirry seuraavan kaskyn kohdalle
            # Kaskyn koko = 1 (opcode) + operandien maara
            i += 1 + operand_count
            pc += 1 + operand_count

        # Yhdista rivit rivinvaihdoilla
        return "\n".join(lines)
