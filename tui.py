# pyright: reportMissingImports=false
"""Textual UI for interactive kCPU16 simulation control."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import DataTable, Footer, Header, Input, RichLog, Static

from .assembler import Assembler
from .examples import get_source, list_examples
from .machine import KCPU16Machine
from .specs import format_arch_spec_report


@dataclass
class CommandResult:
    ok: bool
    message: str


class KCPU16TUI(App[None]):
    """Interactive terminal UI for the emulator."""

    CSS = """
    Screen {
        layout: vertical;
    }

    #main_row {
        layout: horizontal;
        height: 1fr;
    }

    #left_col {
        width: 3fr;
        height: 1fr;
    }

    #right_col {
        width: 2fr;
        height: 1fr;
    }

    #screen_panel {
        border: solid green;
        height: 26;
    }

    #cpu_panel {
        border: solid cyan;
        height: 7;
    }

    #regs_panel {
        border: solid yellow;
        height: 1fr;
    }

    #log_panel {
        border: solid magenta;
        height: 1fr;
    }

    #cmd_input {
        dock: bottom;
    }
    """

    BINDINGS = [
        Binding("ctrl+c", "quit", "Quit"),
        Binding("f5", "run_short", "Run 100"),
        Binding("f10", "step", "Step"),
        Binding("f9", "clear_screen", "Clear VRAM"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.machine = KCPU16Machine()
        self.assembler = Assembler()

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)

        with Horizontal(id="main_row"):
            with Vertical(id="left_col"):
                yield Static(id="screen_panel")
                yield Static(id="cpu_panel")
            with Vertical(id="right_col"):
                yield DataTable(id="regs_panel")
                yield RichLog(id="log_panel", wrap=True, highlight=False)

        yield Input(placeholder="command: help", id="cmd_input")
        yield Footer()

    def on_mount(self) -> None:
        regs = self.query_one("#regs_panel", DataTable)
        regs.add_columns("Register", "Hex", "Dec")

        self.machine.cold_reset()
        self._log("kCPU16 Textual UI started. Type 'help' for commands.")
        self._refresh_views()
        self.set_interval(0.25, self._refresh_views)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        cmd = event.value.strip()
        event.input.value = ""
        if not cmd:
            return

        self._log(f"> {cmd}")
        result = self._execute_command(cmd)
        self._log(result.message)
        self._refresh_views()

    def action_run_short(self) -> None:
        self.machine.run(max_cycles=100)
        self._log("Ran 100 cycles.")
        self._refresh_views()

    def action_step(self) -> None:
        self.machine.step()
        self._log("Stepped 1 cycle.")
        self._refresh_views()

    def action_clear_screen(self) -> None:
        self.machine.clear_screen_memory()
        self._log("VRAM cleared.")
        self._refresh_views()

    def _execute_command(self, command: str) -> CommandResult:
        parts = command.split()
        op = parts[0].lower()
        args = parts[1:]

        try:
            if op == "help":
                return CommandResult(
                    True,
                    "Commands: help, step [n], run [n], reset, regs, status, screen, "
                    "screen-clear, examples, load <name>, loadfile <path>, spec, clearlog",
                )

            if op == "step":
                count = int(args[0], 0) if args else 1
                for _ in range(max(1, count)):
                    self.machine.step()
                return CommandResult(True, f"Stepped {max(1, count)} cycle(s).")

            if op == "run":
                cycles = int(args[0], 0) if args else 1000
                self.machine.run(max_cycles=max(1, cycles))
                return CommandResult(True, f"Ran up to {max(1, cycles)} cycle(s).")

            if op == "reset":
                self.machine.cold_reset()
                return CommandResult(True, "Machine reset.")

            if op == "screen-clear":
                self.machine.clear_screen_memory()
                return CommandResult(True, "VRAM cleared.")

            if op == "examples":
                lines = [f"- {name}: {desc}" for name, desc in list_examples()]
                return CommandResult(True, "\n".join(lines))

            if op == "load":
                if not args:
                    return CommandResult(False, "Usage: load <example-name>")
                name = args[0]
                source = get_source(name)
                words = self.assembler.assemble(source)
                self.machine.cold_reset()
                self.machine.load_program(words)
                return CommandResult(
                    True, f"Loaded example '{name}' ({len(words)} words)."
                )

            if op == "loadfile":
                if not args:
                    return CommandResult(False, "Usage: loadfile <path-to-asm>")
                path = Path(" ".join(args))
                source = path.read_text(encoding="utf-8")
                words = self.assembler.assemble(source)
                self.machine.cold_reset()
                self.machine.load_program(words)
                return CommandResult(
                    True, f"Loaded file '{path}' ({len(words)} words)."
                )

            if op == "regs":
                regs = self.machine.dump_registers()
                out = []
                for name, value in regs.items():
                    out.append(f"{name}=0x{value:04X} ({value})")
                return CommandResult(True, "\n".join(out))

            if op == "status":
                return CommandResult(True, self._status_text())

            if op == "screen":
                return CommandResult(True, self.machine.render_screen())

            if op == "spec":
                return CommandResult(True, format_arch_spec_report())

            if op == "clearlog":
                self.query_one("#log_panel", RichLog).clear()
                return CommandResult(True, "Log cleared.")

            return CommandResult(False, f"Unknown command: {op}")
        except Exception as exc:  # pragma: no cover - runtime guard
            return CommandResult(False, f"Error: {exc}")

    def _status_text(self) -> str:
        cpu = self.machine.cpu
        mode = "HALTED" if cpu.halted else "RUNNING"
        if self.machine.process_exited:
            mode = "PROCESS_EXIT"
        return (
            f"State: {mode}\n"
            f"Cycles: {cpu.instruction_counter}\n"
            f"PC: 0x{self.machine.regs.pc:04X}\n"
            f"SP: 0x{self.machine.regs.sp:04X}\n"
            f"SR: 0x{self.machine.regs.sr:04X}"
        )

    def _refresh_views(self) -> None:
        screen_panel = self.query_one("#screen_panel", Static)
        cpu_panel = self.query_one("#cpu_panel", Static)
        regs_table = self.query_one("#regs_panel", DataTable)

        screen_panel.update("SCREEN 80x24\n" + self.machine.render_screen())
        cpu_panel.update("CPU STATUS\n" + self._status_text())

        regs_table.clear(columns=False)
        for name, value in self.machine.dump_registers().items():
            regs_table.add_row(name, f"0x{value:04X}", str(value))

    def _log(self, message: str) -> None:
        self.query_one("#log_panel", RichLog).write(message)


def run_tui() -> int:
    app = KCPU16TUI()
    app.run()
    return 0
