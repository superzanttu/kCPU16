"""
Verifioi test/*.asm tiedostojen konekielinen ulostulo spesifikaatiota vasten.

Tarkistukset jokaiselle käännetylle käskylle:
  1. Opcode löytyy OPCODE_TABLE:sta (tunnettu käsky)
  2. Opcode bit-kentät: bits 5-0 = 0 (varattu), OPS-kenttä vastaa operandimäärää
  3. Käsky ei mene segmentin yli (operandit mahtuvat)
  4. Rekisterioperandit ovat välillä 0-5
  5. Kaikki sanat ovat 16-bittisiä (0x0000-0xFFFF)
  6. Segmentti mahtuu muistiavaruuteen (0x0000-0xFFFF)
"""

from __future__ import annotations

import sys
from pathlib import Path

# Varmista että kcpu16-paketti löytyy
sys.path.insert(0, str(Path(__file__).parent))

from kcpu16.assembler import Assembler
from kcpu16.instruction import OPCODE_TABLE, OPCODE_NOPS_SHIFT, OPCODE_NOPS_MASK
from kcpu16.constants import WORD_MASK

# ---------------------------------------------------------------------------
# Operandityyppikartta: mnemonic -> lista operandityypeistä
# 'r' = rekisteri (0-5), 'i' = immediate/osoite (0-0xFFFF)
# ---------------------------------------------------------------------------
OPERAND_TYPES: dict[str, list[str]] = {
    # GRP 1: Tiedonsiirto
    "LOAD": ["r", "i"],  # reg, imm
    "CPY": ["r", "r"],  # regD, regS
    "READ": ["r", "i"],  # reg, addr
    "STORE": ["r", "i"],  # reg, addr
    "READ_IND": ["r", "r"],  # regD, regS
    "STORE_IND": ["r", "r"],  # regD, regS
    "READ_REL": ["r", "i"],  # reg, fp-offset
    "STORE_REL": ["r", "i"],  # reg, fp-offset
    "STOREI": ["i", "i"],  # imm, addr
    "STOREI_IND": ["r", "i"],  # regD, imm
    "STOREI_REL": ["i", "i"],  # imm, offset
    # GRP 2: Aritmetiikka
    "ADD": ["r", "r"],
    "SUB": ["r", "r"],
    "MUL": ["r", "r"],
    "DIV": ["r", "r"],
    "CMP": ["r", "r"],
    "ADC": ["r", "r"],
    # GRP 3: Logiikka
    "AND": ["r", "r"],
    "OR": ["r", "r"],
    "XOR": ["r", "r"],
    "NOT": ["r"],
    "SHL": ["r", "r"],
    "SHR": ["r", "r"],
    # GRP 4: Pino
    "PUSH": ["r"],
    "POP": ["r"],
    "SWSP": ["r", "r"],
    # GRP 5: Ohjausrakenne
    "JUMP": ["i"],
    "CALL": ["i"],
    "RET": [],
    "JZ": ["i"],
    "JNZ": ["i"],
    "JLT": ["i"],
    "JGT": ["i"],
    "JLE": ["i"],
    "JGE": ["i"],
    # GRP 6: Keskeytykset
    "INT": ["i"],
    "IRET": [],
    "STI": [],
    "CLI": [],
    # GRP 7: Järjestelmä
    "HALT": [],
    "DREAD": ["r", "r"],
    "DWRITE": ["r", "r"],
    "SMPR": ["r"],
    "STMR": ["r"],
    "EXIT": [],
    "KGET": ["r"],
    "TSL": ["r", "i"],
    "NOP": [],
}

MAX_REG_IDX = 5  # R0=0 R1=1 R2=2 R3=3 FP=4 SP=5


def _build_data_addrs(
    source_map: list[tuple[str, int]], seg_start: int, seg_end: int
) -> set[int]:
    """
    Rakenna joukko dataosoitteista (ei-käskyjä) source_map:n perusteella.

    .db ja .dstr direktiivit sijoittavat raakadataa muistiin — ne eivät ole käskyjä.
    Löydetään jokaisen data-direktiivin osoite ja merkitään kaikki sanat
    seuraavaan source_map-merkintään asti dataksi.
    """
    data_addrs: set[int] = set()
    # Suodata tämän segmentin merkinnät ja järjestä osoitteen mukaan
    seg_entries = sorted(
        [(src, addr) for src, addr in source_map if seg_start <= addr <= seg_end],
        key=lambda x: x[1],
    )
    for k, (src_line, addr) in enumerate(seg_entries):
        sl = src_line.strip().lower()
        if sl.startswith(".db") or sl.startswith(".dstr"):
            # Merkitään data alueena seuraavaan merkintään asti
            next_addr = (
                seg_entries[k + 1][1] if k + 1 < len(seg_entries) else seg_end + 1
            )
            data_addrs.update(range(addr, next_addr))
    return data_addrs


def verify_segment(
    seg_start: int,
    words: list[int],
    filename: str,
    source_map: list[tuple[str, int]],
) -> list[str]:
    """
    Verifioi yksi muistisegmentti.

    Palauttaa listan virheilmoituksista (tyhjä = kaikki ok).
    """
    errors: list[str] = []

    # Tarkistus 1: Segmentin osoitealue
    if seg_start < 0 or seg_start > WORD_MASK:
        errors.append(
            f"  Segmentin aloitusosoite 0x{seg_start:04X} on muistiavaruuden ulkopuolella"
        )
    seg_end = seg_start + len(words) - 1
    if seg_end > WORD_MASK:
        errors.append(
            f"  Segmentti ylittää muistiavaruuden: "
            f"0x{seg_start:04X}+{len(words)}=0x{seg_end:04X} > 0xFFFF"
        )

    # Rakenna dataosoitejoukko (.db / .dstr -alueet)
    data_addrs = _build_data_addrs(source_map, seg_start, seg_end)

    i = 0
    while i < len(words):
        word = words[i]
        pc = seg_start + i

        # Ohita dataosoitteet (.db / .dstr -alueet) — ei käskyjä
        if pc in data_addrs:
            # Tarkista vain että arvo mahtuu 16 bittiin
            if word < 0 or word > WORD_MASK:
                errors.append(f"  0x{pc:04X}: data-sana 0x{word:X} ei mahdu 16 bittiin")
            i += 1
            continue

        # Tarkistus 2: Kaikki sanat 16-bittisiä
        if word < 0 or word > WORD_MASK:
            errors.append(f"  0x{pc:04X}: sana 0x{word:08X} ei mahdu 16 bittiin")
            i += 1
            continue

        # Tarkistus 3: Opcode olemassa OPCODE_TABLE:ssa
        if word not in OPCODE_TABLE:
            errors.append(f"  0x{pc:04X}: tuntematon opcode 0x{word:04X}")
            i += 1
            continue

        mnemonic, n_ops_spec, privileged = OPCODE_TABLE[word]

        # Tarkistus 4: Varatut bitit 5-0 ovat nollia
        reserved_bits = word & 0x3F
        if reserved_bits != 0:
            errors.append(
                f"  0x{pc:04X}: opcode 0x{word:04X} ({mnemonic}): "
                f"varatut bitit 5-0 eivät ole nollia: 0b{reserved_bits:06b}"
            )

        # Tarkistus 5: OPS-kenttä vastaa OPCODE_TABLE:n operandimäärää
        ops_field = (word >> OPCODE_NOPS_SHIFT) & OPCODE_NOPS_MASK
        if ops_field != n_ops_spec:
            errors.append(
                f"  0x{pc:04X}: opcode 0x{word:04X} ({mnemonic}): "
                f"OPS-kenttä={ops_field} mutta OPCODE_TABLE odottaa {n_ops_spec}"
            )

        # Tarkistus 6: Operandit mahtuvat segmenttiin
        if i + n_ops_spec >= len(words) and n_ops_spec > 0:
            available = len(words) - i - 1
            errors.append(
                f"  0x{pc:04X}: {mnemonic} tarvitsee {n_ops_spec} operandia "
                f"mutta segmentissä on vain {available} sanaa jäljellä"
            )
            i += 1
            continue

        # Tarkistus 7: Operandien arvot
        op_types = OPERAND_TYPES.get(mnemonic)
        if op_types is None:
            errors.append(
                f"  0x{pc:04X}: mnemonic {mnemonic!r} puuttuu OPERAND_TYPES-kartasta"
            )
        else:
            for j, op_type in enumerate(op_types):
                if j >= n_ops_spec:
                    break
                operand_word = words[i + 1 + j]
                if operand_word < 0 or operand_word > WORD_MASK:
                    errors.append(
                        f"  0x{pc:04X}: {mnemonic} operandi {j+1}: "
                        f"arvo 0x{operand_word:X} ei mahdu 16 bittiin"
                    )
                elif op_type == "r" and operand_word > MAX_REG_IDX:
                    errors.append(
                        f"  0x{pc:04X}: {mnemonic} operandi {j+1}: "
                        f"rekisteriindeksi {operand_word} on virheellinen "
                        f"(sallittu 0-{MAX_REG_IDX})"
                    )

        i += 1 + n_ops_spec

    return errors


def main() -> int:
    test_dir = Path(__file__).parent / "kcpu16" / "test"
    asm_files = sorted(test_dir.glob("*.asm"))

    if not asm_files:
        print(f"Ei löydy .asm-tiedostoja hakemistosta: {test_dir}")
        return 1

    passed = 0
    failed = 0
    all_errors: list[tuple[str, list[str]]] = []

    for asm_path in asm_files:
        source = asm_path.read_text(encoding="utf-8")
        asm = Assembler()
        try:
            segments = asm.assemble(source)
        except Exception as exc:
            all_errors.append((asm_path.name, [f"  Assemblointivirhe: {exc}"]))
            failed += 1
            continue

        file_errors: list[str] = []
        for seg_start, words in segments:
            errs = verify_segment(seg_start, words, asm_path.name, asm.source_map)
            file_errors.extend(errs)

        if file_errors:
            all_errors.append((asm_path.name, file_errors))
            failed += 1
        else:
            passed += 1

    # --- Tulostus ---
    print()
    print("=" * 60)
    print("  kCPU16 KONEKIELIVERIFIKAATIO")
    print("=" * 60)
    print(f"  Tiedostoja testattu: {len(asm_files)}")
    print(f"  OK:     {passed}")
    print(f"  VIRHE:  {failed}")
    print("=" * 60)

    if all_errors:
        print()
        print("VIRHEELLISET TIEDOSTOT:")
        for fname, errors in all_errors:
            print(f"\n  {fname}:")
            for err in errors:
                print(err)

    if failed == 0:
        print()
        print("  Kaikki tiedostot läpäisivät spesifikaatiotarkistuksen.")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
