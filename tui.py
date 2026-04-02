# pyright: reportMissingImports=false
"""Textual UI for interactive kCPU16 simulation control with integrated editor."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import (
    DataTable,
    Footer,
    Header,
    Input,
    RichLog,
    Static,
    Button,
    Label,
)
from textual.message import Message

from .assembler import Assembler
from .editor import SimpleEditor, AssemblySyntaxHighlighter
from .examples import get_source, list_examples
from .machine import KCPU16Machine
from .specs import format_arch_spec_report


@dataclass
class CommandResult:
    ok: bool
    message: str


class FileInputDialog(Static):
    """Yksinkertainen dialogi tiedoston nimen syöttämiselle."""

    class FileSelected(Message):
        def __init__(self, path: Path) -> None:
            super().__init__()
            self.path = path

    def __init__(self) -> None:
        super().__init__()
        self.input_path = ""

    def compose(self) -> ComposeResult:
        yield Label("File path:")
        yield Input(placeholder="/path/to/file.asm", id="file_input")
        with Horizontal():
            yield Button("OK", id="file_ok", variant="primary")
            yield Button("Cancel", id="file_cancel")


class EditorPanel(Static):
    """Editorin näyttöpaneeli."""

    def __init__(self) -> None:
        super().__init__()
        self.editor = SimpleEditor()

    def render(self) -> str:
        """Renderoi editorin sisältö."""
        if not self.editor.get_content():
            return "[dim]Editor (empty)[/dim]\nPress Ctrl+O to load a file"

        # Näytä editori syntaksivärityksellä
        highlighted = self.editor.render_highlighted(max_lines=30)
        return highlighted


class KCPU16TUI(App[None]):
    """Interactive terminal UI for the emulator with integrated editor."""

    CSS = """
    Screen {
        layout: vertical;
    }

    #header_buttons {
        height: 3;
        dock: top;
        border: solid blue;
    }

    #main_row {
        layout: horizontal;
        height: 1fr;
    }

    #editor_col {
        width: 1fr;
        height: 1fr;
        border: solid cyan;
    }

    #screen_col {
        width: 1fr;
        height: 1fr;
    }

    #screen_panel {
        border: solid green;
        height: 27;
    }

    #cpu_panel {
        border: solid yellow;
        height: 1fr;
    }

    #regs_col {
        width: 1fr;
        height: 1fr;
        border: solid magenta;
    }

    #regs_panel {
        border: solid yellow;
        height: 1fr;
    }

    #log_panel {
        border: solid magenta;
        height: 8;
        dock: bottom;
    }

    #cmd_input {
        dock: bottom;
        height: 1;
    }

    Button {
        margin: 0 1;
    }
    """

    BINDINGS = [
        Binding("ctrl+c", "quit", "Quit"),
        Binding("ctrl+o", "open_file", "Open"),
        Binding("ctrl+s", "save_file", "Save"),
        Binding("f5", "run_short", "Run 100"),
        Binding("f10", "step", "Step"),
        Binding("f9", "clear_screen", "Clear"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.machine = KCPU16Machine()
        self.assembler = Assembler()
        self.editor = SimpleEditor()
        self.current_code_path: Path | None = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)

        # Header buttons
        with Horizontal(id="header_buttons"):
            yield Label("kCPU16 Emulator with Editor", id="title_label")
            yield Button("Load (Ctrl+O)", id="btn_load", variant="primary")
            yield Button("Save (Ctrl+S)", id="btn_save")
            yield Button("New", id="btn_new")
            yield Button("Assemble", id="btn_assemble")
            yield Button("Step (F10)", id="btn_step", variant="warning")
            yield Button("Run (F5)", id="btn_run", variant="success")
            yield Button("Reset", id="btn_reset")
            yield Button("Clear (F9)", id="btn_clear")

        # Main content
        with Horizontal(id="main_row"):
            # Editor column (left)
            with Vertical(id="editor_col"):
                yield Static(id="editor_panel")

            # Screen and CPU (middle)
            with Vertical(id="screen_col"):
                yield Static(id="screen_panel")
                yield Static(id="cpu_panel")

            # Registers (right)
            with Vertical(id="regs_col"):
                yield DataTable(id="regs_panel")

        # Log and input (bottom)
        yield RichLog(id="log_panel", wrap=True, highlight=False)
        yield Input(
            placeholder="command: help, step, run [n], regs, status, screen",
            id="cmd_input",
        )
        yield Footer()

    def on_mount(self) -> None:
        regs = self.query_one("#regs_panel", DataTable)
        regs.add_columns("Register", "Hex", "Dec")

        self.machine.cold_reset()
        self._log("kCPU16 TUI started. Press Ctrl+O to open a file or Ctrl+N for new.")
        self._refresh_views()
        self.set_interval(0.25, self._refresh_views)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button clicks."""
        button_id = event.button.id

        if button_id == "btn_load":
            self.action_open_file()
        elif button_id == "btn_save":
            self.action_save_file()
        elif button_id == "btn_new":
            self.editor.set_content("")
            self.current_code_path = None
            self._log("New document created.")
            self._refresh_views()
        elif button_id == "btn_assemble":
            self._assemble_and_load()
        elif button_id == "btn_step":
            self.action_step()
        elif button_id == "btn_run":
            self.action_run_short()
        elif button_id == "btn_reset":
            self.machine.cold_reset()
            self._log("Machine reset.")
            self._refresh_views()
        elif button_id == "btn_clear":
            self.action_clear_screen()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        cmd = event.value.strip()
        event.input.value = ""
        if not cmd:
            return

        self._log(f"> {cmd}")
        result = self._execute_command(cmd)
        self._log(result.message)
        self._refresh_views()

    def action_open_file(self) -> None:
        """Open file dialog (Ctrl+O)."""
        path_str = self.query_one("#cmd_input", Input).value
        if not path_str:
            self._log("Enter file path or use: open <path>")
            return

        try:
            path = Path(path_str)
            self.editor.load_file(path)
            self.current_code_path = path
            self._log(f"Loaded: {path.name}")
            self._refresh_views()
        except Exception as e:
            self._log(f"Error loading: {e}")

    def action_save_file(self) -> None:
        """Save file (Ctrl+S)."""
        if not self.current_code_path:
            self._log("No file path. Use: save <path>")
            return

        try:
            self.editor.save_file(self.current_code_path)
            self._log(f"Saved: {self.current_code_path.name}")
        except Exception as e:
            self._log(f"Error saving: {e}")

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

    def _assemble_and_load(self) -> None:
        """Assemble editor content and load to machine."""
        try:
            code = self.editor.get_content()
            if not code.strip():
                self._log("Editor is empty. Load a file or type code.")
                return

            words = self.assembler.assemble(code)
            self.machine.cold_reset()
            self.machine.load_program(words)
            self._log(
                f"Assembled and loaded: {len(words)} words. Press F10 to step or F5 to run."
            )
            self._refresh_views()
        except Exception as e:
            self._log(f"Assembly error: {e}")

    def _execute_command(self, command: str) -> CommandResult:
        parts = command.split()
        op = parts[0].lower()
        args = parts[1:]

        try:
            if op == "help":
                return CommandResult(
                    True,
                    "Commands: step [n], run [n], reset, regs, status, screen, "
                    "open <path>, save <path>, load <name>, examples, assemble, spec",
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

            if op == "examples":
                lines = [f"- {name}: {desc}" for name, desc in list_examples()]
                return CommandResult(True, "\n".join(lines))

            if op == "load":
                if not args:
                    return CommandResult(False, "Usage: load <example-name>")
                name = args[0]
                source = get_source(name)
                self.editor.set_content(source)
                words = self.assembler.assemble(source)
                self.machine.cold_reset()
                self.machine.load_program(words)
                return CommandResult(
                    True, f"Loaded '{name}' ({len(words)} words). Ready to run."
                )

            if op == "open":
                if not args:
                    return CommandResult(False, "Usage: open <path>")
                path = Path(" ".join(args))
                self.editor.load_file(path)
                self.current_code_path = path
                return CommandResult(True, f"Opened: {path.name}")

            if op == "save":
                if not args:
                    return CommandResult(False, "Usage: save <path>")
                path = Path(" ".join(args))
                self.editor.save_file(path)
                self.current_code_path = path
                return CommandResult(True, f"Saved: {path.name}")

            if op == "assemble":
                return self._assemble_and_load_result()

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

            return CommandResult(False, f"Unknown command: {op}")
        except Exception as exc:
            return CommandResult(False, f"Error: {exc}")

    def _assemble_and_load_result(self) -> CommandResult:
        """Assemble and return result."""
        try:
            code = self.editor.get_content()
            words = self.assembler.assemble(code)
            self.machine.cold_reset()
            self.machine.load_program(words)
            return CommandResult(
                True, f"Assembled: {len(words)} words loaded. Ready to run."
            )
        except Exception as e:
            return CommandResult(False, f"Assembly error: {e}")

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
        editor_panel = self.query_one("#editor_panel", Static)
        screen_panel = self.query_one("#screen_panel", Static)
        cpu_panel = self.query_one("#cpu_panel", Static)
        regs_table = self.query_one("#regs_panel", DataTable)

        # Update editor
        editor_panel.update(self.editor.render_highlighted(max_lines=30))

        # Update screen
        screen_panel.update("SCREEN 80x25\n" + self.machine.render_screen())

        # Update CPU status
        cpu_panel.update("CPU STATUS\n" + self._status_text())

        # Update registers
        regs_table.clear(columns=False)
        for name, value in self.machine.dump_registers().items():
            regs_table.add_row(name, f"0x{value:04X}", str(value))

    def _log(self, message: str) -> None:
        self.query_one("#log_panel", RichLog).write(message)


def run_tui() -> int:
    app = KCPU16TUI()
    app.run()
    return 0
