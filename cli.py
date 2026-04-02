"""Simple command-line control UI for the kCPU16 machine."""

from __future__ import annotations

import argparse
from pathlib import Path

from .assembler import Assembler
from .disassembler import Disassembler
from .examples import get_source, list_examples
from .machine import KCPU16Machine
from .specs import format_arch_spec_report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="kcpu16", description="kCPU16 emulator skeleton"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run_cmd = sub.add_parser("run", help="Assemble source and run")
    run_cmd.add_argument("source", type=Path, help="Assembly source file")
    run_cmd.add_argument("--cycles", type=int, default=10000, help="Max cycles")

    dis_cmd = sub.add_parser("disasm", help="Disassemble a raw word list")
    dis_cmd.add_argument(
        "words", nargs="+", help="Word values like 0x0001 0x0000 0x002A"
    )

    sub.add_parser(
        "spec",
        help="Print CPU and memory architecture definitions",
    )

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
        default=50000,
        help="Max cycles when running (default: 50000)",
    )

    sub.add_parser("screen-clear", help="Clear screen memory (VRAM)")
    sub.add_parser("tui", help="Launch Textual-based simulator UI")

    sub.add_parser("repl", help="Interactive debug shell")

    return parser


def _run_example(
    name: str, cycles: int, machine: KCPU16Machine, asm: Assembler
) -> None:
    source = get_source(name)
    words = asm.assemble(source)
    machine.cold_reset()
    machine.load_program(words)
    machine.run(max_cycles=cycles)
    print(f"\nRekisterit ({machine.cpu.instruction_counter} kaskyä suoritettu):")
    if machine.process_exited:
        print("  [Prosessi lopetettiin EXIT-kaaskyllä (process_exit_requested)]")
    elif machine.cpu.halted:
        print("  [Kone pysahtyi HALT-kaaskyllä]")
    for reg, value in machine.dump_registers().items():
        print(f"  {reg} = 0x{value:04X}  ({value})")


def run_repl(machine: KCPU16Machine, asm: Assembler) -> None:
    print(
        "kCPU16 repl - komennot: step / run [n] / regs / screen / screen-clear / load <nimi> / examples / quit"
    )
    while True:
        try:
            cmd = input("kcpu16> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        lower = cmd.lower()
        if lower in {"q", "quit", "exit"}:
            break
        if lower == "step":
            machine.step()
            print("ok")
            continue
        if lower.startswith("run"):
            _, _, n = lower.partition(" ")
            machine.run(int(n) if n.strip() else 1000)
            print("ok")
            continue
        if lower == "regs":
            for reg, value in machine.dump_registers().items():
                print(f"  {reg} = 0x{value:04X}  ({value})")
            continue
        if lower == "screen":
            print(machine.render_screen())
            continue
        if lower in {"screen-clear", "cls", "clear"}:
            machine.clear_screen_memory()
            print("Nayttomuisti nollattu.")
            continue
        if lower == "examples":
            for ex_name, desc in list_examples():
                print(f"  {ex_name:<14} {desc}")
            continue
        if lower.startswith("load "):
            ex_name = cmd[5:].strip()
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
            machine.cold_reset()
            machine.load_program(words)
            print(
                f"Ladattu '{ex_name}' ({len(words)} sanaa @ 0x0100). Kayta 'run' tai 'step'."
            )
            continue
        print("Tuntematon komento. Kirjoita 'quit' lopettaaksesi.")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    machine = KCPU16Machine()
    asm = Assembler()
    dis = Disassembler()

    if args.command == "run":
        source = args.source.read_text(encoding="utf-8")
        words = asm.assemble(source)
        machine.cold_reset()
        machine.load_program(words)
        machine.run(max_cycles=args.cycles)
        for reg, value in machine.dump_registers().items():
            print(f"{reg}=0x{value:04X}")
        return 0

    if args.command == "disasm":
        words = [int(w, 0) & 0xFFFF for w in args.words]
        print(dis.disassemble(words))
        return 0

    if args.command == "spec":
        print(format_arch_spec_report())
        return 0

    if args.command == "examples":
        if args.name is None:
            print(f"{'Nimi':<14}  Kuvaus")
            print("-" * 70)
            for ex_name, desc in list_examples():
                print(f"  {ex_name:<12}  {desc}")
            print(f"\nKayta: python main.py examples <nimi> [--run] [--cycles N]")
            return 0
        try:
            source = get_source(args.name)
        except KeyError as err:
            print(err)
            return 1
        print(f"--- {args.name} ---")
        print(source)
        if args.run:
            _run_example(args.name, args.cycles, machine, asm)
        else:
            print("(kayta --run ajaaksesi)")
        return 0

    if args.command == "screen-clear":
        machine.clear_screen_memory()
        print("Nayttomuisti nollattu.")
        return 0

    if args.command == "tui":
        try:
            from .tui import run_tui
        except Exception as err:
            print(f"TUI kaynnistys epaonnistui: {err}")
            print("Asenna riippuvuus: pip install textual")
            return 1
        return run_tui()

    if args.command == "repl":
        machine.cold_reset()
        run_repl(machine, asm)
        return 0

    return 1
