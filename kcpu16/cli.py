"""
Komentoriviliittyma (CLI) kCPU16-emulaattorille.

Ohjelma kaynnistaa oletuksena TUI-kayttoliittyman (Textual).
Valinnaisia komentoriviargumentteja:

KAYTTO:
-------
    python main.py                        # Kaynnista TUI
    python main.py program.asm            # Kaynnista TUI ja lataa .asm
    python main.py --dsk image.dsk        # Kaynnista TUI ja lataa .dsk storageen
    python main.py program.asm --dsk d.dsk  # Molemmat
    python main.py --check program.asm    # Tarkista syntaksi (ei kaynnista TUI:a)
    python main.py --test program.asm     # Suorita testiohjelma ja tarkista odotukset
    python main.py --asm program.asm      # Tulosta konekielinen listaus
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .assembler import Assembler


def build_parser() -> argparse.ArgumentParser:
    """Rakenna komentoriviargumenttien parseri."""
    parser = argparse.ArgumentParser(
        prog="kcpu16", description="kCPU16 emulator — TUI debugger"
    )

    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        default=None,
        help="Assembly-lahdetiedosto (.asm) ladattavaksi TUI:iin",
    )

    parser.add_argument(
        "--dsk",
        type=Path,
        default=None,
        help="Disk image -tiedosto (.dsk) ladattavaksi storageen",
    )

    parser.add_argument(
        "--check",
        type=Path,
        default=None,
        metavar="FILE",
        help="Tarkista .asm-tiedoston syntaksi (ei kaynnista TUI:a)",
    )

    parser.add_argument(
        "--test",
        type=Path,
        default=None,
        metavar="FILE",
        help="Suorita testiohjelma ja vertaa tulosta .expect_*-direktiiveihin",
    )

    parser.add_argument(
        "--asm",
        type=Path,
        default=None,
        metavar="FILE",
        help="Assembloi .asm-tiedosto ja tulosta konekielinen listaus",
    )

    parser.add_argument(
        "--test-all",
        type=Path,
        nargs="?",
        const=Path(__file__).parent / "test",
        default=None,
        metavar="DIR",
        help="Suorita kaikki .asm-testit hakemistosta (oletus: kcpu16/test/)",
    )

    return parser


def _print_asm(path: Path) -> int:
    """Assembloi .asm-tiedosto ja tulosta konekielinen listaus.

    Jokainen sana tulostetaan muodossa:
        OOOO: XXXX XXXX XXXX   MNEMONIC operandit
    jossa OOOO on osoite, XXXX ovat hex-sanat ja lopussa disasm-rivi.

    Returns:
        0 onnistuessa, 1 virhetilanteessa.
    """
    import io

    # Varmista UTF-8-ulostulo Windowsilla (cp1252 ei tue → ─ jne.)
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    elif hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(
            sys.stdout.buffer, encoding="utf-8", errors="replace"
        )

    if not path.exists():
        print(f"Tiedostoa ei loydy: {path}", file=sys.stderr)
        return 1

    source = path.read_text(encoding="utf-8")
    asm = Assembler()
    try:
        segments = asm.assemble(source, source_path=path)
    except Exception as exc:
        print(f"Virhe tiedostossa {path}:")
        print(f"  {exc}")
        return 1

    from .disassembler import Disassembler, REVERSE_TABLE
    from .constants import WORD_MASK

    dis = Disassembler()
    # Rakenna osoite -> lahderivi -hakutaulukko
    addr_to_src: dict[int, str] = {addr: src for src, addr in asm.source_map}
    # Rakenna osoite -> labelinimi -hakutaulukko (vain kayttajan labelit, ei arkkitehtuurivakiot)
    from .constants import ARCH_SYMBOLS

    arch_addrs: set[int] = set(ARCH_SYMBOLS.values())
    addr_to_label: dict[int, str] = {
        addr: name
        for name, addr in asm.labels.items()
        if addr not in arch_addrs and name not in ARCH_SYMBOLS
    }
    # Mnemoniikat joilla on osoiteoperandi (viimeinen operandi on hyppykohde)
    _BRANCH_MNEMONICS: frozenset[str] = frozenset(
        {"JUMP", "CALL", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE"}
    )

    # Keraa kaikki hyppykohteet segmenteista: osoite -> [hypyn lahettaja mnemonic]
    jump_targets: dict[int, list[str]] = {}
    for seg_start, words in segments:
        i = 0
        pc = seg_start
        while i < len(words):
            opcode = words[i] & WORD_MASK
            meta = REVERSE_TABLE.get(opcode)
            operand_count = meta[1] if meta is not None else 0
            mnemonic = meta[0] if meta is not None else None
            if mnemonic in _BRANCH_MNEMONICS and operand_count >= 1:
                target_addr = words[i + operand_count] & WORD_MASK
                label_name = addr_to_label.get(target_addr, f"0x{target_addr:04X}")
                jump_targets.setdefault(target_addr, []).append(
                    f"{mnemonic} @ {pc:04X} ({label_name})"
                )
            i += 1 + operand_count
            pc += 1 + operand_count

    for seg_start, words in segments:
        print(f"; Segmentti 0x{seg_start:04X} ({len(words)} sanaa)")
        i = 0
        pc = seg_start
        while i < len(words):
            opcode = words[i] & WORD_MASK
            meta = REVERSE_TABLE.get(opcode)
            operand_count = meta[1] if meta is not None else 0
            mnemonic = meta[0] if meta is not None else None
            # Tulosta hyppykohdemarker ennen kaskyrivia
            if pc in jump_targets:
                label_name = addr_to_label.get(pc, f"0x{pc:04X}")
                sources = ", ".join(jump_targets[pc])
                print(f";{'─' * 54} {label_name}: <- {sources}")
            # Keraa kaikki kaskyyn kuuluvat sanat
            instr_words = words[i : i + 1 + operand_count]
            hex_part = " ".join(f"{w:04X}" for w in instr_words)
            # Disassembloi vain tama kasky
            disasm = dis.disassemble(instr_words, start_addr=pc).strip()
            # Poista osoite disasm-rivista (muoto "OOOO: ...") koska se on jo edessa
            if ": " in disasm:
                disasm = disasm.split(": ", 1)[1]
            # Alkuperainen lahderivi kommenttina
            src_comment = f"  ; {addr_to_src[pc]}" if pc in addr_to_src else ""
            print(f"{pc:04X}: {hex_part:<20}  {disasm:<30}{src_comment}")
            i += 1 + operand_count
            pc += 1 + operand_count
        print()

    return 0


def _check_syntax(path: Path) -> int:
    """Tarkista .asm-tiedoston syntaksi ja tulosta virheet.

    Returns:
        0 jos ei virheita, 1 jos virheita loytyi.
    """
    if not path.exists():
        print(f"Tiedostoa ei loydy: {path}", file=sys.stderr)
        return 1

    source = path.read_text(encoding="utf-8")
    asm = Assembler()
    try:
        asm.assemble(source, source_path=path)
    except Exception as exc:
        print(f"Virhe tiedostossa {path}:")
        print(f"  {exc}")
        return 1

    print(f"OK: {path} — ei syntaksivirheita.")
    return 0


def _run_test(path: Path) -> int:
    """Suorita .asm-testiohjelma ja vertaa tilaa .expect_*-odotuksiin.

    Returns:
        0 jos kaikki odotukset taytetty, 1 muuten tai virhetilanteessa.
    """
    from .testrunner import run_test

    passed, total = run_test(path)
    return 0 if passed == total else 1


def _run_test_all(test_dir: Path) -> int:
    """Suorita kaikki .asm-testit hakemistosta ja tulosta yhteenveto.

    Returns:
        0 jos kaikki testit menivat lapi, 1 muuten.
    """
    from .testrunner import run_test_all

    return run_test_all(test_dir)


def main(argv: list[str] | None = None) -> int:
    """CLI:n paafunktio.

    Parsii argumentit ja kaynnistaa TUI:n tai tarkistaa syntaksin.

    Args:
        argv: Argumenttilista (oletus: sys.argv[1:])

    Returns:
        Exit-koodi (0 = onnistui, 1 = virhe)
    """
    parser = build_parser()
    args = parser.parse_args(argv)

    # --asm: tulosta konekielinen listaus ja poistu
    if args.asm is not None:
        return _print_asm(args.asm)

    # --check: tarkista syntaksi ja poistu
    if args.check is not None:
        return _check_syntax(args.check)

    # --test: suorita testiohjelma ja poistu
    if args.test is not None:
        return _run_test(args.test)

    # --test-all: suorita kaikki testit hakemistosta ja poistu
    if args.test_all is not None:
        return _run_test_all(args.test_all)

    # Kaynnista TUI
    try:
        from .tui import run_tui
    except Exception as err:
        print(f"TUI kaynnistys epaonnistui: {err}", file=sys.stderr)
        print("Asenna riippuvuus: pip install textual", file=sys.stderr)
        return 1

    return run_tui(startup_asm=args.source, startup_dsk=args.dsk)
