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
  ├────────────────────┬─────────────────────┬─────────────────────────┤
  │ SOURCE EDITOR      │ DISASSEMBLY         │ REGISTERS               │
  │ (TextArea, muokk.) │ (Static, värikood.) │ (muuttuneet=punainen)   │
  │ rivinumerot        │ ●=breakpoint        │                         │
  │ kursori seuraa PC  │ ▶=nykyinen PC       ├─────────────────────────┤
  │ width: 2fr         │ width: 2fr          │ FLAGS  Z N C V I P      │
  │                    │                     │ (vihreä=1, dim=0)       │
  │                    │                     ├─────────────────────────┤
  │                    │                     │ CPU: READY/HALTED/EXIT  │
  │                    │                     │ Cycles: N  BP: lista    │
  ├────────────────────┴─────────────────────┴─────────────────────────┤
  │ [Log] [Screen] [Memory] [Stack]   (TabbedContent, height: 14)      │
  ├────────────────────────────────────────────────────────────────────┤
  │ > komentosyöte                                              Footer│
  └────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import (
    Button,
    Footer,
    Header,
    Input,
    RichLog,
    Static,
    TabbedContent,
    TabPane,
    TextArea,
)

from .assembler import Assembler, MNEMONIC_TO_OPCODE
from .constants import (
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
)
from .debugger import DebugState
from .disassembler import Disassembler
from .examples import get_source, list_examples
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
    "LOAD", "CPY", "READ", "STORE", "READ_IND", "STORE_IND",
    "ADD", "SUB", "MUL", "DIV", "CMP",
    "AND", "OR", "XOR", "NOT", "SHL", "SHR",
    "PUSH", "POP", "SMPR", "STMR", "DREAD", "DWRITE",
}
# Käskyt joissa myös 2. operandi on rekisteri-indeksi (esim. ADD R0, R1)
_REG_SECOND = {
    "CPY", "ADD", "SUB", "MUL", "DIV", "CMP",
    "AND", "OR", "XOR", "SHL", "SHR",
    "READ_IND", "STORE_IND", "DREAD", "DWRITE",
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
            source, 0x0100
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
        Header → Toolbar (Horizontal + Buttonit) → main-area (Horizontal):
            editor-pane (TextArea) | disasm-pane (Static) | right-sidebar:
                regs-pane | flags-pane | cpu-pane
        → bottom-tabs (TabbedContent): Log | Screen | Memory | Stack
        → cmd-input (Input) → Footer

    Päivityslogiikka:
        _refresh_all() kutsutaan jokaisen muutoksen jälkeen (step, run, reset,
        assemble). Se päivittää kaikki paneelit synkronisesti. Timer-pollausta
        ei käytetä, paitsi Screen-välilehti päivittyy 0.5s välein (VRAM voi
        muuttua IO-operaatioilla ilman explisiittistä refreshiä).
    """

    TITLE = "kCPU16 Debugger v1.0"
    SUB_TITLE = "16-bit CPU Emulator"

    # Textual CSS: Määrittelee koko sovelluksen visuaalisen layoutin.
    #
    # Rakenne ylhäältä alas:
    #   1. #toolbar          - Yläpalkki: painikkeet (dock: top, height: 3)
    #   2. #main-area        - Kolmen sarakkeen pääalue (height: 1fr, joustava):
    #      - #editor-pane    - Lähdekoodi-editori (width: 2fr, vasemmalla)
    #      - #disasm-pane    - Disassembly-näkymä (width: 2fr, keskellä)
    #      - #right-sidebar  - Oikea sivupalkki (width: 30, kiinteä):
    #          #regs-pane, #flags-pane, #cpu-pane päällekkäin
    #   3. #bottom-tabs      - Alatason välilehdet (dock: bottom, height: 14):
    #      Log, Screen, Memory, Stack
    #   4. #cmd-input        - Komentosyöte (dock: bottom, height: 3)
    #   5. Footer            - Textual Footer (näppäinsidonnaisuudet)
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
        border-bottom: solid $primary-darken-2;
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

    /* ---- Main 3-column area ---- */
    #main-area {
        height: 1fr;
        layout: horizontal;
    }

    /* Editor (left) */
    #editor-pane {
        width: 2fr;
        min-width: 30;
        border: solid $primary-darken-2;
        border-title-color: $accent;
    }
    #editor-pane TextArea {
        height: 1fr;
    }

    /* Disassembly (center) */
    #disasm-pane {
        width: 2fr;
        min-width: 24;
        border: solid $success-darken-1;
        border-title-color: $accent;
    }
    #disasm-content {
        padding: 0 1;
    }

    /* Right sidebar */
    #right-sidebar {
        width: 30;
        min-width: 26;
        max-width: 36;
    }
    #regs-pane {
        height: auto;
        max-height: 14;
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }
    #flags-pane {
        height: 5;
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }
    #cpu-pane {
        height: 1fr;
        min-height: 4;
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }

    /* ---- Bottom tabs ---- */
    #bottom-tabs {
        height: 14;
        dock: bottom;
        border-top: solid $primary-darken-2;
    }
    TabPane {
        padding: 0;
    }
    #log-view {
        height: 1fr;
    }
    #screen-view {
        height: 1fr;
        padding: 0 1;
    }
    #memory-view {
        height: 1fr;
        padding: 0 1;
    }
    #stack-view {
        height: 1fr;
        padding: 0 1;
    }

    /* Command input */
    #cmd-input {
        dock: bottom;
        height: 3;
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
        self.mem_view_addr: int = 0x0100
        self.addr_to_line: dict[int, int] = {}
        self.is_assembled: bool = False

    # ------------------------------------------------------------------
    # Layout
    # ------------------------------------------------------------------

    def compose(self) -> ComposeResult:
        """Rakenna sovelluksen widget-puu (Textual compose -pattern).

        Palauttaa kaikki widgetit yield-lauseilla. Textual kutsuu tätä
        kerran sovelluksen käynnistyessä.

        Widget-hierarkia:
            Header (kellonaika)
            Toolbar (#toolbar): Open, Save, New, Assemble, Step, Run, Reset,
                                BP, Clear, Help -painikkeet
            Main area (#main-area, Horizontal):
                #editor-pane: TextArea (language=None, ei tree-sitter ASM:lle)
                #disasm-pane: Static (päivitetään _refresh_disassembly():lla)
                #right-sidebar:
                    #regs-pane: Rekisterit (Static)
                    #flags-pane: Liput (Static)
                    #cpu-pane: CPU-tila (Static)
            Bottom tabs (#bottom-tabs, TabbedContent):
                Log (RichLog, max 500 riviä)
                Screen (Static, VRAM-renderöinti)
                Memory (Static, hex dump)
                Stack (Static, pinonäkymä)
            #cmd-input: Komentosyöte (Input)
            Footer: Näppäinsidonnaisuudet
        """
        yield Header(show_clock=True)

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

        # Main area: Editor | Disassembly | Right sidebar
        with Horizontal(id="main-area"):
            with Vertical(id="editor-pane"):
                yield TextArea(
                    "", language=None, show_line_numbers=True, id="editor"
                )

            with VerticalScroll(id="disasm-pane"):
                yield Static(id="disasm-content")

            with Vertical(id="right-sidebar"):
                with Vertical(id="regs-pane"):
                    yield Static(id="regs-content")
                with Vertical(id="flags-pane"):
                    yield Static(id="flags-content")
                with Vertical(id="cpu-pane"):
                    yield Static(id="cpu-content")

        # Bottom tabs
        with TabbedContent(id="bottom-tabs"):
            with TabPane("Log", id="tab-log"):
                yield RichLog(
                    id="log-view", wrap=True, highlight=False,
                    markup=True, max_lines=500,
                )
            with TabPane("Screen", id="tab-screen"):
                yield Static(id="screen-view")
            with TabPane("Memory", id="tab-memory"):
                yield Static(id="memory-view")
            with TabPane("Stack", id="tab-stack"):
                yield Static(id="stack-view")

        yield Input(
            placeholder="Komento: help, step, run, bp, mem, load, assemble ...",
            id="cmd-input",
        )
        yield Footer()

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
        self.query_one("#editor-pane").border_title = "Source Editor"
        self.query_one("#disasm-pane").border_title = "Disassembly"
        self.query_one("#regs-pane").border_title = "Registers"
        self.query_one("#flags-pane").border_title = "Flags"
        self.query_one("#cpu-pane").border_title = "CPU"

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

        self._refresh_all()
        self.set_interval(0.5, self._refresh_screen_tab)

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

        Lukee komennon, tyhjentää kentän, logittaa komennon, suorittaa
        sen _execute_command():lla ja näyttää tuloksen. Virheelliset
        komennot näytetään punaisella. Päivittää kaikki näkymät lopuksi.
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
        result = self._run_with_breakpoints(10000)
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
            self._log("Type file path after 'open' and press Enter.")
            return
        self._do_open(Path(path_str))

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
            self._log("Type file path after 'save' and press Enter.")

    def action_assemble_code(self) -> None:
        """Assembloi editorin koodi ja lataa se muistiin (Ctrl+B).

        Delegoi _do_assemble()-metodille. Tämä on vain action-wrapperi
        joka mahdollistaa kutsumisen sekä näppäimellä että painikkeella.
        """
        self._do_assemble()

    def action_clear_screen(self) -> None:
        """Tyhjennä VRAM-näyttömuisti (F9).

        Nollaa kaikki VRAM-osoitteet (0xF800-0xFFCF). Hyödyllistä
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
        self._log("[bold]Keyboard:[/bold]")
        self._log("  Ctrl+O  Open file       Ctrl+S  Save file")
        self._log("  Ctrl+B  Assemble code   F2      Toggle breakpoint")
        self._log("  F7/F10  Step 1 instr    F5      Run (stops at BP)")
        self._log("  Ctrl+R  Reset machine   F9      Clear VRAM")
        self._log("  Ctrl+Q  Quit            F1      This help")
        self._log("[bold]Commands:[/bold]")
        self._log("  step [n], run [n], reset, assemble")
        self._log("  bp <addr>, bp list, bp clear")
        self._log("  mem <addr>, open <path>, save <path>")
        self._log("  load <example>, examples, regs, status, spec, disasm")
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

    def _do_load_example(self, name: str) -> None:
        """Lataa esimerkkiohjelma editoriin ja assembloi se.

        Hakee esimerkin nimen perusteella examples-moduulista,
        asettaa sen editoriin ja kutsuu automaattisesti _do_assemble().
        Jos nimeä ei löydy, näyttää virheen ja kehottaa kokeilemaan
        'examples'-komentoa.
        """
        try:
            source = get_source(name)
            self.query_one("#editor", TextArea).text = source
            self.current_file = None
            self._log(f"Loaded example: [bold]{name}[/bold]")
            self._do_assemble()
        except KeyError:
            self._log(f"[red]Unknown example: {name}[/red]. Type 'examples'.")
        except Exception as e:
            self._log(f"[red]Error: {e}[/red]")

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
        """Päivitä kaikki näkymäpaneelit kerralla.

        Kutsutaan jokaisen tilan muutoksen jälkeen (step, run, reset,
        assemble, komentosyöte). Ei timer-pollausta - paitsi Screen-tab
        jolla on oma 0.5s intervalli (ks. on_mount).
        """
        self._refresh_disassembly()
        self._refresh_registers()
        self._refresh_flags()
        self._refresh_cpu_status()
        self._refresh_screen_tab()
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

        end = min(0xFFFF, pc + 80)
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
                lines.append(
                    f"{bp}[bold white on #3a3a3a]\u25b6 {display}[/]"
                )
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
        mode = (
            "[bold green]KERNEL[/]" if r.in_kernel_mode else "[yellow]USER[/]"
        )
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
            bp_list = ", ".join(
                f"0x{a:04X}" for a in sorted(self.dbg.breakpoints)
            )
            lines.append(f"[dim]BP: {bp_list}[/dim]")
        self.query_one("#cpu-content", Static).update("\n".join(lines))

    def _refresh_screen_tab(self) -> None:
        """Päivitä Screen-välilehden VRAM-renderöinti.

        Kutsuu screen.render_with_rich_colors() joka lukee VRAM-alueen
        (0xF800-0xFFCF, 80x25) ja tuottaa Rich-muotoillun tekstin
        väreillä (FG/BG). Kutsutaan sekä _refresh_all():sta että
        0.5s intervallitimerista (VRAM voi muuttua IO-operaatiolla
        ilman explisiittistä refreshiä, esim. DWRITE-käskyn aikana).
        """
        try:
            rendered = self.machine.screen.render_with_rich_colors(
                self.machine.memory
            )
            self.query_one("#screen-view", Static).update(rendered)
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
            if row_addr > 0xFFFF:
                break
            hex_parts = []
            ascii_parts = []
            for col in range(8):
                a = row_addr + col
                if a > 0xFFFF:
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
            addr = (sp + 1 + i) & 0xFFFF
            word = self.machine.memory.read(addr)
            marker = "[yellow]\u2192[/] " if i == 0 else "  "
            lines.append(
                f"{marker}[cyan]{addr:04X}[/]: 0x{word:04X}  ({word})"
            )
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
                f"0x{self.machine.memory.read(pc + 1 + i):04X}"
                for i in range(op_count)
            ]
            instr = f"{mnemonic} {', '.join(ops)}" if ops else mnemonic
        else:
            instr = f".word 0x{opcode:04X}"

        line_info = ""
        line_no = self.addr_to_line.get(pc)
        if line_no:
            line_info = f" [dim](line {line_no})[/dim]"
        self._log(
            f"[dim]IC={ic}[/dim] PC=0x{pc:04X}: "
            f"[bold]{instr}[/bold]{line_info}"
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

        Tukee seuraavat komennot:
            help              -- Näytä ohje
            step [n]          -- Steppaa n käskyä (oletus 1)
            run [n]           -- Aja n sykliä breakpointein (oletus 10000)
            reset             -- Cold reset
            bp <addr>         -- Toggle breakpoint osoitteeseen
            bp list           -- Listaa breakpointit
            bp clear          -- Poista kaikki breakpointit
            mem [addr]        -- Näytä/vaihda muistinäkymän osoite
            examples          -- Listaa saatavilla olevat esimerkit
            load <name>       -- Lataa esimerkki editoriin ja assembloi
            open <path>       -- Avaa tiedosto
            save <path>       -- Tallenna tiedosto
            assemble          -- Assembloi editorin koodi
            regs              -- Näytä rekisterit yhdellä rivillä
            status            -- Näytä CPU:n tila
            spec              -- Näytä arkkitehtuurin spesifikaatio
            disasm            -- Näytä disassembly lokissa
            screen            -- Päivitä Screen-näkymä

        Parametrit:
            command: Käyttäjän syöttämä komentorivi.

        Palauttaa:
            CommandResult(ok, message) - ok=False virhetilanteessa.
        """
        parts = command.split()
        op = parts[0].lower()
        args = parts[1:]

        try:
            if op == "help":
                self.action_show_help()
                return CommandResult(True, "")

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
                cycles = int(args[0], 0) if args else 10000
                result = self._run_with_breakpoints(max(1, cycles))
                self._update_exec_line()
                return CommandResult(True, result)

            if op == "reset":
                self.machine.cold_reset()
                self.is_assembled = False
                self.addr_to_line = {}
                self.dbg.snapshot_registers(self.machine.dump_registers())
                return CommandResult(True, "[green]Machine reset.[/green]")

            if op == "bp":
                return self._handle_bp_command(args)

            if op in ("mem", "memory"):
                if args:
                    self.mem_view_addr = int(args[0], 0)
                return CommandResult(
                    True, f"Memory view at 0x{self.mem_view_addr:04X}"
                )

            if op == "examples":
                lines = [
                    f"  [cyan]{n:<16}[/cyan] {d}" for n, d in list_examples()
                ]
                return CommandResult(True, "Examples:\n" + "\n".join(lines))

            if op == "load":
                if not args:
                    return CommandResult(False, "Usage: load <example-name>")
                self._do_load_example(args[0])
                return CommandResult(True, "")

            if op == "open":
                if not args:
                    return CommandResult(False, "Usage: open <path>")
                self._do_open(Path(" ".join(args)))
                return CommandResult(True, "")

            if op == "save":
                if not args:
                    return CommandResult(False, "Usage: save <path>")
                self._do_save(Path(" ".join(args)))
                return CommandResult(True, "")

            if op == "assemble":
                self._do_assemble()
                return CommandResult(True, "")

            if op == "regs":
                items = [
                    f"{n}=0x{v:04X}"
                    for n, v in self.machine.dump_registers().items()
                ]
                return CommandResult(True, " | ".join(items))

            if op == "status":
                return CommandResult(True, self._format_status())

            if op == "spec":
                return CommandResult(True, format_arch_spec_report())

            if op == "disasm":
                self._show_disasm_in_log()
                return CommandResult(True, "")

            if op == "screen":
                self._refresh_screen_tab()
                return CommandResult(True, "Screen refreshed.")

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
            return CommandResult(
                False, "Usage: bp <addr> | bp list | bp clear"
            )
        if args[0] == "list":
            if not self.dbg.breakpoints:
                return CommandResult(True, "No breakpoints.")
            bps = ", ".join(
                f"0x{a:04X}" for a in sorted(self.dbg.breakpoints)
            )
            return CommandResult(True, f"Breakpoints: {bps}")
        if args[0] == "clear":
            self.dbg.clear_breakpoints()
            return CommandResult(True, "All breakpoints cleared.")
        addr = int(args[0], 0)
        added = self.dbg.toggle_breakpoint(addr)
        if added:
            return CommandResult(
                True, f"[red]Breakpoint SET at 0x{addr:04X}[/red]"
            )
        return CommandResult(True, f"Breakpoint REMOVED at 0x{addr:04X}")

    def _format_status(self) -> str:
        """Muotoile CPU:n tilaraportti tekstimuotoon.

        Palauttaa monirivisen merkkijonon jossa:
        - Tila: READY / HALTED / EXITED
        - Syklit: suoritettujen käskyjen kokonaismäärä
        - PC, SP, SR: tärkeimmät rekisteriarvot hex-muodossa
        """
        cpu = self.machine.cpu
        if cpu.halted:
            s = "HALTED"
        elif self.machine.process_exited:
            s = "EXITED"
        else:
            s = "READY"
        return (
            f"State: {s}  Cycles: {cpu.instruction_counter}\n"
            f"PC: 0x{self.machine.regs.pc:04X}  "
            f"SP: 0x{self.machine.regs.sp:04X}  "
            f"SR: 0x{self.machine.regs.sr:04X}"
        )

    def _show_disasm_in_log(self) -> None:
        """Näytä disassembly loki-widgetissä (disasm-komento).

        Lukee 30 sanaa muistista alkaen PC-6 ja disassembloi ne.
        Nykyinen PC korostetaan vihreällä taustalla (> -merkki).
        Tämä on vaihtoehto disassembly-paneelille - hyödyllinen
        kun haluaa nähdä disassemblyn loki-kontekstissa.
        """
        pc = self.machine.regs.pc
        start = max(0, pc - 6)
        words = [self.machine.memory.read(start + i) for i in range(30)]
        result = self.disassembler.disassemble(words, start)
        self._log("[bold]Disassembly:[/bold]")
        for line in result.split("\n"):
            addr_part = line.split(":")[0].strip()
            try:
                addr = int(addr_part, 16)
                if addr == pc:
                    self._log(f"[bold on dark_green]> {line}[/]")
                else:
                    self._log(f"  {line}")
            except ValueError:
                self._log(f"  {line}")

    # ------------------------------------------------------------------
    # Apumetodit
    # ------------------------------------------------------------------

    def _log(self, message: str) -> None:
        """Kirjoita viesti Log-välilehden RichLog-widgettiin.

        Tukee Rich-markupia (esim. [bold], [red], [dim]).
        Hiljaisesti ohittaa poikkeukset jos widget ei ole käytettävissä
        (esim. sovelluksen sammutuksen aikana).
        """
        try:
            self.query_one("#log-view", RichLog).write(message)
        except Exception:
            pass


def run_tui() -> int:
    """Käynnistä kCPU16 TUI-sovellus.

    Entry point jota kutsutaan CLI:stä (esim. __main__.py tai console_scripts).
    Luo KCPU16TUI-instanssin ja käynnistää Textual-tapahtumasilmukan.
    Palaa vasta kun käyttäjä sulkee sovelluksen (Ctrl+Q).

    Palauttaa:
        int: Exit-koodi (0 = normaali lopetus).
    """
    app = KCPU16TUI()
    app.run()
    return 0
