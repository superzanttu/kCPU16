"""TUI Command Handler Mixin for kCPU16 Emulator.

This module implements all command-line interface handlers extracted from the main
KCPU16TUI app. The TUICommandsMixin class provides command parsing and execution.

Komennot:
    --- Tiedostot & assembly ---
    load <path>                  -- Avaa .asm tiedosto ja assembloi
    boot <path>                  -- Lataa .dsk ja boottaa blokista 0
    asm                          -- Käännä uudelleen ladattu tiedosto
    check                        -- Tarkista syntaksi ilman latausta
    --- CPU-ohjaus ---
    step [n]                     -- Steppaa n käskyä (oletus 1)
    run [n]                      -- Aja breakpointiin/halttiin
    stop                         -- Pysäytä CPU
    restart                      -- Käännä uudelleen ja aloita alusta
    --- Breakpointit ---
    bp <addr>                    -- Toggle breakpoint
    bp list / bp clear           -- Listaa / poista kaikki
    --- Muisti ---
    mem <addr> [count]           -- Lue muistia
    mset <addr> <value>          -- Kirjoita muistiin
    mfill <addr> <count> <value> -- Täytä muistialue
    --- Tallennustila ---
    disk <block>                 -- Näytä blokki
    disk load|save <path>        -- Lataa/tallenna .dsk (save: polku valinnainen)
    dset <block> <offset> <val>  -- Muokkaa tavu blokissa
    dfill <block> <value>        -- Täytä blokki
    mem2disk <addr> <block>      -- Kopioi muistista blokkiin
    disk2mem <block> <addr>      -- Kopioi blokki muistiin
    --- Reset ---
    reset                        -- Muisti + CPU (storage säilyy)
    reset deep                   -- Muisti + CPU + storage
    reset cpu                    -- Vain CPU (muisti säilyy)
    --- Muut ---
    gameinput [on|off|toggle]    -- Vaihda game input -tila
    cls                          -- Nollaa VRAM
    help                         -- Näytä ohje
    spec                         -- Arkkitehtuuriraportti
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

from .constants import BOOT_RAM_START, WORD_MASK
from .specs import format_arch_spec_report
from . import __version__

if TYPE_CHECKING:
    pass


# ---------------------------------------------------------------------------
# Command Result Dataclass
# ---------------------------------------------------------------------------


@dataclass
class CommandResult:
    """Komentotulkin (_execute_command) paluuarvo.

    Kapseloi komennon onnistumisen ja käyttäjälle näytettävän viestin.
    Viesti voi sisältää Rich-markupia (esim. [red]virhe[/red]).

    Attribuutit:
        ok:      True = komento onnistui, False = virhe.
        message: Käyttäjälle näytettävä teksti (Rich-markup sallittu).
                 Tyhjä merkkijono = ei näytetä mitään.
    """

    ok: bool
    message: str


# ---------------------------------------------------------------------------
# TUI Commands Mixin Class
# ---------------------------------------------------------------------------


class TUICommandsMixin:
    """Mixin class providing command-line interface handlers for KCPU16TUI.

    This class is designed to be mixed into the main KCPU16TUI app class.
    It provides methods that:
    - Parse and execute user commands from the command input
    - Access self.machine, self.assembler, self.dbg, etc.
    - Call self._log() for output
    - Update state variables like self.mem_view_addr, etc.
    - Call other app methods like self._do_open(), self._do_assemble(), etc.

    All methods return CommandResult objects with success status and message.
    """

    def _execute_command(self, command: str) -> CommandResult:
        """Komentotulkki: parsii ja suorittaa komentosyötteen.

        Komennot:
            --- Tiedostot & assembly ---
            load <path>                  -- Avaa .asm tiedosto ja assembloi
            boot <path>                  -- Lataa .dsk ja boottaa blokista 0
            asm                          -- Käännä uudelleen ladattu tiedosto
            check                        -- Tarkista syntaksi ilman latausta
            --- CPU-ohjaus ---
            step [n]                     -- Steppaa n käskyä (oletus 1)
            run [n]                      -- Aja breakpointiin/halttiin
            stop                         -- Pysäytä CPU
            restart                      -- Käännä uudelleen ja aloita alusta
            --- Breakpointit ---
            bp <addr>                    -- Toggle breakpoint
            bp list / bp clear           -- Listaa / poista kaikki
            --- Muisti ---
            mem <addr> [count]           -- Lue muistia
            mset <addr> <value>          -- Kirjoita muistiin
            mfill <addr> <count> <value> -- Täytä muistialue
            --- Tallennustila ---
            disk <block>                 -- Näytä blokki
            disk load|save <path>        -- Lataa/tallenna .dsk (save: polku valinnainen)
            dset <block> <offset> <val>  -- Muokkaa tavu blokissa
            dfill <block> <value>        -- Täytä blokki
            mem2disk <addr> <block>      -- Kopioi muistista blokkiin
            disk2mem <block> <addr>      -- Kopioi blokki muistiin
            --- Reset ---
            reset                        -- Muisti + CPU (storage säilyy)
            reset deep                   -- Muisti + CPU + storage
            reset cpu                    -- Vain CPU (muisti säilyy)
            --- Muut ---
            gameinput [on|off|toggle]    -- Vaihda game input -tila
            cls                          -- Nollaa VRAM
            help                         -- Näytä ohje
            spec                         -- Arkkitehtuuriraportti
        """
        parts = command.split()
        op = parts[0].lower()
        args = parts[1:]

        try:
            # --- Tiedostot & assembly ---
            if op == "load":
                if not args:
                    return CommandResult(False, "Usage: load <filename>")
                path = Path(" ".join(args))
                if not path.suffix:
                    path = path.with_suffix(".asm")
                if not path.is_absolute():
                    path = self.code_dir / path
                self._do_open(path)
                return CommandResult(True, "")

            if op == "boot":
                if not args:
                    return CommandResult(False, "Usage: boot <filename>")
                path = Path(" ".join(args))
                if not path.suffix:
                    path = path.with_suffix(".dsk")
                if not path.is_absolute():
                    path = self.storage_dir / path
                return self._boot_from_disk_image(path)

            if op == "asm":
                self._do_assemble()
                return CommandResult(True, "")

            if op == "check":
                return self._do_syntax_check()

            # --- CPU-ohjaus ---
            if op == "step":
                count = int(args[0], 0) if args else 1
                for _ in range(max(1, count)):
                    if self.machine.cpu.halted or self.machine.process_exited:
                        break
                    try:
                        self.machine.step()
                    except Exception as exc:
                        self._show_cpu_crash(exc)
                        return CommandResult(
                            False,
                            "[bold red]CPU kaatui — ks. Output-paneeli.[/bold red]",
                        )
                ic = self.machine.cpu.instruction_counter
                return CommandResult(True, f"Stepped {max(1, count)}. IC={ic}")

            if op == "run":
                if args:
                    # Eksplisiittinen syklimäärä: synkroninen, rajoitettu ajo
                    cycles = max(1, int(args[0], 0))
                    result = self._run_with_breakpoints(cycles)
                    return CommandResult(True, result)
                else:
                    # Ei argumenttia: loputon ajo taustasäikeessä (kuten F5)
                    if self.machine.cpu.halted or self.machine.process_exited:
                        return CommandResult(False, "CPU stopped. Reset to continue.")
                    self._log(
                        "[green]Running... (stop with 'stop' command or Reset)[/green]"
                    )
                    self._cpu_run_worker()
                    return CommandResult(True, "")

            if op == "stop":
                self.action_stop_program()
                return CommandResult(True, "")

            if op == "slow":
                # slow [n] – aseta nopeus ja käynnistä hidas suoritus
                if args:
                    ips = int(args[0], 0)
                    if not 1 <= ips <= 1000:
                        return CommandResult(False, "Speed must be 1\u20131000")
                    self._slow_ips = ips
                    self._sync_speed_slider()
                self.action_run_slow_speed()
                return CommandResult(True, "")

            if op == "restart":
                self._do_assemble()
                return CommandResult(True, "")

            # --- Breakpointit ---
            if op == "bp":
                return self._handle_bp_command(args)

            # --- Muisti ---
            if op == "mem":
                return self._handle_mem_command(args)

            if op == "mset":
                return self._handle_mset_command(args)

            if op == "mfill":
                return self._handle_mfill_command(args)

            # --- Tallennustila ---
            if op == "disk":
                return self._handle_disk_command(args)

            if op == "dset":
                return self._handle_dset_command(args)

            if op == "dfill":
                return self._handle_dfill_command(args)

            if op == "mem2disk":
                return self._handle_mem2disk_command(args)

            if op == "disk2mem":
                return self._handle_disk2mem_command(args)

            # --- Reset ---
            if op == "reset":
                return self._handle_reset_command(args)

            if op == "gameinput":
                mode = args[0].lower() if args else "toggle"
                if mode == "on":
                    if not self._game_input_mode:
                        self.action_toggle_game_input()
                elif mode == "off":
                    if self._game_input_mode:
                        self.action_toggle_game_input()
                elif mode == "toggle":
                    self.action_toggle_game_input()
                else:
                    return CommandResult(False, "Usage: gameinput [on|off|toggle]")

                state = (
                    "ON (keyboard -> emulator)"
                    if self._game_input_mode
                    else "OFF (keyboard -> TUI)"
                )
                return CommandResult(True, f"Game input mode: {state}")

            # --- Näyttö & muut ---
            if op == "cls":
                self.machine.clear_screen_memory()
                return CommandResult(True, "[green]VRAM cleared.[/green]")

            if op == "help":
                self.action_show_help()
                return CommandResult(True, "")

            if op == "spec":
                return CommandResult(True, format_arch_spec_report())

            if op == "version":
                return CommandResult(True, f"kCPU16 v{__version__}")

            if op == "speed":
                if not args:
                    return CommandResult(
                        True,
                        f"SLOW speed: {self._slow_ips} IPS (1–1000). Usage: speed <1–1000>",
                    )
                ips = int(args[0], 0)
                if not 1 <= ips <= 1000:
                    return CommandResult(False, "Speed must be 1–1000")
                self._slow_ips = ips
                self._sync_speed_slider()
                return CommandResult(True, f"SLOW speed set to {ips} IPS.")

            return CommandResult(False, f"Unknown: {op}. Type 'help'.")
        except Exception as exc:
            return CommandResult(False, f"Error: {exc}")

    def _handle_bp_command(self, args: list[str]) -> CommandResult:
        """Käsittele breakpoint-alikomennot (bp <addr> / bp list / bp clear).

        - bp <addr>: Toggle breakpoint annetussa osoitteessa (hex tai dec).
        - bp list: Listaa kaikki asetetut breakpointit.
        - bp clear: Poista kaikki breakpointit.
        - bp (ilman argumentteja): Näytä käyttöohje.
        """
        if not args:
            return CommandResult(False, "Usage: bp <addr> | bp list | bp clear")
        if args[0] == "list":
            if not self.dbg.breakpoints:
                return CommandResult(True, "No breakpoints.")
            bps = ", ".join(f"0x{a:04X}" for a in sorted(self.dbg.breakpoints))
            return CommandResult(True, f"Breakpoints: {bps}")
        if args[0] == "clear":
            self.dbg.clear_breakpoints()
            return CommandResult(True, "All breakpoints cleared.")
        addr = int(args[0], 0)
        added = self.dbg.toggle_breakpoint(addr)
        if added:
            return CommandResult(
                True, f"[yellow]Breakpoint SET at 0x{addr:04X}[/yellow]"
            )
        return CommandResult(True, f"Breakpoint REMOVED at 0x{addr:04X}")

    def _do_syntax_check(self) -> CommandResult:
        """Tarkista ladatun tiedoston assembly-koodin syntaksi ilman latausta muistiin."""
        if not self.current_file:
            return CommandResult(
                False, "[yellow]No file loaded. Use 'load <file>' first.[/yellow]"
            )
        try:
            source = self.current_file.read_text(encoding="utf-8").strip()
            if not source:
                return CommandResult(False, "[yellow]File is empty.[/yellow]")
            segments = self.assembler.assemble(source, source_path=self.current_file)
            total_words = sum(len(w) for _, w in segments)
            return CommandResult(
                True,
                f"[green]Syntax OK — {total_words} words in {len(segments)} segment(s).[/green]",
            )
        except Exception as e:
            return CommandResult(False, f"[red]Syntax error: {e}[/red]")

    def _boot_from_disk_image(self, path: Path) -> CommandResult:
        """Load a .dsk image and boot from storage block 0."""
        if not path.exists():
            return CommandResult(False, f"File not found: {path}")

        self.workers.cancel_all()
        self._exec_mode = "stopped"
        self._update_run_mode_ui()

        self.machine.storage.load_from_file(path)
        self.current_disk_file = path
        self._disk_dirty = False

        # Disk-booted program is no longer tied to currently opened .asm source.
        self.current_file = None
        self.is_assembled = False
        self.addr_to_line = {}
        self._asm_addr_to_src = {}
        self._asm_addr_to_label = {}
        self._asm_jump_targets = {}
        self._disasm_cache = {}

        self.machine.cold_reset()
        self.machine.boot_from_storage()
        self.dbg.snapshot_registers(self.machine.dump_registers())

        self._boot_status_text = f"boot {path.name}: entry 0x{BOOT_RAM_START:04X}"
        self._update_program_title()
        self._update_disk_title()
        self._exec_mode = "fast"
        self._update_run_mode_ui()
        self._refresh_all(include_screen=True, force_screen=True)
        self._cpu_run_worker("fast")
        return CommandResult(
            True,
            f"[green]Booted from {path.name}. Running fast... (F5/F8 to stop)[/green]",
        )

    def _format_hex_dump(self, words: list[int], base_addr: int) -> str:
        """Muotoile sanalista hex-dumpiksi (8 sanaa/rivi)."""
        lines: list[str] = []
        for row_start in range(0, len(words), 8):
            addr = base_addr + row_start
            row = words[row_start : row_start + 8]
            hex_part = " ".join(f"{w:04X}" for w in row)
            lines.append(f"  0x{addr:04X}: {hex_part}")
        return "\n".join(lines)

    def _handle_mem_command(self, args: list[str]) -> CommandResult:
        """Lue muistia: mem <addr> [count]."""
        if not args:
            return CommandResult(False, "Usage: mem <addr> [count]")
        addr = int(args[0], 0)
        self.mem_view_addr = addr
        if len(args) >= 2:
            count = int(args[1], 0)
            words = [self.machine.memory.read(addr + i) for i in range(count)]
            dump = self._format_hex_dump(words, addr)
            return CommandResult(True, dump)
        val = self.machine.memory.read(addr)
        return CommandResult(True, f"0x{addr:04X}: 0x{val:04X} ({val})")

    def _handle_mset_command(self, args: list[str]) -> CommandResult:
        """Kirjoita muistiin: mset <addr> <value>."""
        if len(args) < 2:
            return CommandResult(False, "Usage: mset <addr> <value>")
        addr = int(args[0], 0)
        value = int(args[1], 0)
        self.machine.memory.write(addr, value)
        return CommandResult(
            True, f"[green]0x{addr:04X} = 0x{value & WORD_MASK:04X}[/green]"
        )

    def _handle_mfill_command(self, args: list[str]) -> CommandResult:
        """Täytä muistialue: mfill <addr> <count> <value>."""
        if len(args) < 3:
            return CommandResult(False, "Usage: mfill <addr> <count> <value>")
        addr = int(args[0], 0)
        count = int(args[1], 0)
        value = int(args[2], 0)
        for i in range(count):
            self.machine.memory.write(addr + i, value)
        end = (addr + count - 1) & WORD_MASK
        return CommandResult(
            True,
            f"[green]Filled 0x{addr:04X}–0x{end:04X} with 0x{value & WORD_MASK:04X}[/green]",
        )

    def _handle_disk_command(self, args: list[str]) -> CommandResult:
        """Tallennustilan komennot: disk <block> | disk load|save <path>."""
        if not args:
            return CommandResult(
                False, "Usage: disk <block> | disk load <file> | disk save [file]"
            )
        sub = args[0].lower()
        if sub == "load":
            if len(args) < 2:
                return CommandResult(False, "Usage: disk load <filename>")
            path = Path(" ".join(args[1:]))
            if path.suffix.lower() != ".dsk":
                path = path.with_suffix(".dsk")
            if not path.is_absolute():
                path = self.storage_dir / path
            self.machine.storage.load_from_file(path)
            self.current_disk_file = path
            self.workers.cancel_all()
            self._exec_mode = "stopped"
            self._update_run_mode_ui()
            self._update_disk_title()
            return CommandResult(True, f"[green]Disk loaded from {path.name}[/green]")
        if sub == "save":
            if len(args) < 2:
                if self.current_disk_file:
                    self.machine.storage.save_to_file(self.current_disk_file)
                    self._disk_dirty = False
                    self._update_disk_title()
                    return CommandResult(
                        True,
                        f"[green]Disk saved to {self.current_disk_file.name}[/green]",
                    )
                return CommandResult(
                    False,
                    "[yellow]No disk file loaded. Use: disk save <name>[/yellow]",
                )
            path = Path(" ".join(args[1:]))
            if path.suffix.lower() != ".dsk":
                path = path.with_suffix(".dsk")
            if not path.is_absolute():
                path = self.storage_dir / path
            self.machine.storage.save_to_file(path)
            self.current_disk_file = path
            self._disk_dirty = False
            self._update_disk_title()
            return CommandResult(True, f"[green]Disk saved to {path.name}[/green]")
        block_idx = int(args[0], 0)
        data = self.machine.storage.read_block(block_idx)
        base = block_idx * self.machine.storage.block_size_words
        dump = self._format_hex_dump(data, base)
        return CommandResult(True, f"Block {block_idx}:\n{dump}")

    def _handle_dset_command(self, args: list[str]) -> CommandResult:
        """Muokkaa tallennustilaa: dset <block> <offset> <value>."""
        if len(args) < 3:
            return CommandResult(False, "Usage: dset <block> <offset> <value>")
        block = int(args[0], 0)
        offset = int(args[1], 0)
        value = int(args[2], 0)
        word_addr = block * self.machine.storage.block_size_words + offset
        self.machine.storage.write_word(word_addr, value)
        self._disk_dirty = True
        self._update_disk_title()
        return CommandResult(
            True,
            f"[green]Block {block} offset {offset} = 0x{value & WORD_MASK:04X}[/green]",
        )

    def _handle_dfill_command(self, args: list[str]) -> CommandResult:
        """Täytä tallenustilan blokki: dfill <block> <value>."""
        if len(args) < 2:
            return CommandResult(False, "Usage: dfill <block> <value>")
        block_idx = int(args[0], 0)
        value = int(args[1], 0) & WORD_MASK
        bsw = self.machine.storage.block_size_words
        data = [value] * bsw
        self.machine.storage.write_block(block_idx, data)
        self._disk_dirty = True
        self._update_disk_title()
        return CommandResult(
            True,
            f"[green]Block {block_idx} filled with 0x{value:04X}[/green]",
        )

    def _handle_mem2disk_command(self, args: list[str]) -> CommandResult:
        """Kopioi muistista yhden blokin verran sanoja levylle: mem2disk <addr> <block>."""
        if len(args) < 2:
            return CommandResult(False, "Usage: mem2disk <addr> <block>")
        addr = int(args[0], 0) & WORD_MASK
        block_idx = int(args[1], 0)
        bsw = self.machine.storage.block_size_words
        data = [self.machine.memory.read(addr + i) for i in range(bsw)]
        self.machine.storage.write_block(block_idx, data)
        self._disk_dirty = True
        self._update_disk_title()
        return CommandResult(
            True,
            f"[green]Mem 0x{addr:04X}–0x{(addr + bsw - 1) & WORD_MASK:04X} "
            f"→ disk block {block_idx}.[/green]",
        )

    def _handle_disk2mem_command(self, args: list[str]) -> CommandResult:
        """Kopioi levyblokki muistiin: disk2mem <block> <addr>."""
        if len(args) < 2:
            return CommandResult(False, "Usage: disk2mem <block> <addr>")
        block_idx = int(args[0], 0)
        addr = int(args[1], 0) & WORD_MASK
        bsw = self.machine.storage.block_size_words
        data = self.machine.storage.read_block(block_idx)
        for i, word in enumerate(data):
            self.machine.memory.write(addr + i, word)
        return CommandResult(
            True,
            f"[green]Disk block {block_idx} → mem 0x{addr:04X}–0x{(addr + bsw - 1) & WORD_MASK:04X}.[/green]",
        )

    def _handle_reset_command(self, args: list[str]) -> CommandResult:
        """Resetoi: reset | reset deep | reset cpu."""
        if not args:
            # Normaali reset: VRAM + muisti + CPU. Storage säilyy.
            self.machine.cold_reset()
            self.is_assembled = False
            self.current_disk_file = None
            self._disk_dirty = False
            self.addr_to_line = {}
            self._asm_addr_to_src = {}
            self._asm_addr_to_label = {}
            self._asm_jump_targets = {}
            self._disasm_cache = {}
            self.dbg.snapshot_registers(self.machine.dump_registers())
            self._update_program_title()
            self._update_disk_title()
            return CommandResult(
                True, "[green]Reset (memory + CPU). Storage intact.[/green]"
            )
        sub = args[0].lower()
        if sub == "deep":
            self.machine.cold_reset()
            self.machine.storage.reset()
            self.is_assembled = False
            self.current_disk_file = None
            self.addr_to_line = {}
            self._asm_addr_to_src = {}
            self._asm_addr_to_label = {}
            self._asm_jump_targets = {}
            self._disasm_cache = {}
            self.dbg.snapshot_registers(self.machine.dump_registers())
            self._disk_dirty = False
            self._update_program_title()
            self._update_disk_title()
            return CommandResult(
                True, "[green]Deep reset (memory + CPU + storage).[/green]"
            )
        if sub == "cpu":
            self.machine.cpu.reset()
            self.dbg.snapshot_registers(self.machine.dump_registers())
            return CommandResult(True, "[green]CPU reset. Memory preserved.[/green]")
        return CommandResult(False, "Usage: reset | reset deep | reset cpu")
