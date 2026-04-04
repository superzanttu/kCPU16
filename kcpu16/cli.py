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
        "--test-all",
        type=Path,
        nargs="?",
        const=Path(__file__).parent / "test",
        default=None,
        metavar="DIR",
        help="Suorita kaikki .asm-testit hakemistosta (oletus: kcpu16/test/)",
    )

    return parser


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
        asm.assemble(source)
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

    return run_test(path)


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
