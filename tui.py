# pyright: reportMissingImports=false
"""Ammattimainen Textual TUI kCPU16-emulaattorille.

Tämä moduuli toteuttaa kCPU16-emulaattorin päätason käyttöliittymän.
Se on debuggeri-tyylinen TUI (Text User Interface), joka yhdistää
lähdekoodieditorin, reaaliaikaisen disassemblyn, rekisterinäkymän,
muistinäkymän ja VRAM-näytön yhteen interaktiiviseen sovellukseen.

Inspiroitu MARS/RARS, GDB TUI, Turbo Debugger ja emu8086 -ohjelmistoista.

Tärkeimmät luokat:
    KCPU16TUI       -- Päätason Textual App -sovellus (koko käyttöliittymä).
    CommandResult   -- Komentotulkin paluuarvo (ok/virhe + viesti).

Tärkeimmät funktiot:
    _build_addr_to_line  -- Rakentaa konekieliosoite → lähdekoodirivi -mapin.
    run_tui              -- Käynnistää TUI:n (entry point).

Riippuvuudet:
    Textual >= 0.80 (testattu 0.82.1): App, TextArea, TabbedContent, RichLog
    Rich (Textual sisältää): Rich-markup värikoodeihin

Tietovirta:
    1. Käyttäjä kirjoittaa assembly-koodin editoriin (TextArea)
    2. Ctrl+B → _do_assemble() kutsuu Assembler.assemble() → konekielisanat
    3. Machine.cold_reset() + load_program() → sanat muistiin osoitteesta 0x0100
    4. _build_addr_to_line() → osoite→rivi -mappi kursoria varten
    5. F7/Step → machine.step() → _refresh_all() päivittää kaikki paneelit
    6. Disassembler lukee muistia PC:n ympäriltä ja näyttää disassemblyn

Layout:
  ┌─ Toolbar (Open|Save|New | Assemble ^B | Step F7|Run F5|Reset ^R | BP F2)
  ├──────────────┬─────────────────────┬─────────────────────────────┤
  │ SCREEN       │ DISASSEMBLY/MEM/STK │ SOURCE EDITOR               │
  │ (80x24 VRAM) │ (TabbedContent)     │ (TextArea, muokk.)          │
  │              │ ●=breakpoint        │ rivinumerot                 │
  │              │ ▶=nykyinen PC       │ kursori seuraa PC           │
  ├──────────────┴─────────────────────┤                             │
  │ LOG (lokiviestit)                  │                             │
  ├────────────────────────────────────┤                             │
  │ COMMANDS (komentotulosteet)        │                             │
  ├────────────────────────────────────┴─────────────────────────────┤
  │ > komentosyöte      │ FLAGS Z N C V I P  │ REGISTERS             │
  │                     │ CPU state/cycles   │ (muuttuneet=punainen) │
  └─────────────────────┴────────────────────┴───────────────────────┘
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import (
    Button,
    Input,
    RichLog,
    Static,
    TabbedContent,
    TabPane,
    TextArea,
)

from .assembler import Assembler, MNEMONIC_TO_OPCODE
from .constants import (
    BOOT_RAM_START,
    DEFAULT_RUN_CYCLES,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    WORD_MASK,
)
from .debugger import DebugState
from .disassembler import Disassembler

from .instruction import OPCODE_TABLE
from .machine import KCPU16Machine
from .specs import format_arch_spec_report


# ---------------------------------------------------------------------------
# Rekisteri-indeksi -> nimi
#
# Disassembler palauttaa operandit numeerisina arvoina (esim. "0, 42").
# Ihmisen on vaikea lukea "LOAD 0, 42" - paljon selkeämpi on "LOAD R0, #42".
# REG_NAMES muuntaa konekielen rekisteri-indeksit luettaviksi nimiksi.
# _REG_FIRST ja _REG_SECOND kertovat, mitkä käskyt odottavat rekisteriä
# missäkin operandipositiossa, jotta _fmt_operands() osaa päätellä
# onko numero rekisteri-indeksi vai välitön arvo.
# ---------------------------------------------------------------------------

REG_NAMES = {0: "R0", 1: "R1", 2: "R2", 3: "R3", 4: "FP", 5: "SP"}

# Käskyt joissa 1. operandi on rekisteri-indeksi (esim. LOAD R0, ...)
_REG_FIRST = {
    "LOAD",
    "CPY",
    "READ",
    "STORE",
    "READ_IND",
    "STORE_IND",
    "READ_REL",
    "STORE_REL",
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
    "DREAD",
    "DWRITE",
    "KGET",
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
    "READ_IND",
    "STORE_IND",
    "SWSP",
    "DREAD",
    "DWRITE",
}


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
# Lähdekoodi -> osoite -kartoitus (makrotuki)
# ---------------------------------------------------------------------------


def _build_addr_to_line(source: str, assembler: Assembler) -> dict[int, int]:
    """Rakenna osoite → lähdekoodirivi -mappi assembloidusta koodista.

    Tarkoitus: Kun käyttäjä steppaa koodia (F7), editorin kursori siirtyy
    automaattisesti sille riville, joka vastaa nykyistä PC-osoitetta.
    Tämä funktio rakentaa mapin joka mahdollistaa tuon yhteyden.

    Makrotuki - miksi kaksi vaihetta:
        1. Pass 0 (expand macros): Assemblerin makrot laajennetaan, jolloin
           yksi lähdekoodirivi voi tuottaa useita expanded-rivejä.
           Expanded-koodin rivinumerot EI vastaa alkuperäisiä.
        2. exp_to_orig -mappi: Yhdistää jokaisen expanded-rivin takaisin
           alkuperäiseen lähdekoodirivinumeroon vertaamalla rivien sisältöä.
           Jos vastaavuutta ei löydy (makroista syntyneet rivit), käytetään
           edellisen vastanneen rivin numeroa.

    Osoite→rivi -mapin rakentaminen:
        - Käy expanded-koodin läpi rivi kerrallaan
        - Ohittaa tyhjät rivit ja labelit (eivät tuota konekieltä)
        - Tunnistaa mnemoniikin ja hakee sen opcode-taulusta
        - Laskee osoitteen: addr += 1 + operandien_määrä (käskysana + operandit)
        - Tallentaa result[addr] = alkuperäinen rivinumero

    Parametrit:
        source:    Alkuperäinen lähdekoodi (editorin sisältö).
        assembler: Assembler-instanssi (tarvitaan makrolaajennukseen).

    Palauttaa:
        dict[int, int]: Mappi {konekieliosoite: lähdekoodirivinumero (1-pohjainen)}.
        Tyhjä dict jos makrolaajennus epäonnistuu.
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
        mnemonic = line.replace(",", " ").split()[0].upper()
        opcode = MNEMONIC_TO_OPCODE.get(mnemonic)
        if opcode is None:
            continue
        _, operand_count, _ = OPCODE_TABLE[opcode]
        result[addr] = exp_to_orig.get(exp_line_no, exp_line_no)
        addr += 1 + operand_count

    return result


# ===========================================================================
# TUI-sovellus
# ===========================================================================


class KCPU16TUI(App[None]):
    """Päätason Textual-sovellus: kCPU16 emulaattori-debuggeri.

    Tämä on koko TUI:n juuriluokka. Se luo kaikki widgetit (editori,
    disassembly, rekisterit, jne.), hallinnoi koneen tilaa ja välittää
    käyttäjän syötteet (näppäimet, painikkeet, komennot) oikeille toiminnoille.

    Instanssimuuttujat:
        machine       -- KCPU16Machine: CPU + muisti + laitteet.
        assembler     -- Assembler: kääntää assembly → konekieli.
        disassembler  -- Disassembler: konekieli → luettava assembly.
        dbg           -- DebugState: breakpointit + rekisterimuutosten seuranta.
                         HUOM: self.dbg (EI self.debug), koska Textual App:ssa
                         on sisäänrakennettu debug-property.
        current_file  -- Avatun tiedoston polku (None = ei tallennettu).
        mem_view_addr -- Memory-näkymän aloitusosoite (oletus 0x0100).
        addr_to_line  -- Osoite → lähdekoodirivi -mappi (_build_addr_to_line).
        is_assembled  -- True kun koodi on assembloitu ja ladattu muistiin.

    Widget-hierarkia:
        Toolbar (Horizontal + Buttonit) → content-area (Horizontal):
            left-panel: top-section (Horizontal):
                            screen-section (Static, VRAM 80x24)
                            disasm-tabs (TabbedContent: Disassembly|Memory|Stack)
                        output-pane (RichLog, kaikki tulosteet + komentosyöte)
            editor-pane: TextArea (koko korkeus)
        → bottom-bar (Horizontal):
            cmd-input-col (Input) | flags-pane (Flags+CPU) | regs-pane (Registers)

    Päivityslogiikka:
        _refresh_all() kutsutaan jokaisen muutoksen jälkeen (step, run, reset,
        assemble). Se päivittää kaikki paneelit synkronisesti. Timer-pollausta
        ei käytetä, paitsi Screen-välilehti päivittyy 0.5s välein (VRAM voi
        muuttua IO-operaatioilla ilman explisiittistä refreshiä).
    """

    TITLE = "kCPU16 Emulator"
    SUB_TITLE = "16-bit CPU Emulator"

    # Textual CSS: Määrittelee koko sovelluksen visuaalisen layoutin.
    #
    # Rakenne ylhäältä alas:
    #   1. #toolbar          - Yläpalkki: painikkeet (dock: top, height: 3)
    #   2. #content-area     - Pääalue (height: 1fr, horizontal):
    #      - #left-panel     - Vasen paneeli (width: 142): Screen+Disasm | Log | Cmds
    #        - #top-section  - Yläosa (horizontal): Screen (82) + Disasm tabs (60)
    #        - #output-pane   - Tulosteet + komentosyöte (height: 1fr)
    #      - #editor-pane    - Oikea sarake (width: 1fr): Editori (koko korkeus)
    #   3. #bottom-bar       - Alarivi (dock: bottom, horizontal):
    #      - #cmd-input-col  - Komentosyöte (width: 142, 1 rivi)
    #      - #flags-pane     - Liput + CPU-tila (width: auto)
    #      - #regs-pane      - Rekisterit (width: 1fr)
    CSS = """
    Screen {
        layout: vertical;
        background: $surface;
    }

    /* ---- Toolbar ---- */
    #toolbar {
        height: 3;
        dock: top;
        background: $panel;
        layout: horizontal;
    }
    #toolbar Button {
        min-width: 8;
        height: 3;
        margin: 0 0;
    }
    #toolbar .sep {
        width: 1;
        height: 3;
    }

    /* ---- Content area ---- */
    #content-area {
        height: 1fr;
        layout: horizontal;
    }

    /* -- Left panel: Screen+Disasm top, Log+CmdOutput bottom -- */
    #left-panel {
        width: 142;
        layout: vertical;
    }
    #top-section {
        height: 26;
        layout: horizontal;
    }
    #screen-section {
        width: 82;
        height: 26;
        border: solid $primary-darken-2;
        border-title-color: $accent;
    }
    #screen-view-solo {
        width: 80;
        height: 24;
    }
    #disasm-tabs {
        width: 1fr;
        height: 1fr;
        border: solid $success-darken-1;
        border-title-color: $accent;
    }
    TabPane {
        padding: 0;
    }
    TabPane VerticalScroll {
        height: 1fr;
    }
    #disasm-content {
        padding: 0 1;
    }
    #memory-view {
        padding: 0 1;
    }
    #stack-view {
        padding: 0 1;
    }
    #output-pane {
        height: 1fr;
        border: solid $primary-darken-2;
        border-title-color: $accent;
    }
    #output-view {
        height: 1fr;
    }

    /* -- Right column: Editor (full height) -- */
    #editor-pane {
        width: 1fr;
        min-width: 30;
        border: solid $primary-darken-2;
        border-title-color: $accent;
    }
    #editor-pane TextArea {
        height: 1fr;
    }

    /* ---- cmd-input inside output-pane ---- */
    #cmd-input {
        dock: bottom;
        width: 1fr;
    }

    /* ---- Bottom bar: Flags+CPU | Registers ---- */
    #bottom-bar {
        dock: bottom;
        height: auto;
        max-height: 14;
        layout: grid;
        grid-size: 3;
        grid-columns: 142 28 1fr;
    }
    #flags-pane {
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }
    #regs-pane {
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }
    """

    # Näppäinsidonnaisuudet (Textual Binding).
    # priority=True tarkoittaa, että nämä toimivat myös TextArea:n ollessa
    # aktiivinen (muuten TextArea kaappaisi näppäimen).
    # Sidonnaisuudet näkyvät myös Footerissa automaattisesti.
    BINDINGS = [
        Binding("ctrl+q", "quit", "Quit", priority=True),
        Binding("f2", "toggle_breakpoint", "BP F2", priority=True),
        Binding("f5", "run_program", "Run F5", priority=True),
        Binding("f7", "step_once", "Step F7", priority=True),
        Binding("f10", "step_once", "Step", priority=True),
        Binding("ctrl+r", "reset_machine", "Reset", priority=True),
        Binding("ctrl+o", "open_file", "Open", priority=True),
        Binding("ctrl+s", "save_file", "Save", priority=True),
        Binding("ctrl+b", "assemble_code", "Asm ^B", priority=True),
        Binding("f9", "clear_screen", "Clr F9", priority=True),
        Binding("f1", "show_help", "Help F1", priority=True),
    ]

    def __init__(self) -> None:
        """Alusta TUI-sovellus ja sen sisäinen tila.

        Luo emulaattorikomponentit (machine, assembler, disassembler, dbg)
        ja asettaa oletusarvot. Tässä vaiheessa widgettejä ei vielä ole
        luotu - ne syntyvät compose()-metodissa.

        Instanssimuuttujat:
            machine       -- CPU-emulaattori (muisti, rekisterit, laitteet).
            assembler     -- Assembly → konekieli -kääntäjä.
            disassembler  -- Konekieli → assembly -purkaja.
            dbg           -- Debug-tila (breakpointit, rekisterisnapshot).
            current_file  -- Avoinna oleva tiedostopolku (None aluksi).
            mem_view_addr -- Memory-tabin näyttöosoite (oletus 0x0100).
            addr_to_line  -- PC-osoite → editorin rivinumero -mappi.
            is_assembled  -- Onko koodi assembloitu muistiin.
        """
        super().__init__()
        self.machine = KCPU16Machine()
        self.assembler = Assembler()
        self.disassembler = Disassembler()
        self.dbg = DebugState()
        self.current_file: Path | None = None
        self.code_dir: Path = Path(__file__).resolve().parent / "code"
        self.code_dir.mkdir(exist_ok=True)
        self.mem_view_addr: int = BOOT_RAM_START
        self.addr_to_line: dict[int, int] = {}
        self.is_assembled: bool = False
        self._last_screen_render: str = ""

    # ------------------------------------------------------------------
    # Layout
    # ------------------------------------------------------------------

    def compose(self) -> ComposeResult:
        """Rakenna sovelluksen widget-puu (Textual compose -pattern).

        Widget-hierarkia:
            Toolbar (#toolbar): Open, Save, New, Assemble, Step, Run, Reset,
                                BP, Clear, Help -painikkeet
            Content area (#content-area, Horizontal):
                #left-panel (Vertical, 142 lev.):
                    #top-section (Horizontal):
                        #screen-section: Static (VRAM 80x24)
                        #disasm-tabs (TabbedContent: Disassembly|Memory|Stack)
                    #output-pane: RichLog (kaikki tulosteet) + Input (komentosyöte)
                #editor-pane (Vertical, 1fr, koko korkeus):
                    TextArea (lähdekoodieditori)
            Bottom bar (#bottom-bar, Horizontal):
                #cmd-input-col: Input (komentosyöte, 142 lev., 1 rivi)
                #flags-pane: Flags + CPU-tila
                #regs-pane: Rekisterit
        """
        # Toolbar
        with Horizontal(id="toolbar"):
            yield Button("Open", id="btn-open", variant="default")
            yield Button("Save", id="btn-save", variant="default")
            yield Button("New", id="btn-new", variant="default")
            yield Static(" ", classes="sep")
            yield Button("Assemble ^B", id="btn-asm", variant="primary")
            yield Static(" ", classes="sep")
            yield Button("Step F7", id="btn-step", variant="warning")
            yield Button("Run F5", id="btn-run", variant="success")
            yield Button("Reset ^R", id="btn-reset", variant="error")
            yield Static(" ", classes="sep")
            yield Button("BP F2", id="btn-bp", variant="default")
            yield Button("Clear F9", id="btn-clear", variant="default")
            yield Button("Help F1", id="btn-help", variant="default")

        # Content area: left panel + editor
        with Horizontal(id="content-area"):
            # Left panel: Screen+Disasm top, Log+CmdOutput bottom
            with Vertical(id="left-panel"):
                with Horizontal(id="top-section"):
                    with Vertical(id="screen-section"):
                        yield Static(id="screen-view-solo")
                    with TabbedContent(id="disasm-tabs"):
                        with TabPane("Disassembly", id="tab-disasm"):
                            with VerticalScroll():
                                yield Static(id="disasm-content")
                        with TabPane("Memory", id="tab-memory"):
                            with VerticalScroll():
                                yield Static(id="memory-view")
                        with TabPane("Stack", id="tab-stack"):
                            with VerticalScroll():
                                yield Static(id="stack-view")
                with Vertical(id="output-pane"):
                    yield RichLog(
                        id="output-view",
                        wrap=True,
                        highlight=False,
                        markup=True,
                        max_lines=500,
                    )
                    yield Input(
                        placeholder="Command: help, step, run, bp, mem, mset, disk, reset ...",
                        id="cmd-input",
                    )

            # Right column: Editor (full height)
            with Vertical(id="editor-pane"):
                yield TextArea("", language=None, show_line_numbers=True, id="editor")

        # Bottom bar: Flags+CPU | Registers
        with Horizontal(id="bottom-bar"):
            yield Static("", id="bottom-spacer")
            with Vertical(id="flags-pane"):
                yield Static(id="flags-content")
                yield Static(id="cpu-content")
            with Vertical(id="regs-pane"):
                yield Static(id="regs-content")

    # ------------------------------------------------------------------
    # Alustus
    # ------------------------------------------------------------------

    def on_mount(self) -> None:
        """Alusta sovellus kun DOM on valmis (Textual lifecycle).

        Suoritetaan kerran kun kaikki widgetit ovat luotu ja kiinnitetty
        DOM-puuhun. Tässä:
        1. Asetetaan paneelien otsikot (border_title)
        2. Resetoidaan kone (cold_reset) ja otetaan rekisterisnapshot
        3. Asetetaan oletuskoodi editoriin (esimerkki-kommentit)
        4. Kirjoitetaan tervetuloa-viestit lokiin
        5. Päivitetään kaikki näkymät (_refresh_all)
        6. Käynnistetään Screen-tabin 0.5s päivitystimer
        """
        self.query_one("#editor-pane").border_title = "Editor"
        self.query_one("#regs-pane").border_title = "Registers"
        self.query_one("#flags-pane").border_title = "Flags"
        self.query_one("#screen-section").border_title = "Screen"
        self.query_one("#output-pane").border_title = "Output"

        self.machine.cold_reset()
        self.dbg.snapshot_registers(self.machine.dump_registers())

        self.query_one("#editor", TextArea).text = (
            "; kCPU16 Assembly\n"
            "; Ctrl+O = Open | Ctrl+B = Assemble | F7 = Step | F5 = Run\n"
            ";\n"
            "; Example:\n"
            ";   LOAD R0, #42\n"
            ";   LOAD R1, #8\n"
            ";   ADD  R0, R1\n"
            ";   HALT\n"
        )

        self._log("[bold]kCPU16 Debugger[/bold] ready.")
        self._log(
            "[dim]F7/F10=Step  F5=Run  F2=Breakpoint  "
            "Ctrl+B=Assemble  Ctrl+O=Open[/dim]"
        )
        self._log("[dim]Type 'help' for command list.[/dim]")

        # Lataa käynnistysparametreilla annetut tiedostot
        startup_asm: Path | None = getattr(self, "startup_asm", None)
        startup_dsk: Path | None = getattr(self, "startup_dsk", None)

        if startup_dsk is not None:
            try:
                self.machine.storage.load_from_file(startup_dsk)
                self._log(f"[green]Storage loaded from {startup_dsk}[/green]")
            except Exception as e:
                self._log(f"[red]Storage load error: {e}[/red]")

        if startup_asm is not None:
            self._do_open(startup_asm)

        self._refresh_all()
        self.set_interval(1.0, self._refresh_screen_tab)
        self.query_one("#cmd-input", Input).focus()

    # ------------------------------------------------------------------
    # Painikkeet
    # ------------------------------------------------------------------

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Käsittele toolbar-painikkeiden klikkaukset.

        Yhdistää painikkeen id:n (esim. "btn-step") vastaavaan
        action-metodiin dict-lookupin kautta. Tämä välttää pitkän
        if/elif-ketjun ja tekee uusien painikkeiden lisäämisestä helppoa.
        """
        actions = {
            "btn-open": self.action_open_file,
            "btn-save": self.action_save_file,
            "btn-new": self._do_new,
            "btn-asm": self.action_assemble_code,
            "btn-step": self.action_step_once,
            "btn-run": self.action_run_program,
            "btn-reset": self.action_reset_machine,
            "btn-bp": self.action_toggle_breakpoint,
            "btn-clear": self.action_clear_screen,
            "btn-help": self.action_show_help,
        }
        action = actions.get(event.button.id)
        if action:
            action()

    # ------------------------------------------------------------------
    # Komentosyöte
    # ------------------------------------------------------------------

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Käsittele komentosyöte (Enter-painallus #cmd-input -kentässä).

        Lukee komennon, tyhjentää kentän, näyttää komennon output-paneelissa,
        suorittaa sen _execute_command():lla ja näyttää tuloksen.
        """
        cmd = event.value.strip()
        event.input.value = ""
        if not cmd:
            return

        self._log(f"[dim]> {cmd}[/dim]")
        result = self._execute_command(cmd)

        if result.ok:
            if result.message:
                self._log(result.message)
        else:
            self._log(f"[red]{result.message}[/red]")

        # VAIN step/run komennot päivittävät näkymän
        cmd_verb = cmd.split()[0].lower()
        if cmd_verb in {"step", "run", "restart", "asm", "reset"}:
            self._refresh_all()

    # ------------------------------------------------------------------
    # Actions (näppäinsidonnaisuudet)
    # ------------------------------------------------------------------

    def action_step_once(self) -> None:
        """Suorita yksi konekielikäsky (F7/F10 tai Step-painike).

        Tarkistaa ensin onko CPU pysähtynyt (HALT/EXIT). Jos ei,
        suorittaa yhden käskyn, siirtää editorikursorin vastaavalle
        riville, logittaa käskyn tiedot ja päivittää näkymät.
        """
        if self.machine.cpu.halted or self.machine.process_exited:
            self._log("[yellow]CPU stopped. Reset to continue.[/yellow]")
            self._refresh_all()
            return
        self.machine.step()
        self._update_exec_line()
        self._log_step_info()
        self._refresh_all()

    def action_run_program(self) -> None:
        """Suorita ohjelma breakpointiin tai max 10000 sykliin asti (F5).

        Käyttää _run_with_breakpoints()-metodia, joka steppaa yksi käsky
        kerrallaan ja tarkistaa breakpointit jokaisen jälkeen. Logittaa
        tuloksen ja päivittää näkymät.
        """
        result = self._run_with_breakpoints(DEFAULT_RUN_CYCLES)
        self._log(result)
        self._update_exec_line()
        self._refresh_all()

    def action_reset_machine(self) -> None:
        """Resetoi kone alkutilaan (Ctrl+R tai Reset-painike).

        Cold reset nollaa CPU:n, muistin ja laitteet. Asettaa
        is_assembled=False ja tyhjentää addr_to_line-mapin. Ottaa
        uuden rekisterisnapshot vertailua varten.
        """
        self.machine.cold_reset()
        self.is_assembled = False
        self.addr_to_line = {}
        self.dbg.snapshot_registers(self.machine.dump_registers())
        self._log("[green]Machine reset.[/green]")
        self._refresh_all()

    def action_toggle_breakpoint(self) -> None:
        """Aseta tai poista breakpoint nykyiseen PC-osoitteeseen (F2).

        Kutsuu dbg.toggle_breakpoint() joka palauttaa True jos lisättiin,
        False jos poistettiin. Logittaa tuloksen ja päivittää näkymät
        (disassembly näyttää ● breakpointatuille riveille).
        """
        addr = self.machine.regs.pc
        added = self.dbg.toggle_breakpoint(addr)
        if added:
            self._log(f"[red]Breakpoint SET at 0x{addr:04X}[/red]")
        else:
            self._log(f"Breakpoint REMOVED at 0x{addr:04X}")
        self._refresh_all()

    def action_open_file(self) -> None:
        """Avaa assembly-tiedosto editoriin (Ctrl+O).

        Jos komentosyötteessä ei ole polkua, asettaa fokuksen syötekenttään
        ja kirjoittaa "open " alkuun. Käyttäjä kirjoittaa polun ja painaa
        Enter, jolloin on_input_submitted → _execute_command käsittelee sen.
        """
        cmd_input = self.query_one("#cmd-input", Input)
        path_str = cmd_input.value.strip()
        if not path_str or path_str.startswith("open "):
            cmd_input.focus()
            cmd_input.value = "open "
            self._log("Type filename after 'open' and press Enter.")
            return
        path = Path(path_str)
        if not path.is_absolute():
            path = self.code_dir / path
        self._do_open(path)

    def action_save_file(self) -> None:
        """Tallenna editorin sisältö tiedostoon (Ctrl+S).

        Jos tiedosto on jo avattu (current_file), tallennetaan suoraan.
        Muuten ohjataan käyttäjä kirjoittamaan polku komentosyötteeseen.
        """
        if self.current_file:
            self._do_save(self.current_file)
        else:
            cmd_input = self.query_one("#cmd-input", Input)
            cmd_input.focus()
            cmd_input.value = "save "
            self._log("Type filename after 'save' and press Enter.")

    def action_assemble_code(self) -> None:
        """Assembloi editorin koodi ja lataa se muistiin (Ctrl+B).

        Delegoi _do_assemble()-metodille. Tämä on vain action-wrapperi
        joka mahdollistaa kutsumisen sekä näppäimellä että painikkeella.
        """
        self._do_assemble()

    def action_clear_screen(self) -> None:
        """Tyhjennä VRAM-näyttömuisti (F9).

        Nollaa kaikki VRAM-osoitteet (0xF800-0xFF7F). Hyödyllistä
        kun haluaa aloittaa piirron puhtaalta ruudulta ilman resettiä.
        """
        self.machine.clear_screen_memory()
        self._log("VRAM cleared.")
        self._refresh_all()

    def action_show_help(self) -> None:
        """Näytä ohje-teksti lokissa (F1).

        Tulostaa loki-widgettiin listan kaikista näppäinsidonnaisuuksista
        ja komennoista Rich-muotoiltuna.
        """
        self._log("")
        self._log("[bold]--- kCPU16 Debugger Help ---[/bold]")
        self._log("")
        self._log("[bold]Keyboard shortcuts:[/bold]")
        self._log("  Ctrl+O  Open file       Ctrl+S  Save file")
        self._log("  Ctrl+B  Assemble code   F2      Toggle breakpoint")
        self._log("  F7/F10  Step 1 instr    F5      Run (stops at BP)")
        self._log("  Ctrl+R  Reset machine   F9      Clear VRAM")
        self._log("  Ctrl+Q  Quit            F1      This help")
        self._log("")
        self._log("[bold cyan]File & Assembly:[/bold cyan]")
        self._log("  open <filename>              Load .asm from code/ directory")
        self._log("  save [filename]              Save editor to code/ directory")
        self._log("  asm                          Assemble, reset and load into memory")
        self._log("  check                        Syntax check only (no load)")
        self._log("[bold cyan]CPU Control:[/bold cyan]")
        self._log("  step [n]                     Step n instructions (default 1)")
        self._log("  run  [n]                     Run to BP/halt (max n cycles)")
        self._log("  stop                         Halt CPU immediately")
        self._log("  restart                      Reassemble and restart from 0x0100")
        self._log("[bold cyan]Breakpoints:[/bold cyan]")
        self._log("  bp <addr>                    Toggle breakpoint at address")
        self._log("  bp list                      List all breakpoints")
        self._log("  bp clear                     Remove all breakpoints")
        self._log("[bold cyan]Memory:[/bold cyan]")
        self._log("  mem <addr> [count]           Show count words at addr (default 1)")
        self._log("  mset <addr> <value>          Write value to addr")
        self._log("  mfill <addr> <count> <value> Fill count words starting at addr")
        self._log("[bold cyan]Disk (Storage):[/bold cyan]")
        self._log("  disk <block>                 Show block as hex dump")
        self._log("  disk load <path>             Load .dsk file into storage")
        self._log("  disk save <path>             Save storage to .dsk file")
        self._log("  dset <block> <offset> <value>  Write value at block + offset")
        self._log("  dfill <block> <value>        Fill entire block with value")
        self._log("[bold cyan]Reset:[/bold cyan]")
        self._log("  reset                        Memory + CPU (storage intact)")
        self._log("  reset deep                   Memory + CPU + storage")
        self._log("  reset cpu                    CPU only (memory intact)")
        self._log("[bold cyan]Other:[/bold cyan]")
        self._log("  cls                          Clear VRAM")
        self._log("  spec                         Show architecture spec")
        self._log("  help                         This help")
        self._log("")
        self._log("[bold cyan]Parameter syntax:[/bold cyan]")
        self._log("  <addr>    Memory address         0–0xFFFF (e.g. 256 or 0x0100)")
        self._log("  <value>   16-bit word            0–0xFFFF (e.g. 42 or 0x002A)")
        self._log("  <count>   Number of items        (e.g. 16 or 0x10)")
        self._log("  <block>   Storage block index    (e.g. 0, 1, 2 ...)")
        self._log("  <offset>  Word offset in block   (e.g. 0, 1, 2 ...)")
        self._log("  <path>    File path               (e.g. disk.dsk)")
        self._log("  <filename> .asm file in code/     (e.g. hello.asm)")
        self._log("  [param]   Optional parameter     (can be omitted)")
        self._log("")
        self._log("[bold cyan]Number formats:[/bold cyan]")
        self._log("  Decimal:  42, 256, 65535")
        self._log("  Hex:      0x2A, 0x0100, 0xFFFF")
        self._log("  Binary:   0b101010")
        self._log("  Octal:    0o52")
        self._log("---")

    # ------------------------------------------------------------------
    # Perusoperaatiot
    # ------------------------------------------------------------------

    def _do_new(self) -> None:
        """Luo uusi tyhjä dokumentti editoriin.

        Tyhjentää editorin, nollaa tiedostopolun ja assembly-tilan.
        Ei resetoi konetta - kone jää edelliseen tilaan.
        """
        self.query_one("#editor", TextArea).text = ""
        self.current_file = None
        self.is_assembled = False
        self.addr_to_line = {}
        self._log("New document.")

    def _do_open(self, path: Path) -> None:
        """Avaa tiedosto ja lataa sen sisältö editoriin.

        Lukee tiedoston UTF-8-enkoodauksella. Onnistuessa asettaa
        current_file = path ja is_assembled = False (koodi pitää
        assembloida uudelleen). Virhetilanteessa logittaa virheen.
        """
        try:
            content = path.read_text(encoding="utf-8")
            self.query_one("#editor", TextArea).text = content
            self.current_file = path
            self.is_assembled = False
            self._log(f"Opened: [bold]{path.name}[/bold] ({len(content)} chars)")
        except Exception as e:
            self._log(f"[red]Error: {e}[/red]")

    def _do_save(self, path: Path) -> None:
        """Tallenna editorin sisältö tiedostoon.

        Kirjoittaa editorin tekstin UTF-8-tiedostoksi. Asettaa
        current_file = path, jotta seuraava Ctrl+S tallentaa samaan
        paikkaan. Virhetilanteessa logittaa virheen.
        """
        try:
            content = self.query_one("#editor", TextArea).text
            path.write_text(content, encoding="utf-8")
            self.current_file = path
            self._log(f"Saved: [bold]{path.name}[/bold]")
        except Exception as e:
            self._log(f"[red]Error: {e}[/red]")

    def _do_assemble(self) -> None:
        """Assembloi editorin koodi ja lataa se koneen muistiin.

        Tämä on TUI:n keskeinen operaatio - "editori → konekieli → muisti":

        1. Lue editorin teksti (source)
        2. assembler.assemble(source) → lista 16-bittisiä sanoja
        3. machine.cold_reset() → nollaa CPU, muisti, laitteet
        4. machine.load_program(words) → lataa sanat osoitteesta 0x0100
        5. _build_addr_to_line() → rakenna osoite→rivi -mappi
        6. dbg.snapshot_registers() → ota vertailupiste rekistereille
        7. _update_exec_line() → siirrä kursori PC:n riville
        8. _refresh_all() → päivitä kaikki näkymät

        Virhetilanteessa (syntaksivirhe, tuntematon käsky) assembly
        keskeytyy ja virhe näytetään lokissa punaisella.
        """
        source = self.query_one("#editor", TextArea).text
        if not source.strip():
            self._log("[yellow]Editor is empty.[/yellow]")
            return
        try:
            words = self.assembler.assemble(source)
            self.machine.cold_reset()
            self.machine.load_program(words)
            self.is_assembled = True
            self.addr_to_line = _build_addr_to_line(source, self.assembler)
            self.dbg.snapshot_registers(self.machine.dump_registers())
            self._log(
                f"[green]Assembled: {len(words)} words at "
                f"0x{self.machine.regs.pc:04X}. F7=Step, F5=Run.[/green]"
            )
            self._update_exec_line()
            self._refresh_all()
        except Exception as e:
            self._log(f"[red]Assembly error: {e}[/red]")
            self.is_assembled = False

    # ------------------------------------------------------------------
    # Breakpoint-tietoinen suoritus
    # ------------------------------------------------------------------

    def _run_with_breakpoints(self, max_cycles: int) -> str:
        """Suorita ohjelmaa kunnes breakpoint, HALT, EXIT tai sykliraja.

        Ero machine.run()-metodiin: tämä steppaa yhden käskyn kerrallaan
        ja tarkistaa breakpointit JOKAISEN käskyn jälkeen. machine.run()
        ajaisi kaikki kerralla ilman breakpoint-tukea.

        Suoritussilmukka:
            1. machine.step() - suorita yksi käsky
            2. Tarkista: halted? → palauta "HALTED"
            3. Tarkista: process_exit? → palauta "EXITED"
            4. Tarkista: onko uusi PC breakpointattu? → palauta "Breakpoint at..."
            5. Toista kunnes max_cycles saavutettu

        Parametrit:
            max_cycles: Suurin sallittu syklimäärä (oletus 10000 F5:lle).

        Palauttaa:
            Rich-muotoiltu merkkijono joka kertoo pysähtymisen syyn.
        """
        cpu = self.machine.cpu
        if cpu.halted or cpu.process_exit_requested:
            return "[yellow]CPU stopped. Reset to continue.[/yellow]"

        cycles = 0
        while cycles < max_cycles:
            self.machine.step()
            cycles += 1
            if cpu.halted:
                return f"[red]HALTED after {cycles} cycles.[/red]"
            if cpu.process_exit_requested:
                return f"[yellow]EXIT after {cycles} cycles.[/yellow]"
            if self.dbg.has_breakpoint(self.machine.regs.pc):
                return (
                    f"[red]Breakpoint at 0x{self.machine.regs.pc:04X} "
                    f"after {cycles} cycles.[/red]"
                )
        return f"Ran {cycles} cycles. PC=0x{self.machine.regs.pc:04X}"

    # ------------------------------------------------------------------
    # Näkymien päivitys
    # ------------------------------------------------------------------

    def _refresh_all(self) -> None:
        """Päivitä kaikki näkymäpaneelit kerralla (paitsi Screen).

        Kutsutaan jokaisen tilan muutoksen jälkeen (step, run, reset,
        assemble, komentosyöte). Screen-näyttö päivittyy omalla 1s timerilla
        eikä tässä, jotta komentojen suoritus pysyy ketteränä.
        """
        self._refresh_disassembly()
        self._refresh_registers()
        self._refresh_flags()
        self._refresh_cpu_status()
        # self._refresh_screen_tab()  # Käytetään vain 1s timeria
        self._refresh_memory()
        self._refresh_stack()

    def _refresh_disassembly(self) -> None:
        """Päivitä disassembly-paneeli PC:n ympäriltä.

        Näyttöikkuna (scan window):
            - Skannaa taaksepäin PC:stä max 15 osoitetta löytääkseen
              aiempia käskyjä. Ohittaa tyhjät muistipaikat (0x0000),
              mutta pysähtyy kun löytää aukon → ei näytä turhaa dataa.
            - Clamp: näytä enintään 10 sanaa ennen PC:tä.
            - Eteenpäin: näytä max 80 sanaa PC:n jälkeen.

        Breakpointit:
            - Breakpointatut osoitteet sisällytetään aina, vaikka ne
              olisivat scan-ikkunan ulkopuolella (lähellä).
            - Breakpointattu rivi saa ● (punainen pallo) -merkin.

        Suodatus:
            - ".word 0x0000" -rivit piilotetaan (tyhjä muisti) PAITSI:
              * Rivi on PC:n kohdalla tai max 3 osoitteen päässä
              * Rivillä on breakpoint

        Muotoilu:
            - ▶ = nykyinen PC (korostettu tausta)
            - ● = breakpoint (punainen pallo)
            - Osoite syaanilla, mnemoniikki keltaisella
            - Rekisterit sinisellä, välittömät arvot vihreällä
        """
        pc = self.machine.regs.pc

        # Scan backward from PC to find a good start point.
        # Skip over empty memory (0x0000) to avoid showing noise.
        # Show up to 5 instructions before PC if they contain real code.
        scan_start = max(0, pc - 15)
        start = pc  # default: start at PC
        for a in range(pc - 1, scan_start - 1, -1):
            if self.machine.memory.read(a) != 0 or self.dbg.has_breakpoint(a):
                start = a
            else:
                break
        # Also include any breakpoints slightly beyond the backward scan
        if self.dbg.breakpoints:
            for bp_addr in self.dbg.breakpoints:
                if scan_start <= bp_addr < start:
                    start = bp_addr
        # Clamp: show at most 10 words before PC
        start = max(start, pc - 10)

        end = min(WORD_MASK, pc + 80)
        words = [self.machine.memory.read(a) for a in range(start, end + 1)]
        raw = self.disassembler.disassemble(words, start_addr=start)

        lines: list[str] = []
        for raw_line in raw.split("\n"):
            if not raw_line.strip():
                continue
            addr_part = raw_line.split(":")[0].strip()
            try:
                addr = int(addr_part, 16)
            except ValueError:
                lines.append(raw_line)
                continue

            # Skip .word 0x0000 lines (empty memory) unless near PC or has breakpoint
            if (
                ".word 0x0000" in raw_line
                and addr != pc
                and abs(addr - pc) > 3
                and not self.dbg.has_breakpoint(addr)
            ):
                continue

            bp = "[bold red]\u25cf[/] " if self.dbg.has_breakpoint(addr) else "  "
            display = self._fmt_disasm_line(raw_line)

            if addr == pc:
                lines.append(f"{bp}[bold white on #3a3a3a]\u25b6 {display}[/]")
            else:
                lines.append(f"{bp}  {display}")

        self.query_one("#disasm-content", Static).update("\n".join(lines))

    def _fmt_disasm_line(self, line: str) -> str:
        """Muotoile disassembly-rivi värikoodein."""
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
        return f"[cyan]{addr}[/]: [yellow]{mnemonic:<10}[/] {fmt_ops}"

    def _fmt_operands(self, mnemonic: str, ops_str: str) -> str:
        """Muunna operandit luettavaan muotoon (rekisterinimet, värit).

        Disassembler palauttaa operandit numeerisina (esim. "0, 42").
        Tämä metodi muuntaa ne ihmisluettaviksi käyttäen REG_NAMES-lookuppia:
        - _REG_FIRST kertoo, odottaako 1. operandi rekisteri-indeksiä
        - _REG_SECOND kertoo, odottaako 2. operandi rekisteri-indeksiä
        - Jos kyseessä on rekisteri, haetaan nimi REG_NAMES-dictistä (0→R0, jne.)
          ja värjätään siniseksi
        - Muut arvot (välittömät, osoitteet) näytetään vihreällä hex-muodossa
        """
        if not ops_str:
            return ""
        ops = [o.strip() for o in ops_str.split(",")]
        result = []
        for i, op in enumerate(ops):
            if not op:
                continue
            try:
                val = int(op, 16) if op.startswith("0x") else int(op)
            except ValueError:
                result.append(op)
                continue
            if (i == 0 and mnemonic in _REG_FIRST) or (
                i == 1 and mnemonic in _REG_SECOND
            ):
                name = REG_NAMES.get(val, f"?{val}")
                result.append(f"[blue]{name}[/]")
            else:
                result.append(f"[green]0x{val:04X}[/]")
        return ", ".join(result)

    def _refresh_registers(self) -> None:
        """Päivitä rekisteripaneeli.

        Näyttää kaikki rekisterit (R0-R3, FP, SP, PC, SR) sekä hex- että
        desimaaliarvoina. Käyttää dbg.snapshot_registers()-metodia vertaamaan
        edelliseen tilaan - muuttuneet rekisterit korostetaan punaisella
        boldilla, muuttumattomat näytetään syaanilla.
        """
        regs = self.machine.dump_registers()
        changed = self.dbg.snapshot_registers(regs)
        lines: list[str] = []
        for name, value in regs.items():
            h = f"0x{value:04X}"
            d = f"{value:>5}"
            if changed.get(name, False):
                lines.append(f"[bold red]{name:>3}  {h}  {d}[/]")
            else:
                lines.append(f"[cyan]{name:>3}[/]  {h}  {d}")
        self.query_one("#regs-content", Static).update("\n".join(lines))

    def _refresh_flags(self) -> None:
        """Päivitä lippupaneeli (SR-rekisterin yksittäiset bitit).

        Näyttää jokaisen lipun erikseen:
        - Z (Zero), N (Negative), C (Carry), V (Overflow), I (Interrupt),
          P (Privilege)
        - Asetettu lippu (1): vihreä bold
        - Nollattu lippu (0): himmennetty (dim)
        - Moodi: KERNEL (vihreä) tai USER (keltainen), riippuen
          privilege-bitistä (SR_FLAG_P / in_kernel_mode)
        """
        r = self.machine.regs
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
        self.query_one("#flags-content", Static).update(
            f"{' '.join(parts)}\nMode: {mode}"
        )

    def _refresh_cpu_status(self) -> None:
        """Päivitä CPU-tilapaneeli.

        Näyttää:
        - Tila: READY (vihreä), HALTED (punainen) tai EXITED (keltainen)
        - Syklit: CPU:n suorittamien käskyjen kokonaismäärä
        - Breakpoint-lista: kaikki asetetut breakpointit (jos on)
        """
        cpu = self.machine.cpu
        if cpu.halted:
            state = "[bold red]HALTED[/]"
        elif cpu.process_exit_requested:
            state = "[bold yellow]EXITED[/]"
        else:
            state = "[bold green]READY[/]"

        lines = [f"State: {state}", f"Cycles: {cpu.instruction_counter}"]
        if self.dbg.breakpoints:
            bp_list = ", ".join(f"0x{a:04X}" for a in sorted(self.dbg.breakpoints))
            lines.append(f"[dim]BP: {bp_list}[/dim]")
        self.query_one("#cpu-content", Static).update("\n".join(lines))

    def _refresh_screen_tab(self) -> None:
        """Päivitä Screen-näytön VRAM-renderöinti (1s timer).

        Käyttää cachea: Static.update() kutsutaan vain kun VRAM-sisältö
        on oikeasti muuttunut edellisestä kerrasta.
        """
        try:
            rendered = self.machine.screen.render_with_rich_colors(self.machine.memory)
            if rendered != self._last_screen_render:
                self._last_screen_render = rendered
                self.query_one("#screen-view-solo", Static).update(rendered)
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
        self.query_one("#memory-view", Static).update("\n".join(lines))

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
        self.query_one("#stack-view", Static).update("\n".join(lines))

    # ------------------------------------------------------------------
    # PC -> editoririvi -korostus
    # ------------------------------------------------------------------

    def _update_exec_line(self) -> None:
        """Siirrä editorin kursori nykyistä PC:tä vastaavalle riville.

        Käyttää addr_to_line-mappia (_build_addr_to_line) löytääkseen
        mikä lähdekoodirivi vastaa nykyistä PC-osoitetta. Jos löytyy,
        siirtää TextArea:n kursorin kyseiselle riville. Tämä mahdollistaa
        "source-level debugging" -kokemuksen: käyttäjä näkee editorissa
        missä kohdassa lähdekoodia suoritus on.

        Ei tee mitään jos addr_to_line on tyhjä (koodi ei assembloitu)
        tai PC:tä ei löydy mapista (esim. kernel-koodi).
        """
        if not self.addr_to_line:
            return
        pc = self.machine.regs.pc
        line_no = self.addr_to_line.get(pc)
        if line_no is not None:
            try:
                editor = self.query_one("#editor", TextArea)
                target = max(0, line_no - 1)
                if target < len(editor.text.splitlines()):
                    editor.move_cursor((target, 0))
            except Exception:
                pass

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
            mnemonic, op_count, _ = OPCODE_TABLE[opcode]
            ops = [
                f"0x{self.machine.memory.read(pc + 1 + i):04X}" for i in range(op_count)
            ]
            instr = f"{mnemonic} {', '.join(ops)}" if ops else mnemonic
        else:
            instr = f".word 0x{opcode:04X}"

        line_info = ""
        line_no = self.addr_to_line.get(pc)
        if line_no:
            line_info = f" [dim](line {line_no})[/dim]"
        self._log(
            f"[dim]IC={ic}[/dim] PC=0x{pc:04X}: " f"[bold]{instr}[/bold]{line_info}"
        )
        if self.machine.cpu.halted:
            self._log("[green]CPU halted (HALT).[/green]")
        elif self.machine.process_exited:
            self._log("[green]Process exited (EXIT).[/green]")

    # ------------------------------------------------------------------
    # Komentotulkki
    # ------------------------------------------------------------------

    def _execute_command(self, command: str) -> CommandResult:
        """Komentotulkki: parsii ja suorittaa komentosyötteen.

        Komennot:
            --- Tiedostot & assembly ---
            open <path>                  -- Avaa .asm tiedosto editoriin
            save [path]                  -- Tallenna editori tiedostoon
            asm                          -- Käännä, reset, lataa muistiin
            check                        -- Tarkista syntaksi
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
            disk load|save <path>        -- Lataa/tallenna .dsk
            dset <block> <offset> <val>  -- Muokkaa tavu blokissa
            dfill <block> <value>        -- Täytä blokki
            --- Reset ---
            reset                        -- Muisti + CPU (storage säilyy)
            reset deep                   -- Muisti + CPU + storage
            reset cpu                    -- Vain CPU (muisti säilyy)
            --- Muut ---
            cls                          -- Nollaa VRAM
            help                         -- Näytä ohje
            spec                         -- Arkkitehtuuriraportti
        """
        parts = command.split()
        op = parts[0].lower()
        args = parts[1:]

        try:
            # --- Tiedostot & assembly ---
            if op == "open":
                if not args:
                    return CommandResult(False, "Usage: open <filename>")
                path = Path(" ".join(args))
                if not path.is_absolute():
                    path = self.code_dir / path
                self._do_open(path)
                return CommandResult(True, "")

            if op == "save":
                if not args:
                    if self.current_file:
                        self._do_save(self.current_file)
                        return CommandResult(True, "")
                    return CommandResult(False, "Usage: save <filename>")
                path = Path(" ".join(args))
                if not path.is_absolute():
                    path = self.code_dir / path
                self._do_save(path)
                return CommandResult(True, "")

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
                    self.machine.step()
                self._update_exec_line()
                ic = self.machine.cpu.instruction_counter
                return CommandResult(True, f"Stepped {max(1, count)}. IC={ic}")

            if op == "run":
                cycles = int(args[0], 0) if args else DEFAULT_RUN_CYCLES
                result = self._run_with_breakpoints(max(1, cycles))
                self._update_exec_line()
                return CommandResult(True, result)

            if op == "stop":
                self.machine.cpu.halted = True
                return CommandResult(True, "[red]CPU halted.[/red]")

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

            # --- Reset ---
            if op == "reset":
                return self._handle_reset_command(args)

            # --- Näyttö & muut ---
            if op == "cls":
                self.machine.clear_screen_memory()
                return CommandResult(True, "[green]VRAM cleared.[/green]")

            if op == "help":
                self.action_show_help()
                return CommandResult(True, "")

            if op == "spec":
                return CommandResult(True, format_arch_spec_report())

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
            return CommandResult(True, f"[red]Breakpoint SET at 0x{addr:04X}[/red]")
        return CommandResult(True, f"Breakpoint REMOVED at 0x{addr:04X}")

    # ------------------------------------------------------------------
    # Uudet komentokäsittelijät
    # ------------------------------------------------------------------

    def _do_syntax_check(self) -> CommandResult:
        """Tarkista editorin assembly-koodin syntaksi ilman latausta muistiin."""
        source = self.query_one("#editor", TextArea).text.strip()
        if not source:
            return CommandResult(False, "[yellow]Editor is empty.[/yellow]")
        try:
            words = self.assembler.assemble(source)
            return CommandResult(
                True,
                f"[green]Syntax OK — {len(words)} words.[/green]",
            )
        except Exception as e:
            return CommandResult(False, f"[red]Syntax error: {e}[/red]")

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
                False, "Usage: disk <block> | disk load <file> | disk save <file>"
            )
        sub = args[0].lower()
        if sub == "load":
            if len(args) < 2:
                return CommandResult(False, "Usage: disk load <filename.dsk>")
            path = Path(" ".join(args[1:]))
            self.machine.storage.load_from_file(path)
            return CommandResult(True, f"[green]Disk loaded from {path}[/green]")
        if sub == "save":
            if len(args) < 2:
                return CommandResult(False, "Usage: disk save <filename.dsk>")
            path = Path(" ".join(args[1:]))
            self.machine.storage.save_to_file(path)
            return CommandResult(True, f"[green]Disk saved to {path}[/green]")
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
        return CommandResult(
            True,
            f"[green]Block {block_idx} filled with 0x{value:04X}[/green]",
        )

    def _handle_reset_command(self, args: list[str]) -> CommandResult:
        """Resetoi: reset | reset deep | reset cpu."""
        if not args:
            # Normaali reset: VRAM + muisti + CPU. Storage säilyy.
            self.machine.cold_reset()
            self.is_assembled = False
            self.addr_to_line = {}
            self.dbg.snapshot_registers(self.machine.dump_registers())
            return CommandResult(
                True, "[green]Reset (memory + CPU). Storage intact.[/green]"
            )
        sub = args[0].lower()
        if sub == "deep":
            self.machine.cold_reset()
            self.machine.storage.reset()
            self.is_assembled = False
            self.addr_to_line = {}
            self.dbg.snapshot_registers(self.machine.dump_registers())
            return CommandResult(
                True, "[green]Deep reset (memory + CPU + storage).[/green]"
            )
        if sub == "cpu":
            self.machine.cpu.reset()
            self.dbg.snapshot_registers(self.machine.dump_registers())
            return CommandResult(True, "[green]CPU reset. Memory preserved.[/green]")
        return CommandResult(False, "Usage: reset | reset deep | reset cpu")

    # ------------------------------------------------------------------
    # Apumetodit
    # ------------------------------------------------------------------

    def _log(self, message: str) -> None:
        """Kirjoita viesti output-paneelin RichLog-widgettiin.

        Kaikki tulosteet (loki, komentotulosteet, virheet) ohjautuvat
        yhteen yhtenäiseen output-ikkunaan.
        Tukee Rich-markupia (esim. [bold], [red], [dim]).
        """
        try:
            self.query_one("#output-view", RichLog).write(message)
        except Exception:
            pass


def run_tui(
    startup_asm: Path | None = None,
    startup_dsk: Path | None = None,
) -> int:
    """Käynnistä kCPU16 TUI-sovellus.

    Entry point jota kutsutaan CLI:stä (esim. __main__.py tai console_scripts).
    Luo KCPU16TUI-instanssin ja käynnistää Textual-tapahtumasilmukan.
    Palaa vasta kun käyttäjä sulkee sovelluksen (Ctrl+Q).

    Args:
        startup_asm: .asm-tiedosto ladattavaksi editoriin käynnistyksessä.
        startup_dsk: .dsk-tiedosto ladattavaksi storageen käynnistyksessä.

    Palauttaa:
        int: Exit-koodi (0 = normaali lopetus).
    """
    app = KCPU16TUI()
    app.startup_asm = startup_asm
    app.startup_dsk = startup_dsk
    app.run()
    return 0
