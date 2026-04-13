"""Tila-hallinta kCPU16 TUI:lle.

Tämä moduuli sisältää kaikki tiedoston I/O:n, assemblioinnin ja välimuistin
hallintafunktiot. Nämä funktiot erotettu pääasiassa KCPU16TUI-luokasta
modulaarisuuden parantamiseksi.

Funktiot:
    do_open          -- Avaa ja käsittelee .asm-tiedostoa
    do_assemble      -- Assembloi tiedoston ja lataa koneen muistiin
    check_file_changes -- Tarkista tiedoston muutokset (watch)
    build_asm_caches -- Rakenna assembloinnin välimuistit
    update_disk_title -- Päivitä levytiedoston otsikko
    update_program_title -- Päivitä ohjelman otsikko
    sync_speed_slider -- Synkronoi nopeusliukusäädin
    find_bootblock_jump_target -- Etsi bootblockin hyppykohde
    build_addr_to_line -- Rakenna osoite→rivi-mappi

Riippuvuudet:
    KCPU16Machine, Assembler, Disassembler, DebugState
    constants (ARCH_SYMBOLS, BOOT_RAM_START, WORD_MASK)
    disassembler (REVERSE_TABLE)
    instruction (MNEMONIC_TO_OPCODE, OPCODE_TABLE)
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from .constants import ARCH_SYMBOLS, BOOT_RAM_START, WORD_MASK
from .disassembler import REVERSE_TABLE
from .assembler import MNEMONIC_TO_OPCODE
from .instruction import OPCODE_TABLE
from .devices.storage import BlockStorageDevice

if TYPE_CHECKING:
    from .machine import KCPU16Machine
    from .assembler import Assembler
    from .debugger import DebugState
    from textual.app import App


def find_bootblock_jump_target(words: list[int]) -> tuple[str, int, int] | None:
    """Etsi bootblockin ensimmäinen eksplisiittinen hyppykohde konekielestä.

    Palauttaa ensimmäisen tavallisen ohjausrakennekäskyn, jolla on välitön
    kohdeosoite. Tämä auttaa näyttämään TUI-lokissa mihin bootloader yrittää
    siirtyä boot=1-polussa.

    Args:
        words: Bootblockin konekieli-sanat.

    Returns:
        (mnemonic, pc, target) tai None jos ei löydy.
    """
    branch_mnemonics: frozenset[str] = frozenset(
        {"JUMP", "CALL", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE"}
    )
    i = 0
    pc = BOOT_RAM_START
    while i < len(words):
        opcode = words[i] & WORD_MASK
        meta = REVERSE_TABLE.get(opcode)
        op_count = meta[1] if meta is not None else 0
        mnemonic = meta[0] if meta is not None else None
        if mnemonic in branch_mnemonics and op_count >= 1 and i + op_count < len(words):
            target = words[i + op_count] & WORD_MASK
            return mnemonic, pc, target
        i += 1 + op_count
        pc += 1 + op_count
    return None


def build_addr_to_line(source: str, assembler: Assembler) -> dict[int, int]:
    """Rakenna osoite → lähdekoodirivi -mappi assembloidusta koodista.

    Tarkoitus: Kun käyttäjä steppaa koodia (F7), editorin kursori siirtyy
    automaattisesti sille riville, joka vastaa nykyistä PC-osoitetta.
    Tämä funktio rakentaa mapin joka mahdollistaa tuon yhteyden.

    Args:
        source: Alkuperäinen lähdekoodi
        assembler: Assembler-instanssi

    Returns:
        dict[int, int]: Mappi {konekieliosoite: lähdekoodirivinumero (1-pohjainen)}
    """
    try:
        expanded, start_addr = assembler._pass0_expand_macros_and_origin(
            source, BOOT_RAM_START
        )
    except Exception:
        return {}

    original_lines = source.splitlines()
    expanded_lines = expanded.splitlines()

    # Yhdistä expanded-rivit alkuperäisiin
    exp_to_orig: dict[int, int] = {}
    orig_idx = 0
    for exp_idx, exp_line in enumerate(expanded_lines, 1):
        exp_stripped = exp_line.strip()
        found = False
        for oi in range(orig_idx, len(original_lines)):
            orig_stripped = original_lines[oi].split(";", 1)[0].strip()
            if orig_stripped == exp_stripped and exp_stripped:
                exp_to_orig[exp_idx] = oi + 1
                orig_idx = oi + 1
                found = True
                break
        if not found:
            if exp_to_orig:
                exp_to_orig[exp_idx] = max(exp_to_orig.values())
            else:
                exp_to_orig[exp_idx] = 1

    addr = start_addr
    result: dict[int, int] = {}
    exp_line_no = 0
    for raw in expanded_lines:
        exp_line_no += 1
        line = raw.split(";", 1)[0].strip()
        if not line or line.endswith(":"):
            continue
        # .at direktiivi: paivita osoitelaskuri uuteen muistiosoitteeseen
        if line.lower().startswith(".at ") or line.lower() == ".at":
            parts_at = line.split()
            if len(parts_at) >= 2:
                try:
                    addr = int(parts_at[1], 0) & 0xFFFF
                except ValueError:
                    pass
            continue
        # .db: edista osoitetta (ei suoritettavaa koodia)
        if line.lower().startswith(".db"):
            try:
                addr += len(assembler._parse_db_values(line))
            except Exception:
                pass
            continue
        # .dstr: edista osoitetta (ei suoritettavaa koodia)
        if line.lower().startswith(".dstr"):
            try:
                addr += len(assembler._parse_dstr_values(line))
            except Exception:
                pass
            continue
        mnemonic = line.replace(",", " ").split()[0].upper()
        opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
        if opcode is None:
            continue
        _, operand_count, _ = OPCODE_TABLE[opcode]
        result[addr] = exp_to_orig.get(exp_line_no, exp_line_no)
        addr += 1 + operand_count

    return result


class StateManager:
    """Apuluokka TUI:n tila-hallinnalle.
    
    Sisältää metodit, joita kutsutaan KCPU16TUI:sta tilamuutosten käsittelyyn.
    """

    def __init__(self, app: App) -> None:
        """Alusta StateManager tietyllä TUI-sovelluksella.
        
        Args:
            app: KCPU16TUI-instanssi, josta käytetään machine, assembler, jne.
        """
        self.app = app

    def do_open(self, path: Path) -> None:
        """Avaa tiedosto, tallentaa polun ja kääntää sen automaattisesti.
        
        Tiedoston olemassaolo tarkistetaan ennen latausta. Onnistuessa
        asetetaan current_file = path, tallennetaan tiedoston mtime
        tiedoston tarkkailua varten ja kutsutaan do_assemble().
        Virhetilanteessa logitetaan virhe.
        """
        try:
            if not path.exists():
                self.app._log(f"[red]File not found: {path}[/red]")
                return
            self.app.current_file = path
            self.app.is_assembled = False
            self.app.addr_to_line = {}
            self.app._watched_mtime = path.stat().st_mtime_ns
            self.app._log(f"Loaded: [bold]{path}[/bold]")
            self.update_program_title()
            self.do_assemble()
        except Exception as e:
            self.app._log(f"[red]Error: {e}[/red]")

    def do_assemble(self) -> None:
        """Assembloi ladattu tiedosto ja lataa sen koneen muistiin.

        Tämä on TUI:n keskeinen operaatio - "tiedosto → konekieli → muisti".
        """
        self.app.workers.cancel_all()
        if not self.app.current_file:
            self.app._log("[yellow]No file loaded. Use 'load <file>' or Ctrl+O.[/yellow]")
            return
        try:
            source = self.app.current_file.read_text(encoding="utf-8")
            if not source.strip():
                self.app._log("[yellow]File is empty.[/yellow]")
                return
            self.app._boot_status_text = None
            segments = self.app.assembler.assemble(
                source, source_path=self.app.current_file
            )
            bootblock_words: list[int] | None = None
            bootblock_used_words = 0
            bootblock_config = self.app.assembler.bootblock_directive
            if bootblock_config is not None:
                bootblock_words, bootblock_used_words = (
                    self.app.assembler.build_boot_block_words(
                        source_path=self.app.current_file
                    )
                )
            self.app.machine.cold_reset()
            self.app.machine.load_segments(segments)
            self.app.is_assembled = True
            try:
                self.app._watched_mtime = self.app.current_file.stat().st_mtime_ns
            except Exception:
                pass
            watched_sources: dict[Path, int | None] = {}
            if self.app.current_file is not None:
                watched_sources[self.app.current_file] = self.app._watched_mtime
            for inc in self.app.assembler.included_files:
                try:
                    watched_sources[inc] = inc.stat().st_mtime_ns
                except Exception:
                    watched_sources[inc] = None
            self.app._watched_sources = watched_sources

            includes = list(self.app.assembler.included_files)
            if includes:
                self.app._log(
                    "[dim]Includes: " + ", ".join(p.name for p in includes) + "[/dim]"
                )
            else:
                self.app._log("[dim]Includes: (none)[/dim]")
            self.build_asm_caches(segments)
            self.app.addr_to_line = build_addr_to_line(source, self.app.assembler)
            self.app.dbg.snapshot_registers(self.app.machine.dump_registers())
            total_words = sum(len(w) for _, w in segments)
            self.app._log(
                f"[green]Assembled: {total_words} words in {len(segments)} "
                f"segment(s) at 0x{self.app.machine.regs.pc:04X}. F7=Step, F5=Run.[/green]"
            )
            if bootblock_config is not None and bootblock_words is not None:
                temp_storage = BlockStorageDevice(
                    block_size_words=self.app.machine.storage.block_size_words,
                    block_count=self.app.machine.storage.block_count,
                )
                if bootblock_config.disk_path.exists():
                    temp_storage.load_from_file(bootblock_config.disk_path)
                if not bootblock_config.allow_overwrite and any(
                    temp_storage.read_block(0)
                ):
                    raise ValueError(
                        ".bootblock: target disk image already has a non-empty boot block; "
                        "use overwrite=1 to replace it"
                    )
                temp_storage.write_block(0, bootblock_words)
                temp_storage.save_to_file(bootblock_config.disk_path)
                self.app.machine.storage.load_from_file(bootblock_config.disk_path)
                self.app.current_disk_file = bootblock_config.disk_path
                self.app._disk_dirty = False
                self.update_disk_title()
                self.app._log(
                    f"[cyan].bootblock: wrote {bootblock_used_words} words to "
                    f"{bootblock_config.disk_path.name} block 0.[/cyan]"
                )
                if bootblock_config.boot_after_write:
                    self.app.machine.cold_reset()
                    self.app.machine.load_segments(segments)
                    self.app.machine.boot_from_storage()
                    jump_info = find_bootblock_jump_target(bootblock_words)
                    if jump_info is None:
                        self.app._boot_status_text = f"boot {bootblock_config.disk_path.name}: entry 0x{BOOT_RAM_START:04X}, no jump"
                        self.app._log(
                            f"[cyan].bootblock: booted from {bootblock_config.disk_path.name} "
                            f"(entry PC=0x{BOOT_RAM_START:04X}, no explicit jump target found).[/cyan]"
                        )
                    else:
                        mnemonic, jump_pc, jump_target = jump_info
                        self.app._boot_status_text = f"boot {bootblock_config.disk_path.name}: {mnemonic}@0x{jump_pc:04X} -> 0x{jump_target:04X}"
                        self.app._log(
                            f"[cyan].bootblock: booted from {bootblock_config.disk_path.name} "
                            f"(entry PC=0x{BOOT_RAM_START:04X}, first {mnemonic} @ 0x{jump_pc:04X} "
                            f"-> 0x{jump_target:04X}).[/cyan]"
                        )
            # .diskblock-direktiivi: kirjoita konekieli levyblokkiin
            blk = self.app.assembler.disk_block
            if blk is not None:
                blk_size = self.app.machine.storage.block_size_words
                code: list[int] = []
                for _, words in segments:
                    code.extend(words)
                code = (code + [0] * blk_size)[:blk_size]
                self.app.machine.storage.write_block(blk, code)
                self.app._disk_dirty = True
                self.update_disk_title()
                self.app._log(
                    f"[cyan].diskblock: {total_words} words written to "
                    f"disk block {blk}.[/cyan]"
                )
            self.app._exec_mode = "stopped"
            self.app._update_run_mode_ui()
            self.update_program_title()
            self.app._refresh_all(include_screen=True, force_screen=True)
        except Exception as e:
            self.app._log(f"[red]Assembly error: {e}[/red]")
            self.app.is_assembled = False
            self.app._exec_mode = "stopped"
            self.app._update_run_mode_ui()
            self.update_program_title()
            self.app._refresh_all(include_screen=True, force_screen=True)

    def build_asm_caches(self, segments: list[tuple[int, list[int]]]) -> None:
        """Rakenna --asm-listauksen tukitiedot assembloinnin jälkeen."""
        _BRANCH_MNEMONICS: frozenset[str] = frozenset(
            {"JUMP", "CALL", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE"}
        )
        self.app._asm_addr_to_src = {addr: src for src, addr in self.app.assembler.source_map}
        arch_addrs: set[int] = set(ARCH_SYMBOLS.values())
        self.app._asm_addr_to_label = {
            addr: name
            for name, addr in self.app.assembler.labels.items()
            if addr not in arch_addrs and name not in ARCH_SYMBOLS
        }
        jump_targets: dict[int, list[str]] = {}
        for seg_start, words in segments:
            i = 0
            pc = seg_start
            while i < len(words):
                opcode = words[i] & WORD_MASK
                meta = REVERSE_TABLE.get(opcode)
                op_count = meta[1] if meta is not None else 0
                mnemonic = meta[0] if meta is not None else None
                if (
                    mnemonic in _BRANCH_MNEMONICS
                    and op_count >= 1
                    and i + op_count < len(words)
                ):
                    target = words[i + op_count] & WORD_MASK
                    jump_targets.setdefault(target, []).append(f"{mnemonic}@{pc:04X}")
                i += 1 + op_count
                pc += 1 + op_count
        self.app._asm_jump_targets = jump_targets

    def check_file_changes(self) -> None:
        """Tarkista onko ladattu tiedosto muuttunut (1s timer)."""
        if not self.app.current_file or not self.app.current_file.exists():
            return
        try:
            if not self.app._watched_sources:
                try:
                    self.app._watched_sources = {
                        self.app.current_file: self.app.current_file.stat().st_mtime_ns
                    }
                except Exception:
                    self.app._watched_sources = {self.app.current_file: None}

            changed: list[Path] = []
            for path, old_mtime in list(self.app._watched_sources.items()):
                try:
                    mtime = path.stat().st_mtime_ns
                except Exception:
                    mtime = None
                if mtime != old_mtime:
                    changed.append(path)

            if changed:
                names = ", ".join(p.name for p in changed)
                self.app._log(f"[dim]File changed: {names}. Reloading...[/dim]")
                self.do_assemble()
        except Exception:
            pass

    def update_disk_title(self) -> None:
        """Päivitä Disassembly-paneelin alaotsikko näyttämään nykyinen levytiedosto."""
        try:
            tabs = self.app.query_one("#disasm-tabs")
            name = self.app.current_disk_file.name if self.app.current_disk_file else ""
            if self.app._disk_dirty:
                tabs.border_subtitle = f"{name} *" if name else "*"
            else:
                tabs.border_subtitle = name
        except Exception:
            pass

    def update_program_title(self) -> None:
        """Päivitä Screen-paneelin alaotsikko näyttämään ladatun .asm-tiedoston nimi."""
        try:
            screen_section = self.app.query_one("#screen-section")
            screen_section.border_subtitle = (
                self.app.current_file.name
                if (self.app.current_file and self.app.is_assembled)
                else ""
            )
        except Exception:
            pass

    def sync_speed_slider(self) -> None:
        """Synkronoi liukusäätimen arvo _slow_ips:n mukaan."""
        try:
            slider = self.app.query_one("#speed-slider")
            slider._value = self.app._slow_ips  # type: ignore
            slider.refresh()
        except Exception:
            pass
