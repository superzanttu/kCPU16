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


class Disassembler:
    """
    kCPU16 Disassembler - muuntaa konekielen assembly-tekstiksi.

    Lukee sanoja jarjestyksessa ja tulkitsee ne kaskyina.
    Tuntemattomat opcodet tulostetaan .word-direktiiveina.

    Example:
        >>> dis = Disassembler()
        >>> words = [0x0001, 0x0000, 0x002A, 0x0044]
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
            operands = []
            for j in range(operand_count):
                # Tarkista ettei lueta yli listan
                if i + 1 + j >= len(words):
                    break
                # Muotoile operandi heksana
                operands.append(f"0x{(words[i + 1 + j] & WORD_MASK):04X}")

            # Rakenna tulostusrivi
            line = f"{pc:04X}: {mnemonic}"
            if operands:
                # Lisaa operandit pilkulla erotettuna
                line += " " + ", ".join(operands)
            lines.append(line)

            # Siirry seuraavan kaskyn kohdalle
            # Kaskyn koko = 1 (opcode) + operandien maara
            i += 1 + operand_count
            pc += 1 + operand_count

        # Yhdista rivit rivinvaihdoilla
        return "\n".join(lines)
