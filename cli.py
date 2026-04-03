"""
Komentoriviliittyma (CLI) kCPU16-emulaattorille.

Tama moduuli toteuttaa kayttoliittyman eri toiminnoille:
- run: Assembloi ja suorita ohjelma
- disasm: Muunna konekieli tekstiksi
- spec: Tulosta arkkitehtuurimaaritykset
- examples: Listaa ja aja esimerkkeja
- repl: Interaktiivinen debuggeri
- tui: Graafinen kayttoliittyma (Textual)

KAYTTO:
-------
    python main.py run ohjelma.asm [--cycles N]
    python main.py disasm 0x0001 0x0002 ...
    python main.py spec
    python main.py examples [nimi] [--run] [--cycles N]
    python main.py repl
    python main.py tui

REPL-KOMENNOT:
--------------
    step           - Suorita yksi kasky
    run [n]        - Suorita n kaskya (oletus: 1000)
    regs           - Nayta rekisterien arvot
    screen         - Nayta nayton sisalto
    screen-clear   - Tyhjenna nayttomuisti
    examples       - Listaa esimerkkiohjelmat
    load <nimi>    - Lataa esimerkki muistiin
    quit           - Lopeta
"""

from __future__ import annotations

import argparse
from pathlib import Path

from .assembler import Assembler
from .constants import (
    DEFAULT_EXAMPLE_CYCLES,
    DEFAULT_REPL_CYCLES,
    DEFAULT_RUN_CYCLES,
    WORD_MASK,
)
from .disassembler import Disassembler
from .examples import get_source, list_examples
from .machine import KCPU16Machine
from .specs import format_arch_spec_report


def build_parser() -> argparse.ArgumentParser:
    """
    Rakenna komentoriviargumenttien parseri.

    Luo ArgumentParser-olion kaikilla tuetulla komennoilla
    ja niiden parametreilla.

    Returns:
        Konfiguroitu argparse.ArgumentParser
    """
    # Paaparseri
    parser = argparse.ArgumentParser(
        prog="kcpu16", description="kCPU16 emulator skeleton"
    )

    # Alikomennot
    sub = parser.add_subparsers(dest="command", required=True)

    # --------------------------------------------------------------------------
    # RUN - Assembloi ja suorita ohjelma
    # --------------------------------------------------------------------------
    run_cmd = sub.add_parser("run", help="Assemble source and run")
    run_cmd.add_argument("source", type=Path, help="Assembly source file")
    run_cmd.add_argument(
        "--cycles", type=int, default=DEFAULT_RUN_CYCLES, help="Max cycles"
    )

    # --------------------------------------------------------------------------
    # DISASM - Disassembloi konekielisanoja
    # --------------------------------------------------------------------------
    dis_cmd = sub.add_parser("disasm", help="Disassemble a raw word list")
    dis_cmd.add_argument(
        "words", nargs="+", help="Word values like 0x0001 0x0000 0x002A"
    )

    # --------------------------------------------------------------------------
    # SPEC - Tulosta arkkitehtuurimaaritykset
    # --------------------------------------------------------------------------
    sub.add_parser(
        "spec",
        help="Print CPU and memory architecture definitions",
    )

    # --------------------------------------------------------------------------
    # EXAMPLES - Listaa ja aja esimerkkeja
    # --------------------------------------------------------------------------
    ex_cmd = sub.add_parser(
        "examples",
        help="List and run built-in example programs",
    )
    ex_cmd.add_argument(
        "name",
        nargs="?",
        default=None,
        help="Example name (omit to list all)",
    )
    ex_cmd.add_argument(
        "--run",
        action="store_true",
        help="Assemble and run the example immediately",
    )
    ex_cmd.add_argument(
        "--cycles",
        type=int,
        default=DEFAULT_EXAMPLE_CYCLES,
        help="Max cycles when running (default: 50000)",
    )

    # --------------------------------------------------------------------------
    # SCREEN-CLEAR - Tyhjenna nayttomuisti
    # --------------------------------------------------------------------------
    sub.add_parser("screen-clear", help="Clear screen memory (VRAM)")

    # --------------------------------------------------------------------------
    # TUI - Graafinen kayttoliittyma
    # --------------------------------------------------------------------------
    sub.add_parser("tui", help="Launch Textual-based simulator UI")

    # --------------------------------------------------------------------------
    # REPL - Interaktiivinen debuggeri
    # --------------------------------------------------------------------------
    sub.add_parser("repl", help="Interactive debug shell")

    return parser


def _run_example(
    name: str, cycles: int, machine: KCPU16Machine, asm: Assembler
) -> None:
    """
    Aja nimetty esimerkki ja tulosta tulokset.

    Args:
        name: Esimerkin nimi (esim. "hello_regs")
        cycles: Maksimi kaskyjen maara
        machine: KCPU16Machine-instanssi
        asm: Assembler-instanssi
    """
    # Hae esimerkin lahdekoodi
    source = get_source(name)

    # Assembloi konekieleksi
    words = asm.assemble(source)

    # Alusta kone ja lataa ohjelma
    machine.cold_reset()
    machine.load_program(words)

    # Suorita
    machine.run(max_cycles=cycles)

    # Tulosta tulokset
    print(f"\nRekisterit ({machine.cpu.instruction_counter} kaskyä suoritettu):")

    # Nayta pysaytyksensyy
    if machine.process_exited:
        print("  [Prosessi lopetettiin EXIT-kaaskyllä (process_exit_requested)]")
    elif machine.cpu.halted:
        print("  [Kone pysahtyi HALT-kaaskyllä]")

    # Tulosta kaikki rekisterit
    for reg, value in machine.dump_registers().items():
        print(f"  {reg} = 0x{value:04X}  ({value})")


def run_repl(machine: KCPU16Machine, asm: Assembler) -> None:
    """
    Aja interaktiivinen REPL-debuggeri.

    Tarjoaa yksinkertaisen komentopohjaisen liittyman koneen
    ohjaamiseen. Hyodyllinen debuggaukseen ja opetteluun.

    Args:
        machine: KCPU16Machine-instanssi
        asm: Assembler-instanssi (ohjelmien latausta varten)
    """
    # Tulosta ohje
    print(
        "kCPU16 repl - komennot: step / run [n] / regs / screen / screen-clear / load <nimi> / examples / quit"
    )

    # Paakomentosilmukka
    while True:
        try:
            # Lue kayttajan syote
            cmd = input("kcpu16> ").strip()
        except (EOFError, KeyboardInterrupt):
            # Ctrl+D tai Ctrl+C lopettaa
            break

        lower = cmd.lower()

        # QUIT - Lopeta
        if lower in {"q", "quit", "exit"}:
            break

        # STEP - Suorita yksi kasky
        if lower == "step":
            machine.step()
            print("ok")
            continue

        # RUN [n] - Suorita n kaskya
        if lower.startswith("run"):
            # Parsi mahdollinen numero ("run 5000" -> 5000)
            _, _, n = lower.partition(" ")
            machine.run(int(n) if n.strip() else DEFAULT_REPL_CYCLES)
            print("ok")
            continue

        # REGS - Nayta rekisterit
        if lower == "regs":
            for reg, value in machine.dump_registers().items():
                print(f"  {reg} = 0x{value:04X}  ({value})")
            continue

        # SCREEN - Nayta nayton sisalto
        if lower == "screen":
            print(machine.render_screen())
            continue

        # SCREEN-CLEAR - Tyhjenna nayttomuisti
        if lower in {"screen-clear", "cls", "clear"}:
            machine.clear_screen_memory()
            print("Nayttomuisti nollattu.")
            continue

        # EXAMPLES - Listaa esimerkit
        if lower == "examples":
            for ex_name, desc in list_examples():
                print(f"  {ex_name:<14} {desc}")
            continue

        # LOAD <nimi> - Lataa esimerkki
        if lower.startswith("load "):
            ex_name = cmd[5:].strip()  # Saailyta alkuperainen case
            try:
                source = get_source(ex_name)
            except KeyError as err:
                print(err)
                continue
            try:
                words = asm.assemble(source)
            except ValueError as err:
                print(f"Assembler error: {err}")
                continue
            # Alista kone ja lataa ohjelma
            machine.cold_reset()
            machine.load_program(words)
            print(
                f"Ladattu '{ex_name}' ({len(words)} sanaa @ 0x0100). Kayta 'run' tai 'step'."
            )
            continue

        # Tuntematon komento
        print("Tuntematon komento. Kirjoita 'quit' lopettaaksesi.")


def main(argv: list[str] | None = None) -> int:
    """
    CLI:n paafunktio.

    Parsii argumentit ja suorittaa pyydetyn komennon.

    Args:
        argv: Argumenttilista (oletus: sys.argv[1:])

    Returns:
        Exit-koodi (0 = onnistui, 1 = virhe)
    """
    parser = build_parser()
    args = parser.parse_args(argv)

    # Luo yleiset oliot
    machine = KCPU16Machine()
    asm = Assembler()
    dis = Disassembler()

    # -------------------------------------------------------------------------
    # RUN - Assembloi ja suorita tiedosto
    # -------------------------------------------------------------------------
    if args.command == "run":
        # Lue lahdetiedosto
        source = args.source.read_text(encoding="utf-8")
        # Assembloi
        words = asm.assemble(source)
        # Alusta ja lataa
        machine.cold_reset()
        machine.load_program(words)
        # Suorita
        machine.run(max_cycles=args.cycles)
        # Tulosta rekisterit
        for reg, value in machine.dump_registers().items():
            print(f"{reg}=0x{value:04X}")
        return 0

    # -------------------------------------------------------------------------
    # DISASM - Disassembloi sanoja
    # -------------------------------------------------------------------------
    if args.command == "disasm":
        # Muunna argumentit numeroiksi
        words = [int(w, 0) & WORD_MASK for w in args.words]
        # Disassembloi ja tulosta
        print(dis.disassemble(words))
        return 0

    # -------------------------------------------------------------------------
    # SPEC - Tulosta arkkitehtuurimaaritykset
    # -------------------------------------------------------------------------
    if args.command == "spec":
        print(format_arch_spec_report())
        return 0

    # -------------------------------------------------------------------------
    # EXAMPLES - Listaa ja aja esimerkkeja
    # -------------------------------------------------------------------------
    if args.command == "examples":
        # Jos ei annettu nimea, listaa kaikki
        if args.name is None:
            print(f"{'Nimi':<14}  Kuvaus")
            print("-" * 70)
            for ex_name, desc in list_examples():
                print(f"  {ex_name:<12}  {desc}")
            print(f"\nKayta: python main.py examples <nimi> [--run] [--cycles N]")
            return 0

        # Hae tietty esimerkki
        try:
            source = get_source(args.name)
        except KeyError as err:
            print(err)
            return 1

        # Tulosta lahdekoodi
        print(f"--- {args.name} ---")
        print(source)

        # Aja jos pyydetty
        if args.run:
            _run_example(args.name, args.cycles, machine, asm)
        else:
            print("(kayta --run ajaaksesi)")
        return 0

    # -------------------------------------------------------------------------
    # SCREEN-CLEAR - Tyhjenna nayttomuisti
    # -------------------------------------------------------------------------
    if args.command == "screen-clear":
        machine.clear_screen_memory()
        print("Nayttomuisti nollattu.")
        return 0

    # -------------------------------------------------------------------------
    # TUI - Graafinen kayttoliittyma
    # -------------------------------------------------------------------------
    if args.command == "tui":
        try:
            # Yrita importata TUI-moduuli
            from .tui import run_tui
        except Exception as err:
            print(f"TUI kaynnistys epaonnistui: {err}")
            print("Asenna riippuvuus: pip install textual")
            return 1
        return run_tui()

    # -------------------------------------------------------------------------
    # REPL - Interaktiivinen debuggeri
    # -------------------------------------------------------------------------
    if args.command == "repl":
        machine.cold_reset()
        run_repl(machine, asm)
        return 0

    # Tuntematon komento (ei pitaisi tapahtua required=True takia)
    return 1
