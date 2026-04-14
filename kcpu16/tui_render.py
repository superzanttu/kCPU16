"""TUI render mixin for kCPU16 emulator.

This module contains all display/rendering-related methods extracted from the main
KCPU16TUI application. These methods are collected into TUIRenderMixin, which is
inherited by KCPU16TUI to keep rendering logic separated from command/control logic.

When used as a mixin, the inheriting class provides access to:
  - self.machine: KCPU16Machine instance
  - self.dbg: DebugState instance
  - self.disassembler: Disassembler instance
  - self.query_one(): Textual widget query method
  - self._log(): Logging method (stays in app, called from mixin)
  - self.mem_view_addr, self.addr_to_line, etc.: Render state variables
"""

from __future__ import annotations

import re

from rich.text import Text
from textual.widgets import Static

from .constants import (
    GFX_MODE_B,
    GFX_MODE_C,
    GFX_MODE_REG,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    VRAM_START,
    WORD_MASK,
)
from .disassembler import REVERSE_TABLE
from .instruction import OPCODE_TABLE


# ---------------------------------------------------------------------------
# Constants: Register names, operand type sets, mnemonics
# ---------------------------------------------------------------------------

# Poistaa Rich-markup-tagit (esim. [bold], [/red], [dim]) pelkään tekstiksi
_RICH_MARKUP_RE = re.compile(r"\[/?[^\[\]]+?\]")

# Rekisteri-indeksi -> nimi
# Disassembler palauttaa operandit numeerisina arvoina (esim. "0, 42").
# Ihmisen on vaikea lukea "LOAD 0, 42" - paljon selkeämpi on "LOAD R0, #42".
# REG_NAMES muuntaa konekielen rekisteri-indeksit luettaviksi nimiksi.
REG_NAMES = {
    0: "R0",
    1: "R1",
    2: "R2",
    3: "R3",
    4: "R4",
    5: "R5",
    6: "R6",
    7: "R7",
    8: "R8",
    9: "R9",
    10: "R10",
    11: "R11",
    12: "R12",
    13: "R13",
    14: "R14",
    15: "R15",
    16: "FP",
    17: "SP",
}

# Käskyt joissa 1. operandi on rekisteri-indeksi (esim. LOAD R0, ...)
_REG_FIRST = {
    "LOAD",
    "CPY",
    "ADD",
    "ADC",
    "SUB",
    "MUL",
    "DIV",
    "CMP",
    "AND",
    "OR",
    "XOR",
    "NOT",
    "SHL",
    "SHR",
    "PUSH",
    "POP",
    "SWSP",
    "SMPR",
    "STMR",
    "SCTMR",
    "DREAD",
    "DWRITE",
    "TSL",
}

# Käskyt joissa myös 2. operandi on rekisteri-indeksi (esim. ADD R0, R1)
_REG_SECOND = {
    "CPY",
    "ADD",
    "ADC",
    "SUB",
    "MUL",
    "DIV",
    "CMP",
    "AND",
    "OR",
    "XOR",
    "SHL",
    "SHR",
    "SWSP",
    "DREAD",
    "DWRITE",
}

# Hyppy/kutsukäskyt joissa viimeinen operandi on kohdeosoite (labelinimi)
_BRANCH_MNEMONICS: frozenset[str] = frozenset(
    {"JUMP", "CALL", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE"}
)


class TUIRenderMixin:
    """Mixin class providing all display/rendering methods for KCPU16TUI.

    This mixin extracts render-related logic from the main KCPU16TUI app,
    keeping the codebase organized by separating UI rendering from control flow.

    Instance variables (initialized in KCPU16TUI.__init__):
      - _last_screen_render: str = ""
      - _last_screen_lines: list[str] | None = None
      - _last_vram_version: int = -1
      - _last_gfx_mode: int = -1
      - _text_fast_mode: bool = True
      - _disasm_cache: dict[tuple[int, tuple[int, ...]], str] = {}
      - _w_disasm_content: Static | None = None
      - _w_regs_content: Static | None = None
      - _w_flags_content: Static | None = None
      - _w_screen_view: Static | None = None
      - _w_memory_view: Static | None = None
      - _w_stack_view: Static | None = None
      - _boot_status_text: str | None = None
      - _asm_addr_to_src: dict[int, str] = {}
      - _asm_addr_to_label: dict[int, str] = {}
      - _asm_jump_targets: dict[int, list[str]] = {}

    Accessed from inheriting class:
      - self.machine: KCPU16Machine instance (cpu, regs, memory, screen)
      - self.dbg: DebugState instance (breakpoints, snapshots)
      - self.disassembler: Disassembler instance
      - self.mem_view_addr: int (current memory view start address)
      - self.addr_to_line: dict[int, int] (pc -> source line number)
      - self._exec_mode: str (execution mode: stopped/step/fast/max/slow)
      - self._slow_ips: int, self._slow_multiplier: int
      - self.process_exited: bool
      - self.query_one(selector: str, expect_type=None) -> Widget
      - self._log(message: str) -> None
    """

    # ------------------------------------------------------------------
    # Näkymien päivitys (View updates)
    # ------------------------------------------------------------------

    def _refresh_all(
        self, include_screen: bool = False, force_screen: bool = False
    ) -> None:
        """Päivitä kaikki näkymäpaneelit kerralla.

        Kutsutaan jokaisen tilan muutoksen jälkeen (step, run, reset,
        assemble, komentosyöte).

        Parametrit:
            include_screen: Jos True, päivittää myös VRAM-näytön (Screen-tab).
                            Käytä True stepissä ja suoritustilan vaihtuessa.
            force_screen:   Jos True, ohitetaan kaksoisbufferointi ja renderöidään
                            suoraan VRAMista (käytetään step/done/stop-tiloissa).
        """
        self._refresh_disassembly()
        self._refresh_registers()
        self._refresh_flags()
        self._refresh_cpu_status()
        if include_screen:
            self._refresh_screen_tab(force=force_screen)
        self._refresh_memory()
        self._refresh_stack()

    def _refresh_disassembly(self) -> None:
        """Päivitä disassembly-paneeli PC:n ympäriltä (--asm-formaatti).

        Näyttöikkuna:
            - Skannaa taaksepäin PC:stä max 15 osoitetta.
            - Eteenpäin max 80 osoitetta PC:n jälkeen.
            - Ohittaa tyhjät muistipaikat paitsi PC:n lähellä tai BP:ssa.

        Joka käskyrivillä näytetään:
            ● ▶ ADDR: HEX_SANAT   MNEMONIC OPERANDIT   ; lähdekoodi

            ● = breakpoint (punainen)   ▶ = nykyinen PC (korostettu tausta)
            ADDR syaanilla, mnemoniikki keltaisella, rekisterit sinisellä,
            välittömät arvot vihreällä, lähdekomentit himmennettyinä.

        Jump target -merkit (label-nimi) näytetään ennen hyppykohdetä olevaa
        käskyriviä.

        Optimointi: Disassembler-kutsut cachetan. Cache invalidoidaan ohjelman
        latauksen yhteydessä (_do_assemble).
        """
        pc = self.machine.regs.pc

        # -- Scan window --
        scan_start = max(0, pc - 15)
        start = pc
        for a in range(pc - 1, scan_start - 1, -1):
            if self.machine.memory.read(a) != 0 or self.dbg.has_breakpoint(a):
                start = a
            else:
                break
        if self.dbg.breakpoints:
            for bp_addr in self.dbg.breakpoints:
                if scan_start <= bp_addr < start:
                    start = bp_addr
        start = max(start, pc - 10)
        end = min(WORD_MASK, pc + 80)

        lines: list[str] = []
        addr = start
        while addr <= end:
            opcode = self.machine.memory.read(addr)
            meta = REVERSE_TABLE.get(opcode)
            if meta is None:
                instr_words = [opcode]
                disasm_tail = f".word 0x{opcode:04X}"
                op_count = 0
            else:
                mnemonic, op_count, _ = meta
                instr_words = [
                    self.machine.memory.read(addr + i) for i in range(1 + op_count)
                ]
                # Etsi cachesta ennen kutsua disassembler.disassemble()
                cache_key = (addr, tuple(instr_words))
                if cache_key in self._disasm_cache:
                    disasm_tail = self._disasm_cache[cache_key]
                else:
                    raw = self.disassembler.disassemble(
                        instr_words, start_addr=addr
                    ).strip()
                    disasm_tail = raw.split(": ", 1)[1] if ": " in raw else raw
                    self._disasm_cache[cache_key] = disasm_tail

            # Skip .word 0x0000 unless near PC or on a breakpoint
            if (
                disasm_tail == ".word 0x0000"
                and addr != pc
                and abs(addr - pc) > 3
                and not self.dbg.has_breakpoint(addr)
            ):
                addr += 1 + op_count
                continue

            # Jump-target separator line (label name)
            if addr in self._asm_jump_targets:
                label = self._asm_addr_to_label.get(addr, f"0x{addr:04X}")
                srcs = "  ".join(self._asm_jump_targets[addr])
                lines.append(
                    f"[dim]\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500"
                    f" [bold]{label}[/bold]: \u2190 {srcs}[/dim]"
                )

            # Hex bytes column — pad to fixed width
            # Max instruction = 3 words = "XXXX XXXX XXXX" = 14 chars
            hex_str = " ".join(f"{w:04X}" for w in instr_words)

            # Rich-colored mnemonic + operands
            disasm_rich = self._fmt_disasm_tail(disasm_tail)

            # Source comment (instruction text only, strip inline comments)
            src_line = self._asm_addr_to_src.get(addr, "")
            src_clean = src_line.split(";", 1)[0].strip()

            # Pad the disasm column to a fixed VISUAL width so the comment
            # column stays aligned. Rich markup tags add invisible characters;
            # also \[ and \] are Rich literal-bracket escapes that each render
            # as a single character, so strip tags first then convert escapes.
            DISASM_VIS_WIDTH = 26
            _stripped = (
                _RICH_MARKUP_RE.sub("", disasm_rich)
                .replace("\\[", "[")
                .replace("\\]", "]")
            )
            disasm_visible_len = len(_stripped)
            disasm_pad = " " * max(0, DISASM_VIS_WIDTH - disasm_visible_len)
            src_part = f"{disasm_pad}  [dim]; {src_clean}[/dim]" if src_clean else ""

            # BP and PC markers
            bp_marker = (
                "[bold red]\u25cf[/] " if self.dbg.has_breakpoint(addr) else "  "
            )

            if addr == pc:
                lines.append(
                    f"{bp_marker}[bold white on #3a3a3a]"
                    f"\u25b6 {addr:04X}: {hex_str:<14}  {disasm_rich}[/]"
                    f"{src_part}"
                )
            else:
                lines.append(
                    f"{bp_marker}  [cyan]{addr:04X}[/]: "
                    f"{hex_str:<14}  {disasm_rich}"
                    f"{src_part}"
                )

            addr += 1 + op_count

        if self._w_disasm_content:
            self._w_disasm_content.update("\n".join(lines))

    def _refresh_registers(self) -> None:
        """Päivitä rekisteripaneeli kahdessa sarakkeessa.

        Näyttää kaikki rekisterit (R0–R15, FP, SP, PC, SR, MPR, TMR, CTMR)
        kahdessa vierekkäisessä sarakkeessa. Käyttää dbg.snapshot_registers()
        -metodia vertaamaan edelliseen tilaan - muuttuneet rekisterit
        korostetaan punaisella boldilla, muuttumattomat näytetään syaanilla.
        """
        regs = self.machine.dump_registers()
        changed = self.dbg.snapshot_registers(regs)

        names = list(regs.keys())
        half = (len(names) + 1) // 2

        def fmt_cell(name: str) -> str:
            """Format one register cell with change highlighting."""
            value = regs[name]
            h = f"0x{value:04X}"
            d = f"{value:>5}"
            if changed.get(name, False):
                return f"[bold yellow]{name:>4} {h} {d}[/]"
            else:
                return f"[cyan]{name:>4}[/] {h} {d}"

        lines: list[str] = []
        for i in range(half):
            left = fmt_cell(names[i])
            if i + half < len(names):
                right = fmt_cell(names[i + half])
                lines.append(f"{left}  {right}")
            else:
                lines.append(left)

        if self._w_regs_content:
            self._w_regs_content.update("\n".join(lines))

    def _refresh_flags(self) -> None:
        """Päivitä lippupaneeli (SR-rekisterin yksittäiset bitit).

        Näyttää jokaisen lipun erikseen:
        - Z (Zero), N (Negative), C (Carry), V (Overflow), I (Interrupt),
          P (Privilege)
        - Asetettu lippu (1): vihreä bold
        - Nollattu lippu (0): himmennetty (dim)
        - Moodi: KERNEL (vihreä) tai USER (keltainen)
        - Uptime: 32-bitin sekuntilaskuri HH:MM:SS -muodossa
        - TMR/CTMR: säädettävissä olevien keskeytysten tila
        """
        r = self.machine.regs
        cpu = self.machine.cpu
        flags = [
            ("Z", r.get_flag(SR_FLAG_Z)),
            ("N", r.get_flag(SR_FLAG_N)),
            ("C", r.get_flag(SR_FLAG_C)),
            ("V", r.get_flag(SR_FLAG_V)),
            ("I", r.get_flag(SR_FLAG_I)),
            ("P", r.get_flag(SR_FLAG_P)),
        ]
        # Show each flag as name:value on one line for clarity
        parts = []
        for name, val in flags:
            if val:
                parts.append(f"[bold green]{name}:1[/]")
            else:
                parts.append(f"[dim]{name}:0[/]")
        mode = "[bold green]KERNEL[/]" if r.in_kernel_mode else "[yellow]USER[/]"

        # Uptime (32-bit seconds)
        uptime = cpu._uptime_counter & 0xFFFFFFFF
        hours = uptime // 3600
        mins = (uptime % 3600) // 60
        secs = uptime % 60
        uptime_str = f"{hours:02d}:{mins:02d}:{secs:02d}"

        # Configurable interrupt states with remaining time
        if r.tmr > 0:
            remaining_tmr = max(0, cpu._next_tmr_time_us - cpu._simulated_time_us)
            tmr_str = f"[green]{r.tmr}[/] µs (next: {remaining_tmr} µs)"
        else:
            tmr_str = "[dim]off[/]"
        if r.ctmr > 0:
            remaining_ctmr = max(0, cpu._next_ctmr_time_us - cpu._simulated_time_us)
            ctmr_str = f"[green]{r.ctmr}[/] ms (next: {remaining_ctmr // 1000} ms)"
        else:
            ctmr_str = "[dim]off[/]"

        # Graphics mode (GFX_MODE_REG)
        gfx_val = self.machine.memory.read(GFX_MODE_REG)
        if gfx_val == 0:
            gfx_str = "[dim]A (text)[/]"
        elif gfx_val == 1:
            gfx_str = "[cyan]B (80×48)[/]"
        elif gfx_val == 2:
            gfx_str = "[cyan]C (160×96)[/]"
        else:
            gfx_str = f"[yellow]{gfx_val}[/]"

        content = (
            f"{' '.join(parts)}\n"
            f"Mode: {mode}\n"
            f"Uptime: {uptime_str}\n"
            f"TMR:  {tmr_str}\n"
            f"CTMR: {ctmr_str}\n"
            f"GFX:  {gfx_str}\n"
            f"Boot: {self._boot_status_text or '[dim]n/a[/]'}"
        )
        if self._w_flags_content:
            self._w_flags_content.update(content)

    def _refresh_cpu_status(self) -> None:
        """Päivitä CPU-tilapaneeli.

        Näyttää kaksi erillistä tilatietoa:
        - Prog: ohjelman lataus/kääntämistila (NO PROG / NOT LOADED / READY)
        - CPU:  suoritustila (STOPPED / STEP / FAST / MAX / SLOW / HALTED / EXITED)
        - Cycles: suoritettujen käskyjen kokonaismäärä
        - Breakpoint-lista: kaikki asetetut breakpointit (jos on)
        """
        cpu = self.machine.cpu

        # Program state (loading / assembling related)
        if not self.current_file:
            prog_state = "[dim]NO PROG[/]"
        elif not self.is_assembled:
            prog_state = "[yellow]NOT LOADED[/]"
        else:
            prog_state = "[bold green]READY[/]"

        # CPU execution state
        if cpu.halted:
            cpu_state = "[bold red]HALTED[/]"
        elif cpu.process_exit_requested:
            cpu_state = "[bold yellow]EXITED[/]"
        elif self._exec_mode == "fast":
            cpu_state = "[bold green]▶ FAST[/]"
        elif self._exec_mode == "max":
            cpu_state = "[bold green]▶ MAX[/]"
        elif self._exec_mode == "slow":
            ips = self._slow_ips * self._slow_multiplier
            cpu_state = f"[bold green]▶ SLOW ({ips} IPS)[/]"
        elif self._exec_mode == "step":
            cpu_state = "[cyan]◼ STEP[/]"
        else:
            cpu_state = "[bold green]◼ STOPPED[/]"

        lines = [
            f"Prog: {prog_state}",
            f"CPU:  {cpu_state}",
            f"Cycles: {cpu.instruction_counter}",
        ]
        if self.dbg.breakpoints:
            bp_list = ", ".join(f"0x{a:04X}" for a in sorted(self.dbg.breakpoints))
            lines.append(f"[dim]BP: {bp_list}[/dim]")
        self.query_one("#cpu-content", Static).update("\n".join(lines))

    def _refresh_screen_tab(self, force: bool = False) -> None:
        """Päivitä Screen-näytön VRAM-renderöinti (1s timer).

        Kaksoisbufferointi on käytössä vain grafiikkatiloissa B ja C.
        Tekstitilassa (A) renderöidään aina suoraan VRAMista.

        Dirty-flag optimointi: Tarkista VRAM-versio (inkrementoidaan VRAM-
        kirjoituksissa) ja GFX_MODE, jotta vältetään turhaa renderöintiä kun
        VRAM ei ole muuttunut.

        Parametrit:
            force: Jos True, ohitetaan etupuskuri ja renderöidään suoraan
                   VRAMista (käytetään step- ja done-tiloissa).
        """
        try:
            screen = self.machine.screen
            memory = self.machine.memory
            mode = memory.read(GFX_MODE_REG)
            vram_version = screen.get_vram_version()
            # NOTE: Text-only fast path drops VRAM color attributes (FG/BG),
            # so colored backgrounds (e.g. C64 demo) appear black.
            # Keep colors correct by always using color-aware rendering in mode A.
            use_text_fast = False

            # Dirty-check: Jos VRAM ei ole muuttunut ja GFX_MODE ei muuttunut (paitsi force)
            # Tekstitilassa voidaan ohittaa suoraan viime renderiin.
            if (
                not force
                and vram_version == self._last_vram_version
                and mode == self._last_gfx_mode
                and (mode == 0 or screen.has_front_buffer)
            ):
                if mode == 0:
                    rendered = self._last_screen_render
                else:
                    rendered = screen.get_front_buffer()
            elif mode in (GFX_MODE_B, GFX_MODE_C):
                # Grafiikkatilat B/C: kaksoisbufferointi käytössä.
                # Etupuskuri renderöidään atomisesti CPU._write_word():ssä kun
                # GFX_FLIP_REG kirjoitetaan — ei täältä, jotta vältytään race
                # conditionilta (VRAM saattaa olla jo tyhjennetty/osittain piirretty).
                if force or not screen.has_front_buffer:
                    # Step-tila tai ensimmäinen kehys: renderöi suoraan VRAMista
                    rendered = screen.render_auto(memory)
                else:
                    # Näytä viimeisin atomiesti flipattu kehys
                    rendered = screen.get_front_buffer()
            else:
                # Tekstitila A: renderöi aina värit säilyttävällä polulla.
                rendered = screen.render_auto(memory)

            # Päivitä tracked versiot (dirty-checkia varten seuraavaa kutsua)
            self._last_vram_version = vram_version
            self._last_gfx_mode = mode

            if rendered != self._last_screen_render:
                self._last_screen_render = rendered
                if mode == 0:
                    self._last_screen_lines = rendered.split("\n")
                else:
                    self._last_screen_lines = None
                if self._w_screen_view:
                    self._w_screen_view.update(rendered)
        except Exception:
            pass

    def _refresh_memory(self) -> None:
        """Päivitä Memory-välilehden hex dump -näkymä.

        Näyttää 16 rivia x 8 sanaa = 128 sanaa alkaen mem_view_addr:sta.
        Muistiosoitetta voi vaihtaa 'mem <addr>' -komennolla.

        Formaatti (joka rivi):
            ADDR: XXXX XXXX XXXX XXXX XXXX XXXX XXXX XXXX  ASCII
        - ADDR: osoite syaanilla (4-bittinen hex)
        - XXXX: sanan arvo hex-muodossa (16-bittinen)
        - ASCII: sanan alemman tavun tulostettava merkki (tai '.')
        """
        addr = self.mem_view_addr
        lines = [f"[bold]Memory at 0x{addr:04X}:[/]\n"]
        for row in range(16):
            row_addr = addr + row * 8
            if row_addr > WORD_MASK:
                break
            hex_parts = []
            ascii_parts = []
            for col in range(8):
                a = row_addr + col
                if a > WORD_MASK:
                    hex_parts.append("    ")
                    ascii_parts.append(" ")
                else:
                    word = self.machine.memory.read(a)
                    hex_parts.append(f"{word:04X}")
                    ch = chr(word & 0xFF)
                    ascii_parts.append(ch if 32 <= ord(ch) < 127 else ".")
            lines.append(
                f"[cyan]{row_addr:04X}[/]: "
                f"{' '.join(hex_parts)}  [dim]{''.join(ascii_parts)}[/]"
            )
        if self._w_memory_view:
            self._w_memory_view.update("\n".join(lines))

    def _refresh_stack(self) -> None:
        """Päivitä Stack-välilehden pinonäkymä.

        Näyttää 20 sanaa SP:n yläpuolelta (SP+1 ylöspäin, koska SP
        osoittaa viimeksi pushattuun arvoon). Ensimmäinen rivi (SP+1)
        merkitään → -nuolella. Jokainen rivi näyttää osoitteen, arvon
        hex-muodossa ja desimaaliarvon.
        """
        sp = self.machine.regs.sp
        lines = [f"[bold]Stack (SP=0x{sp:04X}):[/]\n"]
        for i in range(20):
            addr = (sp + 1 + i) & WORD_MASK
            word = self.machine.memory.read(addr)
            marker = "[yellow]\u2192[/] " if i == 0 else "  "
            lines.append(f"{marker}[cyan]{addr:04X}[/]: 0x{word:04X}  ({word})")
        if self._w_stack_view:
            self._w_stack_view.update("\n".join(lines))

    # ------------------------------------------------------------------
    # Formatting helpers
    # ------------------------------------------------------------------

    def _fmt_disasm_tail(self, disasm_tail: str) -> str:
        """Muotoile mnemoniikka + operandit Rich-väreillä (ilman osoite-etuliitettä)."""
        tokens = disasm_tail.split(None, 1)
        if not tokens:
            return disasm_tail
        mnemonic = tokens[0]
        operands = tokens[1] if len(tokens) > 1 else ""
        fmt_ops = self._fmt_operands(mnemonic, operands)
        return f"[bold white]{mnemonic:<10}[/] {fmt_ops}"

    def _fmt_disasm_line(self, line: str) -> str:
        """Muotoile disassembly-rivi värikoodein (käytetään step-logissa)."""
        parts = line.split(":", 1)
        if len(parts) < 2:
            return line
        addr = parts[0].strip()
        rest = parts[1].strip()
        tokens = rest.split(None, 1)
        if not tokens:
            return f"[cyan]{addr}[/]: {rest}"
        mnemonic = tokens[0]
        operands = tokens[1] if len(tokens) > 1 else ""
        fmt_ops = self._fmt_operands(mnemonic, operands)
        return f"[cyan]{addr}[/]: [bold white]{mnemonic:<10}[/] {fmt_ops}"

    def _fmt_operands(self, mnemonic: str, ops_str: str) -> str:
        """Muunna operandit luettavaan muotoon (rekisterinimet, värit).

        Käsittelee kolmea muotoa:
        1. Valmiiksi nimetty rekisteri (esim. "R0") → sininen
        2. Hakasulkuinen muistiviite (esim. "[0x0300]", "[R1]", "[FP+2]") →
           hakasulut literaaleina, sisältö värikkäänä
        3. Vanhan muodon heksaluku (esim. "0x0000") → _REG_FIRST/_REG_SECOND
           -taulukoiden perusteella joko rekisterinimi (sininen) tai arvo (vihreä)
        """
        if not ops_str:
            return ""
        _REG_NAMES_SET = set(REG_NAMES.values())  # {"R0","R1","R2","R3","FP","SP"}
        ops = [o.strip() for o in ops_str.split(",")]
        result = []
        for i, op in enumerate(ops):
            if not op:
                continue

            # 1. Valmiiksi nimetty rekisteri ("R0", "FP", jne.)
            if op in _REG_NAMES_SET:
                result.append(f"[blue]{op}[/]")
                continue

            # 2. Hakasulkuinen muistiviite: [addr], [reg], [FP+offset]
            if op.startswith("[") and op.endswith("]"):
                inner = op[1:-1].strip()
                if "+" in inner:
                    base_str, off_str = inner.split("+", 1)
                    base_str = base_str.strip()
                    off_str = off_str.strip()
                    base_fmt = (
                        f"[blue]{base_str}[/]"
                        if base_str in _REG_NAMES_SET
                        else f"[green]{base_str}[/]"
                    )
                    try:
                        off_val = (
                            int(off_str, 16)
                            if off_str.startswith("0x")
                            else int(off_str)
                        )
                        off_fmt = f"[green]{off_val}[/]"
                    except ValueError:
                        off_fmt = off_str
                    result.append(f"\\[{base_fmt}+{off_fmt}\\]")
                elif inner in _REG_NAMES_SET:
                    result.append(f"\\[[blue]{inner}[/]\\]")
                else:
                    try:
                        addr_val = (
                            int(inner, 16) if inner.startswith("0x") else int(inner)
                        )
                        result.append(f"\\[[green]0x{addr_val:04X}[/]\\]")
                    except ValueError:
                        result.append(f"\\[{inner}\\]")
                continue

            # 3. Vanhan muodon heksaluku (ei-muistioperaatioiden operandit)
            try:
                val = int(op, 16) if op.startswith("0x") else int(op)
            except ValueError:
                result.append(op)
                continue
            # Hypyn kohdeosoite → labelinimi jos tunnetaan
            if mnemonic in _BRANCH_MNEMONICS and i == len(ops) - 1:
                label = self._asm_addr_to_label.get(val)
                if label:
                    result.append(f"[bold magenta]{label}[/]")
                else:
                    result.append(f"[green]0x{val:04X}[/]")
            elif (i == 0 and mnemonic in _REG_FIRST) or (
                i == 1 and mnemonic in _REG_SECOND
            ):
                name = REG_NAMES.get(val, f"?{val}")
                result.append(f"[blue]{name}[/]")
            else:
                result.append(f"[green]0x{val:04X}[/]")
        return ", ".join(result)

    def _log_step_info(self) -> None:
        """Logita yksityiskohdat viimeisestä stepistä.

        Näyttää lokissa:
        - IC (Instruction Counter): käskyjen kokonaislaskuri
        - PC: nykyinen osoite
        - Käsky: mnemoniikki + operandit (disassembloitu muistista)
        - Rivinumero: vastaava lähdekoodirivi (jos addr_to_line löytää)
        - HALT/EXIT-ilmoitus jos CPU pysähtyi

        Käskyn tunnistus tehdään lukemalla opcode PC:n kohdalta muistista
        ja hakemalla se OPCODE_TABLE:sta (mnemoniikki + operandien määrä).
        """
        pc = self.machine.regs.pc
        ic = self.machine.cpu.instruction_counter
        opcode = self.machine.memory.read(pc)
        if opcode in OPCODE_TABLE:
            _, op_count, _ = OPCODE_TABLE[opcode]
            words = [opcode] + [
                self.machine.memory.read(pc + 1 + j) for j in range(op_count)
            ]
            raw = self.disassembler.disassemble(words, start_addr=pc)
            instr = raw.split(":", 1)[1].strip() if ":" in raw else raw
        else:
            instr = f".word 0x{opcode:04X}"

        line_info = ""
        line_no = self.addr_to_line.get(pc)
        if line_no:
            line_info = f" [dim](line {line_no})[/dim]"
        self._log(f"[dim]IC={ic}[/dim] PC=0x{pc:04X}: [bold]{instr}[/bold]{line_info}")
        if self.machine.cpu.halted:
            self._log("[bold red]CPU halted (HALT).[/bold red]")
        elif self.process_exited:
            self._log("[bold yellow]Process exited (EXIT).[/bold yellow]")

    def _show_cpu_crash(self, exc: Exception) -> None:
        """Näytä yksityiskohtainen kaatumisraportti CPU-poikkeuksesta.

        Kutsutaan kun machine.step() nostaa käsittelemättömän poikkeuksen.
        Kirjoittaa Output-paneeliin:
          - Virheen tyyppi ja viesti
          - Vikaantunut käsky (PC + disassembloitu mnemoniikka)
          - Tilaliput (Z/N/C/V/I/P) ja suoritustila
          - Kaikki rekisteriarvot (R0–R15, FP, SP, PC, SR)
          - Pinon yläosa (SP+1 … SP+5)

        Pysäyttää CPU:n (halted=True) ja siirtää TUI:n stopped-tilaan.
        """
        r = self.machine.regs
        cpu = self.machine.cpu
        pc = r.pc

        # Pysäytä CPU
        cpu.halted = True
        self._exec_mode = "stopped"

        sep = "[bold red]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/bold red]"
        self._log(sep)
        self._log("[bold red]  CPU CRASHED — EXECUTION ERROR[/bold red]")
        self._log(f"[red]{type(exc).__name__}: {exc}[/red]")

        # Vikaava käsky (disassembloitu)
        try:
            opcode = self.machine.memory.read(pc)
            if opcode in OPCODE_TABLE:
                _, op_count, _ = OPCODE_TABLE[opcode]
                words = [opcode] + [
                    self.machine.memory.read(pc + 1 + j) for j in range(op_count)
                ]
                raw = self.disassembler.disassemble(words, start_addr=pc)
                instr = raw.split(":", 1)[1].strip() if ":" in raw else raw
            else:
                instr = f".word 0x{opcode:04X}"
        except Exception:
            instr = "???"
        line_no = self.addr_to_line.get(pc)
        line_str = f" [dim](line {line_no})[/dim]" if line_no else ""
        self._log(f"PC=0x{pc:04X}:  [bold]{instr}[/bold]{line_str}")

        # Flags
        flags = [
            ("Z", r.get_flag(SR_FLAG_Z)),
            ("N", r.get_flag(SR_FLAG_N)),
            ("C", r.get_flag(SR_FLAG_C)),
            ("V", r.get_flag(SR_FLAG_V)),
            ("I", r.get_flag(SR_FLAG_I)),
            ("P", r.get_flag(SR_FLAG_P)),
        ]
        flag_str = "  ".join(
            f"[bold green]{n}:1[/]" if v else f"[dim]{n}:0[/]" for n, v in flags
        )
        mode_str = "[bold green]KERNEL[/]" if r.in_kernel_mode else "[yellow]USER[/]"
        self._log(f"Flags:  {flag_str}  Mode: {mode_str}")

        # Rekisteriarvot (R0–R15, FP, SP, PC, SR)
        reg_pairs = [(f"R{i}", getattr(r, f"r{i}")) for i in range(16)]
        reg_pairs += [("FP", r.fp), ("SP", r.sp), ("PC", r.pc), ("SR", r.sr)]
        for i in range(0, len(reg_pairs), 4):
            chunk = reg_pairs[i : i + 4]
            row = "  ".join(f"[yellow]{n}[/]=0x{v:04X}" for n, v in chunk)
            self._log(row)

        # Pinon yläosa (SP+1 … SP+5, pino kasvaa alaspäin)
        sp = r.sp
        try:
            items = []
            for offset in range(1, 6):
                addr = (sp + offset) & 0xFFFF
                val = self.machine.memory.read(addr)
                items.append(f"0x{addr:04X}→0x{val:04X}")
            self._log(f"[dim]Stack (SP=0x{sp:04X}): {' | '.join(items)}[/dim]")
        except Exception:
            pass

        self._log(sep)

        # Päivitä UI
        self._update_run_mode_ui()
        self._refresh_all(include_screen=True, force_screen=True)

    def _set_max_stale_visual_state(self, max_mode_active: bool) -> None:
        """Himmennä paneelit, joita ei päivitetä MAX-ajon aikana.

        MAX-tilassa vain Screen-paneelia päivitetään reaaliaikaisesti,
        joten disassembly-, flags- ja register-paneelit merkitään
        visuaalisesti "ei reaaliaikaisiksi" himmentämällä niitä.
        """
        target_ids = ("#disasm-tabs", "#flags-pane", "#regs-pane")
        for target_id in target_ids:
            try:
                widget = self.query_one(target_id)
                if max_mode_active:
                    widget.add_class("max-stale")
                else:
                    widget.remove_class("max-stale")
            except Exception:
                continue

        # Tee MAX-tilassa ei-päivittyvistä paneeleista lähes taustaväriset,
        # jotta käyttäjä näkee heti että sisältö on stale.
        if max_mode_active:
            for content_id in (
                "#disasm-content",
                "#flags-content",
                "#cpu-content",
                "#regs-content",
                "#memory-view",
                "#stack-view",
            ):
                self._apply_stale_snapshot(content_id)

    def _apply_stale_snapshot(self, widget_id: str) -> None:
        """Korvaa Static-widgetin sisältö himmeällä tekstisnapshotilla.

        Muuntaa nykyisen renderöinnin plain-tekstiksi ja piirtää sen
        lähes taustavärillä. Tämä tekee stale-paneelista selkeästi
        erottuvan myös terminaaliteemoissa, joissa opacity ei toimi.
        """
        try:
            widget = self.query_one(widget_id, Static)
            renderable = widget.renderable
            plain = (
                renderable.plain if hasattr(renderable, "plain") else str(renderable)
            )
            widget.update(Text(plain, style="#2f2f2f"))
        except Exception:
            pass

    def _format_hex_dump(self, words: list[int], base_addr: int) -> str:
        """Muotoile sanalista hex-dumpiksi (8 sanaa/rivi)."""
        lines: list[str] = []
        for row_start in range(0, len(words), 8):
            addr = base_addr + row_start
            row = words[row_start : row_start + 8]
            hex_part = " ".join(f"{w:04X}" for w in row)
            lines.append(f"  0x{addr:04X}: {hex_part}")
        return "\n".join(lines)
