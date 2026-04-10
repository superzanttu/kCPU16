# pyright: reportMissingImports=false
"""Ammattimainen Textual TUI kCPU16-emulaattorille.

Tämä moduuli toteuttaa kCPU16-emulaattorin päätason käyttöliittymän.
Se on debuggeri-tyylinen TUI (Text User Interface), joka yhdistää
reaaliaikaisen disassemblyn, rekisterinäkymän, muistinäkymän ja
VRAM-näytön yhteen interaktiiviseen sovellukseen.

Assembly-lähdekoodi ladataan ulkoisesta tiedostosta (load-komento tai
komentoriviargumentti). Ohjelma kääntää ladatun tiedoston automaattisesti
ja seuraa sitä: kun tiedosto muuttuu, se ladataan ja käännetään uudelleen.

Inspiroitu MARS/RARS, GDB TUI, Turbo Debugger ja emu8086 -ohjelmistoista.

Tärkeimmät luokat:
    KCPU16TUI       -- Päätason Textual App -sovellus (koko käyttöliittymä).
    CommandResult   -- Komentotulkin paluuarvo (ok/virhe + viesti).

Tärkeimmät funktiot:
    _build_addr_to_line  -- Rakentaa konekieliosoite → lähdekoodirivi -mapin.
    run_tui              -- Käynnistää TUI:n (entry point).

Riippuvuudet:
    Textual >= 0.80 (testattu 0.82.1): App, TabbedContent, RichLog
    Rich (Textual sisältää): Rich-markup värikoodeihin

Tietovirta:
    1. Käyttäjä avaa .asm-tiedoston (load-komento tai käynnistysparametri)
    2. _do_open() → _do_assemble() kutsuu Assembler.assemble() → konekielisanat
    3. Machine.cold_reset() + load_program() → sanat muistiin osoitteesta 0x0100
    4. Tiedostoa seurataan: muuttunut tiedosto ladataan ja käännetään automaattisesti
    5. F7/Step → machine.step() → _refresh_all() päivittää kaikki paneelit
    6. Disassembler lukee muistia PC:n ympäriltä ja näyttää disassemblyn

Layout:
  ┌─ Toolbar (Open | Assemble ^B | Step F7|Run F5|Reset ^R | BP F2)
  ├──────────────┬─────────────────────────────────────────────────────┤
  │ SCREEN       │ DISASSEMBLY/MEM/STK                                 │
  │ (80x24 VRAM) │ (TabbedContent)                                     │
  │              │ ●=breakpoint  ▶=nykyinen PC                         │
  ├──────────────┴─────────────────────────────────────────────────────┤
  │ LOG (lokiviestit + komentosyöte)                                   │
  ├───────────────────────────────────────────────────────────────────┤
  │ FLAGS Z N C V I P  │ REGISTERS                                     │
  │ CPU state/cycles   │ (muuttuneet=punainen)                         │
  └────────────────────┴───────────────────────────────────────────────┘
"""

from __future__ import annotations

import re
import time
from dataclasses import dataclass
from pathlib import Path

# Poistaa Rich-markup-tagit (esim. [bold], [/red], [dim]) pelkään tekstiksi
_RICH_MARKUP_RE = re.compile(r"\[/?[^\[\]]+?\]")

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual import events
from textual.message import Message
from textual.screen import ModalScreen
from textual.widget import Widget
from textual.worker import get_current_worker
from textual._work_decorator import work
from textual.widgets import (
    Button,
    Checkbox,
    Input,
    RichLog,
    Static,
    TabbedContent,
    TabPane,
)

from .assembler import Assembler, MNEMONIC_TO_OPCODE
from .constants import (
    ARCH_SYMBOLS,
    BOOT_RAM_START,
    GFX_MODE_REG,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    WORD_MASK,
)
from .debugger import DebugState
from .disassembler import Disassembler, REVERSE_TABLE

from .instruction import OPCODE_TABLE
from .machine import KCPU16Machine
from .specs import format_arch_spec_report
from . import __version__


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


# ===========================================================================
# Tallentamattomien muutosten vahvistusikkuna
# ===========================================================================


class SaveConfirmDialog(ModalScreen):
    """Modalikkuna tallentamattomien muutosten tallentamiseen ennen sulkemista.

    Näyttää KYLLÄ/EI/PERUUTA -painikkeet sekä valintaruudut niille
    kohteille (editori, tallennuslaite), joissa on tallentamattomia muutoksia.
    Käyttäjä voi poistaa ruksit kohteilta, joita ei halua tallentaa.

    Palauttaa dismiss():lla tuplen:
        ("yes",    save_editor: bool, save_disk: bool)  -- Tallenna ja poistu
        ("no",     False, False)                         -- Poistu tallentamatta
        ("cancel", False, False)                         -- Peruuta (älä poistu)
    """

    CSS = """
    SaveConfirmDialog {
        align: center middle;
    }
    #save-dialog {
        background: $surface;
        border: thick $primary;
        padding: 1 2;
        width: 56;
        height: auto;
    }
    #save-dialog-title {
        text-align: center;
        text-style: bold;
        color: $warning;
        margin-bottom: 1;
    }
    #save-dialog-question {
        margin-bottom: 1;
    }
    #save-dialog-checks {
        margin-bottom: 1;
        height: auto;
    }
    #save-dialog-error {
        color: $error;
        height: auto;
        min-height: 1;
        margin-bottom: 1;
    }
    #save-dialog-buttons {
        layout: horizontal;
        align: center middle;
        height: 3;
    }
    #save-dialog-buttons Button {
        margin: 0 1;
    }
    """

    def __init__(
        self,
        editor_dirty: bool,
        disk_dirty: bool,
        editor_has_file: bool,
        disk_has_file: bool,
    ) -> None:
        super().__init__()
        self._editor_dirty = editor_dirty
        self._disk_dirty = disk_dirty
        self._editor_has_file = editor_has_file
        self._disk_has_file = disk_has_file

    def compose(self) -> ComposeResult:
        with Vertical(id="save-dialog"):
            yield Static("Tallentamattomat muutokset", id="save-dialog-title")
            yield Static("Tallenetaanko muuttuneet tiedot?", id="save-dialog-question")
            with Vertical(id="save-dialog-checks"):
                if self._editor_dirty:
                    yield Checkbox("Editori (.asm)", value=True, id="chk-editor")
                if self._disk_dirty:
                    yield Checkbox("Tallennuslaite (.dsk)", value=True, id="chk-disk")
            yield Static("", id="save-dialog-error")
            with Horizontal(id="save-dialog-buttons"):
                yield Button("Kyllä", id="btn-save-yes", variant="primary")
                yield Button("Ei", id="btn-save-no", variant="default")
                yield Button("Peruuta", id="btn-save-cancel", variant="warning")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id

        if btn_id == "btn-save-cancel":
            self.dismiss(("cancel", False, False))
            return

        if btn_id == "btn-save-no":
            self.dismiss(("no", False, False))
            return

        if btn_id == "btn-save-yes":
            save_editor = False
            save_disk = False

            if self._editor_dirty:
                try:
                    save_editor = bool(self.query_one("#chk-editor", Checkbox).value)
                except Exception:
                    save_editor = True

            if self._disk_dirty:
                try:
                    save_disk = bool(self.query_one("#chk-disk", Checkbox).value)
                except Exception:
                    save_disk = True

            # Tarkista: rastitettu kohde tarvitsee tiedostonimen
            errors: list[str] = []
            if save_editor and not self._editor_has_file:
                errors.append(
                    "Editorin .asm-tiedostolla ei ole tallennusnimeä.\n"
                    "Tallenna ensin komennolla: save <nimi>"
                )
            if save_disk and not self._disk_has_file:
                errors.append(
                    "Tallennuslaitteen .dsk-tiedostolla ei ole tallennusnimeä.\n"
                    "Tallenna ensin komennolla: disk save <nimi>"
                )

            if errors:
                self.query_one("#save-dialog-error", Static).update("\n".join(errors))
                return  # Pysytään dialogissa, ei suljeta

            self.dismiss(("yes", save_editor, save_disk))

    def on_key(self, event) -> None:
        if event.key == "escape":
            self.dismiss(("cancel", False, False))


# ===========================================================================
# SpeedSlider — liukusäädin SLOW-nopeuden säätöön
# ===========================================================================

_SLIDER_TRACK_W = 54  # raitaosa merkeissä (3× leveämpi)
_SLIDER_MAX_IPS = 1000  # suurin sallittu IPS-arvo


class SpeedSlider(Widget):
    """Liukusäädin SLOW-suoritusnopeuden säätöön (1–1000 IPS).

    Näyttää nykyisen IPS-arvon ja graafisen raidan. Raitaa voi klikata
    tai raahata arvon muuttamiseksi. Hiiren rullalla säätää logaritmisesti.
    Arvon muuttuessa lähetetään SpeedSlider.Changed -viesti.
    """

    DEFAULT_CSS = """
    SpeedSlider {
        width: 70;
        height: 3;
        padding: 0 1;
        content-align: center middle;
        color: $text-muted;
    }
    """

    class Changed(Message):
        """Lähetetään kun liukusäätimen arvo muuttuu."""

        def __init__(self, value: int) -> None:
            super().__init__()
            self.value = value

    def __init__(self, value: int = 10, *, id: str | None = None) -> None:
        super().__init__(id=id)
        self._value: int = max(1, min(_SLIDER_MAX_IPS, value))
        self._multiplier: int = 1
        self._dragging: bool = False

    @property
    def value(self) -> int:
        return self._value

    @value.setter
    def value(self, val: int) -> None:
        val = max(1, min(_SLIDER_MAX_IPS, val))
        if val != self._value:
            self._value = val
            self.refresh()
            self.post_message(self.Changed(self._value))

    def render(self) -> str:
        import math

        # Logaritminen skala: pienet arvot saavat enemmän tilaa
        log_val = math.log10(self._value)
        log_max = math.log10(_SLIDER_MAX_IPS)
        ratio = log_val / log_max
        pos = round(ratio * (_SLIDER_TRACK_W - 1))
        track = "═" * pos + "●" + "═" * (_SLIDER_TRACK_W - 1 - pos)
        effective = self._value * self._multiplier
        return f"IPS:{effective:5d} [{track}]"

    def _x_to_value(self, x: int) -> int:
        import math

        # padding(1) + "IPS:NNNN ["(10) = offset 11
        track_start = 11
        rel = x - track_start
        ratio = max(0.0, min(1.0, rel / (_SLIDER_TRACK_W - 1)))
        # Logaritminen muunnos: ratio → IPS
        val = round(10 ** (ratio * math.log10(_SLIDER_MAX_IPS)))
        return max(1, min(_SLIDER_MAX_IPS, val))

    def on_mouse_down(self, event: events.MouseDown) -> None:
        self._dragging = True
        self.capture_mouse()
        new_val = self._x_to_value(event.x)
        if new_val != self._value:
            self._value = new_val
            self.refresh()
            self.post_message(self.Changed(self._value))

    def on_mouse_move(self, event: events.MouseMove) -> None:
        if self._dragging:
            new_val = self._x_to_value(event.x)
            if new_val != self._value:
                self._value = new_val
                self.refresh()
                self.post_message(self.Changed(self._value))

    def on_mouse_up(self, event: events.MouseUp) -> None:
        if self._dragging:
            self._dragging = False
            self.release_mouse()

    def on_mouse_scroll_up(self, event: events.MouseScrollUp) -> None:
        # Logaritminen askel: +10% tai vähintään +1
        step = max(1, round(self._value * 0.1))
        self.value = self._value + step

    def on_mouse_scroll_down(self, event: events.MouseScrollDown) -> None:
        # Logaritminen askel: -10% tai vähintään -1
        step = max(1, round(self._value * 0.1))
        self.value = self._value - step


# ===========================================================================
# TUI-sovellus
# ===========================================================================


class KCPU16TUI(App[None]):
    """Päätason Textual-sovellus: kCPU16 emulaattori-debuggeri.

    Tämä on koko TUI:n juuriluokka. Se luo kaikki widgetit (disassembly,
    rekisterit, jne.), hallinnoi koneen tilaa ja välittää käyttäjän syötteet
    (näppäimet, painikkeet, komennot) oikeille toiminnoille.

    Assembly-lähdekoodi ladataan ulkoisesta tiedostosta (load-komento tai
    käynnistysparametri). Ohjelma kääntää ladatun tiedoston automaattisesti
    ja seuraa tiedostoa: muutokset uudelleenladataan automaattisesti.

    Instanssimuuttujat:
        machine          -- KCPU16Machine: CPU + muisti + laitteet.
        assembler        -- Assembler: kääntää assembly → konekieli.
        disassembler     -- Disassembler: konekieli → luettava assembly.
        dbg              -- DebugState: breakpointit + rekisterimuutosten seuranta.
                           HUOM: self.dbg (EI self.debug), koska Textual App:ssa
                           on sisäänrakennettu debug-property.
        current_file     -- Ladatun tiedoston polku (None = ei ladattu).
        mem_view_addr    -- Memory-näkymän aloitusosoite (oletus 0x0100).
        addr_to_line     -- Osoite → lähdekoodirivi -mappi (_build_addr_to_line).
        is_assembled     -- True kun koodi on assembloitu ja ladattu muistiin.
        _watched_mtime   -- Viimeksi havaittu tiedoston muutosaika nanosekunteina (tiedoston tarkkailu).

    Widget-hierarkia:
        Toolbar (Horizontal + Buttonit) → content-area (Horizontal):
            left-panel: top-section (Horizontal):
                            screen-section (Static, VRAM 80x24)
                            disasm-tabs (TabbedContent: Disassembly|Memory|Stack)
                        output-pane (RichLog, kaikki tulosteet + komentosyöte)
                        bottom-bar (Horizontal):
                            flags-pane (Flags+CPU) | regs-pane (Registers)

    Päivityslogiikka:
        _refresh_all() kutsutaan jokaisen muutoksen jälkeen (step, run, reset,
        assemble). Se päivittää kaikki paneelit synkronisesti. Timereita käytetään
        Screen-välilehden (1s) ja tiedoston muutostarkistuksen (1s) päivittämiseen.
    """

    TITLE = "kCPU16 Emulator"
    SUB_TITLE = "16-bit CPU Emulator"

    # Textual CSS: Määrittelee koko sovelluksen visuaalisen layoutin.
    #
    # Rakenne ylhäältä alas:
    #   1. #toolbar          - Yläpalkki: painikkeet (dock: top, height: 3)
    #   2. #content-area     - Pääalue (height: 1fr, horizontal):
    #      - #left-panel     - Koko leveys: Screen+Disasm | Log | Cmds | Bottom bar
    #        - #top-section  - Yläosa (horizontal): Screen (82) + Disasm tabs (1fr)
    #        - #output-pane  - Tulosteet + komentosyöte (height: 1fr)
    #        - #bottom-bar   - Alarivi (horizontal): Flags + Registers
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
    #run-mode-label {
        min-width: 14;
        height: 3;
        padding: 0 1;
        content-align: center middle;
        color: $text-muted;
    }
    #speed-control-group {
        height: 3;
        width: auto;
        layout: horizontal;
    }
    SpeedSlider {
        width: 70;
        height: 3;
        padding: 0 1;
        content-align: center middle;
        color: $text-muted;
    }
    #speed-mult-group {
        height: 3;
        width: auto;
        layout: horizontal;
    }
    #speed-mult-group > Button {
        min-width: 6;
        height: 3;
        margin: 0;
    }
    Button.mult-selected {
        background: $accent;
        color: $text;
    }

    /* ---- Content area ---- */
    #content-area {
        height: 1fr;
        layout: horizontal;
    }

    /* -- Left panel: Screen+Disasm top, Log+CmdOutput bottom -- */
    #left-panel {
        width: 1fr;
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
        border: solid $primary-darken-2;
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
        width: 1fr;
        height: 1fr;
        border: solid $primary-darken-2;
        border-title-color: $accent;
    }
    #output-view {
        height: 1fr;
    }

    /* ---- cmd-input inside output-pane ---- */
    #cmd-input {
        dock: bottom;
        width: 1fr;
    }

    /* ---- Bottom bar: Flags | Registers | Output ---- */
    #bottom-bar {
        height: 1fr;
    }
    #flags-pane {
        width: 30;
        height: 1fr;
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
    }
    #regs-pane {
        width: 40;
        height: 1fr;
        border: solid $warning-darken-1;
        border-title-color: $accent;
        padding: 0 1;
        overflow-y: auto;
    }
    """

    # Näppäinsidonnaisuudet (Textual Binding).
    # priority=True tarkoittaa, että nämä toimivat aina (myös syötekentän ollessa aktiivinen).
    # Sidonnaisuudet näkyvät myös Footerissa automaattisesti.
    BINDINGS = [
        Binding("ctrl+q", "quit", "Quit", priority=True),
        Binding("f2", "toggle_breakpoint", "BP F2", priority=True),
        Binding("f4", "run_max_speed", "Max F4", priority=True),
        Binding("f5", "run_full_speed", "Fast F5", priority=True),
        Binding("f6", "run_slow_speed", "Slow F6", priority=True),
        Binding("f8", "stop_program", "Stop F8", priority=True),
        Binding("f7", "step_once", "Step F7", priority=True),
        Binding("f10", "step_once", "Step", priority=True),
        Binding("ctrl+r", "reset_machine", "Reset", priority=True),
        Binding("ctrl+o", "open_file", "Load", priority=True),
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
            machine          -- CPU-emulaattori (muisti, rekisterit, laitteet).
            assembler        -- Assembly → konekieli -kääntäjä.
            disassembler     -- Konekieli → assembly -purkaja.
            dbg              -- Debug-tila (breakpointit, rekisterisnapshot).
            current_file     -- Avoinna oleva tiedostopolku (None aluksi).
            mem_view_addr    -- Memory-tabin näyttöosoite (oletus 0x0100).
            addr_to_line     -- PC-osoite → lähdekoodirivi -mappi.
            is_assembled     -- Onko koodi assembloitu muistiin.
            _watched_mtime   -- Viimeksi havaittu tiedoston muutosaika nanosekunteina.
        """
        super().__init__()
        self.machine = KCPU16Machine()
        self.assembler = Assembler()
        self.disassembler = Disassembler()
        self.dbg = DebugState()
        self.current_file: Path | None = None
        self.current_disk_file: Path | None = None
        self.code_dir: Path = Path(__file__).resolve().parent / "code"
        self.code_dir.mkdir(exist_ok=True)
        self.storage_dir: Path = Path(__file__).resolve().parent / "storage"
        self.storage_dir.mkdir(exist_ok=True)
        self.mem_view_addr: int = BOOT_RAM_START
        self.addr_to_line: dict[int, int] = {}
        self.is_assembled: bool = False
        self._last_screen_render: str = ""
        self._output_buffer: list[str] = []
        self._disk_dirty: bool = False
        self._watched_mtime: int | None = None  # st_mtime_ns (kokonaisluku)
        self._exec_mode: str = (
            "stopped"  # "stopped" | "step" | "fast" | "max" | "slow" | "reset"
        )
        self._slow_ips: int = 10  # käskyä/sekuntti SLOW-tilassa (1–1000)
        self._slow_multiplier: int = 1  # kerroin: 1, 10 tai 100
        # --asm listing caches (rebuilt each assemble)
        self._asm_addr_to_src: dict[int, str] = {}  # addr → raw source line
        self._asm_addr_to_label: dict[int, str] = {}  # addr → label name
        self._asm_jump_targets: dict[int, list[str]] = {}  # addr → list of "MNEM@XXXX"

    # ------------------------------------------------------------------
    # Layout
    # ------------------------------------------------------------------

    def compose(self) -> ComposeResult:
        """Rakenna sovelluksen widget-puu (Textual compose -pattern).

        Widget-hierarkia:
            Toolbar (#toolbar): Open, Assemble, Step, Run, Reset,
                                BP, Clear, Help -painikkeet
            Content area (#content-area, Horizontal):
                #left-panel (Vertical, 1fr):
                    #top-section (Horizontal):
                        #screen-section: Static (VRAM 80x24)
                        #disasm-tabs (TabbedContent: Disassembly|Memory|Stack)
                    #output-pane: RichLog (kaikki tulosteet) + Input (komentosyöte)
                    #bottom-bar (Horizontal):
                        #flags-pane: Flags + CPU-tila
                        #regs-pane: Rekisterit
        """
        # Toolbar
        with Horizontal(id="toolbar"):
            yield Button("Load", id="btn-open", variant="default")
            yield Static(" ", classes="sep")
            yield Button("Assemble ^B", id="btn-asm", variant="primary")
            yield Static(" ", classes="sep")
            yield Button("Step F7", id="btn-step", variant="primary")
            yield Button("Fast F5", id="btn-run-full", variant="success")
            yield Button("Max F4", id="btn-run-max", variant="success")
            yield Button("Slow F6", id="btn-run-slow", variant="success")
            yield Button("Stop F8", id="btn-stop", variant="default")
            yield Button("Reset ^R", id="btn-reset", variant="error")
            yield Static(" ", classes="sep")
            yield Button("BP F2", id="btn-bp", variant="default")
            yield Button("Clear F9", id="btn-clear", variant="default")
            yield Button("Help F1", id="btn-help", variant="default")
            yield Static(" ", classes="sep")
            with Horizontal(id="speed-control-group"):
                yield SpeedSlider(value=10, id="speed-slider")
                with Horizontal(id="speed-mult-group"):
                    yield Button("x1", id="btn-mult-x1", classes="mult-selected")
                    yield Button("x10", id="btn-mult-x10")
                    yield Button("x100", id="btn-mult-x100")
            yield Static("\u25a0 STOPPED", id="run-mode-label")

        # Content area: left panel (full width)
        with Horizontal(id="content-area"):
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
                with Horizontal(id="bottom-bar"):
                    with Vertical(id="flags-pane"):
                        yield Static(id="flags-content")
                        yield Static(id="cpu-content")
                    with Vertical(id="regs-pane"):
                        yield Static(id="regs-content")
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

    # ------------------------------------------------------------------
    # Alustus
    # ------------------------------------------------------------------

    def on_mount(self) -> None:
        """Alusta sovellus kun DOM on valmis (Textual lifecycle).

        Suoritetaan kerran kun kaikki widgetit ovat luotu ja kiinnitetty
        DOM-puuhun. Tässä:
        1. Asetetaan paneelien otsikot (border_title)
        2. Resetoidaan kone (cold_reset) ja otetaan rekisterisnapshot
        3. Kirjoitetaan tervetuloa-viestit lokiin
        4. Lataa käynnistysparametreilla annetut tiedostot
        5. Päivitetään kaikki näkymät (_refresh_all)
        6. Käynnistetään timereita: Screen-päivitys (1.0s) + tiedoston tarkkailu (1.0s)
        """
        self.query_one("#regs-pane").border_title = "Registers"
        self.query_one("#flags-pane").border_title = "Flags"
        self.query_one("#screen-section").border_title = "Screen"
        self.query_one("#output-pane").border_title = "Output"

        self.machine.cold_reset()
        self.dbg.snapshot_registers(self.machine.dump_registers())

        self._log(f"[bold]kCPU16 Debugger[/bold] v{__version__} ready.")
        self._log(
            "[dim]F7/F10=Step  F5=Run  F2=Breakpoint  "
            "Ctrl+B=Assemble  Ctrl+O=Load[/dim]"
        )
        self._log("[dim]Type 'help' for command list.[/dim]")

        # Lataa käynnistysparametreilla annetut tiedostot
        startup_asm: Path | None = getattr(self, "startup_asm", None)
        startup_dsk: Path | None = getattr(self, "startup_dsk", None)

        if startup_dsk is not None:
            try:
                self.machine.storage.load_from_file(startup_dsk)
                self.current_disk_file = startup_dsk
                self._update_disk_title()
                self._log(f"[green]Storage loaded from {startup_dsk}[/green]")
            except Exception as e:
                self._log(f"[red]Storage load error: {e}[/red]")

        if startup_asm is not None:
            self._do_open(startup_asm)

        self._refresh_all()
        self.set_interval(1.0, self._refresh_screen_tab)
        self.set_interval(1.0, self._check_file_changes)
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
            "btn-asm": self.action_assemble_code,
            "btn-step": self.action_step_once,
            "btn-run-full": self.action_run_full_speed,
            "btn-run-max": self.action_run_max_speed,
            "btn-run-slow": self.action_run_slow_speed,
            "btn-stop": self.action_stop_program,
            "btn-reset": self.action_reset_machine,
            "btn-bp": self.action_toggle_breakpoint,
            "btn-clear": self.action_clear_screen,
            "btn-help": self.action_show_help,
        }
        action = actions.get(event.button.id)
        if action:
            action()
            return

        # Nopeudenkertoimen valinta
        if event.button.id in ("btn-mult-x1", "btn-mult-x10", "btn-mult-x100"):
            mult_map = {"btn-mult-x1": 1, "btn-mult-x10": 10, "btn-mult-x100": 100}
            self._slow_multiplier = mult_map[event.button.id]
            for bid in ("btn-mult-x1", "btn-mult-x10", "btn-mult-x100"):
                try:
                    self.query_one(f"#{bid}", Button).remove_class("mult-selected")
                except Exception:
                    pass
            event.button.add_class("mult-selected")
            try:
                sl = self.query_one("#speed-slider", SpeedSlider)
                sl._multiplier = self._slow_multiplier
                sl.refresh()
            except Exception:
                pass

    def on_speed_slider_changed(self, event: SpeedSlider.Changed) -> None:
        """Päivitä SLOW-nopeus kun liukusäädin muuttuu."""
        self._slow_ips = event.value

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
        if cmd_verb in {"step", "run", "slow", "restart", "asm", "reset", "stop"}:
            self._refresh_all(include_screen=True)

    # ------------------------------------------------------------------
    # Actions (näppäinsidonnaisuudet)
    # ------------------------------------------------------------------

    def _reload_and_run(self, mode: str) -> None:
        """Lataa nykyinen tiedosto uudelleen ja aloita suoritus annetussa moodissa.

        Kutsutaan kun CPU on pysähtynyt (HALT/EXIT) ja käyttäjä painaa
        Step, Fast, Slow tai Stop. Jos tiedostoa ei ole ladattu, logitetaan ilmoitus.

        Args:
            mode: "step", "fast", "slow" tai "stop"
        """
        if not self.current_file:
            self._log("[yellow]Ei ladattua ohjelmaa. Käytä 'load <tiedosto>'.[/yellow]")
            return
        self.workers.cancel_all()
        self._exec_mode = "stopped"
        self._do_assemble()  # cold_reset + lataa + assembloi
        if not self.is_assembled:
            return
        self._log(f"[cyan]Uudelleenladattu: {self.current_file.name}[/cyan]")
        if mode == "step":
            self.machine.step()
            self._log_step_info()
            self._exec_mode = "step"
            self._update_run_mode_ui()
            self._refresh_all(include_screen=True)
        elif mode == "fast":
            self._exec_mode = "fast"
            self._update_run_mode_ui()
            self._log("[green]Running fast... (F5/F8 to stop)[/green]")
            self._cpu_run_worker("fast")
        elif mode == "max":
            self._exec_mode = "max"
            self._update_run_mode_ui()
            self._log("[green]Running max... (F4/F8 to stop)[/green]")
            self._cpu_run_worker("max")
        elif mode == "slow":
            self._exec_mode = "slow"
            self._update_run_mode_ui()
            self._log(
                f"[green]Running slow ({self._slow_ips * self._slow_multiplier} IPS)... (F6/F8 to stop)[/green]"
            )
            self._cpu_run_worker("slow")
        # mode == "stop": pelkkä uudelleenlataus riittää, _do_assemble hoiti

    def action_step_once(self) -> None:
        """Suorita yksi konekielikäsky (F7/F10 tai Step-painike).

        Tarkistaa ensin onko CPU pysähtynyt (HALT/EXIT). Jos on,
        ladataan ohjelma uudelleen ja suoritetaan ensimmäinen askel.
        """
        if self.machine.cpu.halted or self.machine.process_exited:
            self._reload_and_run("step")
            return
        self.machine.step()
        self._log_step_info()
        self._exec_mode = "step"
        self._update_run_mode_ui()
        self._refresh_all(include_screen=True)

    def action_run_full_speed(self) -> None:
        """Käynnistä CPU täydellä nopeudella (F5). Toinen painalus pysäyttää.

        Jos CPU on pysähtynyt (HALT/EXIT), ladataan ohjelma uudelleen ja
        käynnistetään täydellä nopeudella.
        """
        if self._exec_mode == "fast":
            self.action_stop_program()
            return
        if self.machine.cpu.halted or self.machine.process_exited:
            self._reload_and_run("fast")
            return
        self.workers.cancel_all()
        self._exec_mode = "fast"
        self._update_run_mode_ui()
        self._log("[green]Running fast... (F5/F8 to stop)[/green]")
        self._cpu_run_worker("fast")

    def action_run_max_speed(self) -> None:
        """Käynnistä CPU MAX-nopeudella (F4). Näyttöä ei päivitetä ajon aikana.

        MAX-tilassa suoritus on maksimaalinen: näyttöä (VRAM) ei päivitetä
        ajon aikana, vain pysähdyttäessä. Käyttöliittymä pysyy muutoin toimivana.
        Toinen F4-painallus pysäyttää.
        """
        if self._exec_mode == "max":
            self.action_stop_program()
            return
        if self.machine.cpu.halted or self.machine.process_exited:
            self._reload_and_run("max")
            return
        self.workers.cancel_all()
        self._exec_mode = "max"
        self._update_run_mode_ui()
        self._log("[green]Running max... (F4/F8 to stop)[/green]")
        self._cpu_run_worker("max")

    def action_run_slow_speed(self) -> None:
        """Käynnistä CPU hidas suoritus (F6): ~10 IPS. Toinen painalus pysäyttää.

        Jos CPU on pysähtynyt (HALT/EXIT), ladataan ohjelma uudelleen ja
        käynnistetään hitaassa tilassa.
        """
        if self._exec_mode == "slow":
            self.action_stop_program()
            return
        if self.machine.cpu.halted or self.machine.process_exited:
            self._reload_and_run("slow")
            return
        self.workers.cancel_all()
        self._exec_mode = "slow"
        self._update_run_mode_ui()
        self._log(
            f"[green]Running slow ({self._slow_ips * self._slow_multiplier} IPS)... (F6/F8 to stop)[/green]"
        )
        self._cpu_run_worker("slow")

    def action_stop_program(self) -> None:
        """Pysäytä CPU:n suoritus (F8 tai Stop-painike).

        Jos CPU on jo pysähtynyt (HALT/EXIT), ladataan ohjelma uudelleen
        ja jäädään pysähtyneeseen tilaan (reset + lataus).
        """
        if self.machine.cpu.halted or self.machine.process_exited:
            self._reload_and_run("stop")
            return
        self.workers.cancel_all()
        self._exec_mode = "stopped"
        self._update_run_mode_ui()
        self._log("[yellow]Stopped.[/yellow]")
        self._refresh_all(include_screen=True)

    def action_reset_machine(self) -> None:
        """Resetoi kone alkutilaan (Ctrl+R tai Reset-painike).

        Peruuttaa mahdollisen käynnissä olevan taustayö-suorituksen ensin,
        sitten cold reset nollaa CPU:n, muistin ja laitteet.
        """
        self.workers.cancel_all()
        self._exec_mode = "reset"
        self.machine.cold_reset()
        self.is_assembled = False
        self.addr_to_line = {}
        self._asm_addr_to_src = {}
        self._asm_addr_to_label = {}
        self._asm_jump_targets = {}
        self.dbg.snapshot_registers(self.machine.dump_registers())
        self._update_run_mode_ui()
        self._log("[green]Machine reset.[/green]")
        self._refresh_all(include_screen=True)

    def action_toggle_breakpoint(self) -> None:
        """Aseta tai poista breakpoint nykyiseen PC-osoitteeseen (F2).

        Kutsuu dbg.toggle_breakpoint() joka palauttaa True jos lisättiin,
        False jos poistettiin. Logittaa tuloksen ja päivittää näkymät
        (disassembly näyttää ● breakpointatuille riveille).
        """
        addr = self.machine.regs.pc
        added = self.dbg.toggle_breakpoint(addr)
        if added:
            self._log(f"[yellow]Breakpoint SET at 0x{addr:04X}[/yellow]")
        else:
            self._log(f"Breakpoint REMOVED at 0x{addr:04X}")
        self._refresh_all()

    def action_open_file(self) -> None:
        """Avaa assembly-tiedosto (Ctrl+O).

        Asettaa fokuksen syötekenttään ja kirjoittaa "load " alkuun.
        Käyttäjä kirjoittaa polun ja painaa Enter,
        jolloin on_input_submitted → _execute_command käsittelee sen.
        """
        cmd_input = self.query_one("#cmd-input", Input)
        cmd_input.focus()
        if not cmd_input.value.strip().startswith("load "):
            cmd_input.value = "load "
        self._log("Type filename after 'load' and press Enter.")

    def action_assemble_code(self) -> None:
        """Assembloi ladattu koodi ja lataa se muistiin (Ctrl+B).

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

    def action_quit(self) -> None:
        """Sulje sovellus – tarkista tallentamattomat levymuutokset (Ctrl+Q).

        Jos levyllä on tallentamattomia muutoksia, näytetään vahvistusikkuna.
        """
        if not self._disk_dirty:
            self.exit()
            return

        def _on_confirm(result: tuple) -> None:
            choice, _save_editor, save_disk = result

            if choice == "cancel":
                return  # Palataan takaisin sovellukseen

            if choice == "yes" and save_disk and self.current_disk_file:
                try:
                    self.machine.storage.save_to_file(self.current_disk_file)
                    self._disk_dirty = False
                    self._update_disk_title()
                    self._log(
                        f"[green]Disk saved to {self.current_disk_file.name}[/green]"
                    )
                except Exception as e:
                    self._log(f"[red]Levyn tallennus epäonnistui: {e}[/red]")
                    return  # Älä poistu jos tallennus epäonnistui

            self.exit()

        self.push_screen(
            SaveConfirmDialog(
                editor_dirty=False,
                disk_dirty=self._disk_dirty,
                editor_has_file=False,
                disk_has_file=self.current_disk_file is not None,
            ),
            callback=_on_confirm,
        )

    def action_show_help(self) -> None:
        """Näytä ohje-teksti lokissa (F1).

        Tulostaa loki-widgettiin listan kaikista näppäinsidonnaisuuksista
        ja komennoista Rich-muotoiltuna.
        """
        self._log("")
        self._log("[bold]--- kCPU16 Debugger Help ---[/bold]")
        self._log("")
        self._log("[bold]Keyboard shortcuts:[/bold]")
        self._log("  Ctrl+O  Load file       Ctrl+B  Assemble code")
        self._log("  F7/F10  Step 1 instr    F5      Fast run")
        self._log("  F6      Slow run (10 IPS)  F8      Stop execution")
        self._log("  Ctrl+R  Reset machine   F9      Clear VRAM")
        self._log("  F2      Toggle BP       F1      This help")
        self._log("  Ctrl+Q  Quit")
        self._log("")
        self._log("[bold]File & Assembly:[/bold]")
        self._log(
            "  load <filename>              Load .asm (watches for changes, auto-reassembles)"
        )
        self._log("  asm                          Manually reassemble loaded file")
        self._log("  check                        Syntax check loaded file (no load)")
        self._log("[bold]CPU Control:[/bold]")
        self._log("  step [n]                     Step n instructions (default 1)")
        self._log("  run  [n]                     Fast run to BP/halt (max n cycles)")
        self._log(
            "  slow [n]                     Slow run (1–1000 IPS), all panels update each instr"
        )
        self._log("  stop                         Stop running CPU")
        self._log("  restart                      Reassemble and restart from 0x0100")
        self._log(
            "  speed <1–1000>               Set SLOW run speed in IPS (default 10)"
        )
        self._log("[bold]Breakpoints:[/bold]")
        self._log("  bp <addr>                    Toggle breakpoint at address")
        self._log("  bp list                      List all breakpoints")
        self._log("  bp clear                     Remove all breakpoints")
        self._log("[bold]Memory:[/bold]")
        self._log("  mem <addr> [count]           Show count words at addr (default 1)")
        self._log("  mset <addr> <value>          Write value to addr")
        self._log("  mfill <addr> <count> <value> Fill count words starting at addr")
        self._log("[bold]Disk (Storage):[/bold]")
        self._log("  disk <block>                 Show block as hex dump")
        self._log("  disk load <path>             Load .dsk file into storage")
        self._log(
            "  disk save [path]             Save storage to .dsk (omit path to reuse last)"
        )
        self._log("  dset <block> <offset> <value>  Write value at block + offset")
        self._log("  dfill <block> <value>        Fill entire block with value")
        self._log(
            "  mem2disk <addr> <block>      Copy one block of words from mem to disk"
        )
        self._log("  disk2mem <block> <addr>      Copy disk block to memory")
        self._log("[bold]Reset:[/bold]")
        self._log("  reset                        Memory + CPU (storage intact)")
        self._log("  reset deep                   Memory + CPU + storage")
        self._log("  reset cpu                    CPU only (memory intact)")
        self._log("[bold]Other:[/bold]")
        self._log("  cls                          Clear VRAM")
        self._log("  spec                         Show architecture spec")
        self._log("  help                         This help")
        self._log("")
        self._log("[bold]Parameter syntax:[/bold]")
        self._log("  <addr>    Memory address         0–0xFFFF (e.g. 256 or 0x0100)")
        self._log("  <value>   16-bit word            0–0xFFFF (e.g. 42 or 0x002A)")
        self._log("  <count>   Number of items        (e.g. 16 or 0x10)")
        self._log("  <block>   Storage block index    (e.g. 0, 1, 2 ...)")
        self._log("  <offset>  Word offset in block   (e.g. 0, 1, 2 ...)")
        self._log("  <path>    File path               (e.g. disk.dsk)")
        self._log("  <filename> .asm file in code/     (e.g. hello.asm)")
        self._log("  [param]   Optional parameter     (can be omitted)")
        self._log("")
        self._log("[bold]Number formats:[/bold]")
        self._log("  Decimal:  42, 256, 65535")
        self._log("  Hex:      0x2A, 0x0100, 0xFFFF")
        self._log("  Binary:   0b101010")
        self._log("  Octal:    0o52")
        self._log("---")

    # ------------------------------------------------------------------
    # Näppäimistönvälitys emulaattorille
    # ------------------------------------------------------------------

    def on_key(self, event) -> None:
        """Välitä tulostettavat merkit emulaattorin näppäimistölaitteelle.

        Kutsutaan jokaisesta näppäinpainalluksesta. Kun CPU on käynnissä ja
        näppäimistölaite on olemassa, tulostettavat ASCII-merkit (32–126)
        välitetään emulaattorin KeyboardDevice-jonoon – ellei käyttäjä
        kirjoita komentokenttään (#cmd-input).

        Terminaali ei tue näppäimennostotapahtumia, joten painallus ja
        vapautus lähetetään peräkkäin samasta tapahtumasta.
        """
        if self._exec_mode not in ("fast", "max", "slow"):
            return
        if self.machine.keyboard is None:
            return
        # Älä välitä jos käyttäjä kirjoittaa komentokenttään
        cmd_input = self.query_one("#cmd-input", Input)
        if cmd_input is self.focused:
            return
        char = event.character
        if char is None or len(char) != 1:
            return
        code = ord(char)
        if 32 <= code <= 126:  # tulostettava ASCII
            self.machine.keyboard.push_key(code)
            self.machine.keyboard.push_key_release(code)

    # ------------------------------------------------------------------
    # Perusoperaatiot
    # ------------------------------------------------------------------

    def _update_disk_title(self) -> None:
        """Päivitä Disassembly-paneelin alaotsikko näyttämään nykyinen levytiedosto.

        Näyttää tähden (*) nimen perässä kun levyllä on tallentamattomia muutoksia.
        """
        tabs = self.query_one("#disasm-tabs")
        name = self.current_disk_file.name if self.current_disk_file else ""
        if self._disk_dirty:
            tabs.border_subtitle = f"{name} *" if name else "*"
        else:
            tabs.border_subtitle = name

    def _sync_speed_slider(self) -> None:
        """Synkronoi liukusäätimen arvo _slow_ips:n mukaan."""
        try:
            self.query_one("#speed-slider", SpeedSlider)._value = self._slow_ips
            self.query_one("#speed-slider", SpeedSlider).refresh()
        except Exception:
            pass

    def _do_open(self, path: Path) -> None:
        """Avaa tiedosto, tallentaa polun ja kääntää sen automaattisesti.

        Tiedoston olemassaolo tarkistetaan ennen latausta. Onnistuessa
        asetetaan current_file = path, tallennetaan tiedoston mtime
        tiedoston tarkkailua varten ja kutsutaan _do_assemble().
        Virhetilanteessa logitetaan virhe.
        """
        try:
            if not path.exists():
                self._log(f"[red]Tiedostoa ei löydy: {path}[/red]")
                return
            self.current_file = path
            self.is_assembled = False
            self.addr_to_line = {}
            self._watched_mtime = path.stat().st_mtime_ns
            self._log(f"Loaded: [bold]{path}[/bold]")
            self._do_assemble()
        except Exception as e:
            self._log(f"[red]Error: {e}[/red]")

    def _do_assemble(self) -> None:
        """Assembloi ladattu tiedosto ja lataa se koneen muistiin.

        Tämä on TUI:n keskeinen operaatio - "tiedosto → konekieli → muisti":

        1. Lue current_file tiedostosta (source)
        2. assembler.assemble(source) → lista (osoite, sanat) -segmenttejä
        3. machine.cold_reset() → nollaa CPU, muisti, laitteet
        4. machine.load_segments(segments) → lataa segmentit muistiin
        5. _build_addr_to_line() → rakenna osoite→rivi -mappi
        6. dbg.snapshot_registers() → ota vertailupiste rekistereille
        7. _refresh_all() → päivitä kaikki näkymät

        Virhetilanteessa (syntaksivirhe, tuntematon käsky) assembly
        keskeytyy ja virhe näytetään lokissa punaisella.
        """
        if not self.current_file:
            self._log("[yellow]No file loaded. Use 'load <file>' or Ctrl+O.[/yellow]")
            return
        try:
            source = self.current_file.read_text(encoding="utf-8")
            if not source.strip():
                self._log("[yellow]File is empty.[/yellow]")
                return
            segments = self.assembler.assemble(source, source_path=self.current_file)
            self.machine.cold_reset()
            self.machine.load_segments(segments)
            self.is_assembled = True
            self._build_asm_caches(segments)
            self.addr_to_line = _build_addr_to_line(source, self.assembler)
            self.dbg.snapshot_registers(self.machine.dump_registers())
            total_words = sum(len(w) for _, w in segments)
            self._log(
                f"[green]Assembled: {total_words} words in {len(segments)} "
                f"segment(s) at 0x{self.machine.regs.pc:04X}. F7=Step, F5=Run.[/green]"
            )
            # .diskblock-direktiivi: kirjoita konekieli levyblokkiin
            blk = self.assembler.disk_block
            if blk is not None:
                blk_size = self.machine.storage.block_size_words
                code: list[int] = []
                for _, words in segments:
                    code.extend(words)
                # Täytä loppublokki nollilla
                code = (code + [0] * blk_size)[:blk_size]
                self.machine.storage.write_block(blk, code)
                self._disk_dirty = True
                self._update_disk_title()
                self._log(
                    f"[cyan].diskblock: {total_words} sanaa tallennettu "
                    f"levyblokkiin {blk}.[/cyan]"
                )
            self._exec_mode = "stopped"
            self._update_run_mode_ui()
            self._refresh_all()
        except Exception as e:
            self._log(f"[red]Assembly error: {e}[/red]")
            self.is_assembled = False

    def _build_asm_caches(self, segments: list[tuple[int, list[int]]]) -> None:
        """Rakenna --asm-listauksen tukitiedot assembloinnin jälkeen.

        Täyttää kolme hakutaulukkoa:
            _asm_addr_to_src      -- osoite → alkuperäinen lähdekoodi-rivi
            _asm_addr_to_label    -- osoite → käyttäjän labelinimi
            _asm_jump_targets     -- osoite → lista hyppääjistä ("MNEM@XXXX")

        Parametrit:
            segments: assemble():n palauttama lista (base_addr, words) -pareista.
        """
        _BRANCH_MNEMONICS: frozenset[str] = frozenset(
            {"JUMP", "CALL", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE"}
        )
        # osoite → lähdekoodi-rivi (kommentit mukaan, ei trimmattuna)
        self._asm_addr_to_src = {addr: src for src, addr in self.assembler.source_map}
        # osoite → labelinimi (vain käyttäjän labelit, ei arch-symbolit)
        arch_addrs: set[int] = set(ARCH_SYMBOLS.values())
        self._asm_addr_to_label = {
            addr: name
            for name, addr in self.assembler.labels.items()
            if addr not in arch_addrs and name not in ARCH_SYMBOLS
        }
        # Analysoi hyppykohteet segmentit läpikäyden
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
        self._asm_jump_targets = jump_targets

    def _check_file_changes(self) -> None:
        """Tarkista onko ladattu tiedosto muuttunut (1s timer).

        Jos tiedoston muutosaika (mtime) on muuttunut viimeksi havaitusta,
        ladataan ja käännetään tiedosto automaattisesti uudelleen.
        """
        if not self.current_file or not self.current_file.exists():
            return
        try:
            mtime = self.current_file.stat().st_mtime_ns
            if self._watched_mtime is not None and mtime != self._watched_mtime:
                self._watched_mtime = mtime
                self._log(
                    f"[dim]File changed: {self.current_file.name}. Reloading...[/dim]"
                )
                self._do_assemble()
        except Exception:
            pass

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

    def _update_run_mode_ui(self) -> None:
        """Päivitä toolbar heijastamaan nykyistä suoritustilaa.

        Päivittää #run-mode-label tekstin ja suorituspainikkeiden variantit.
        Turvallinen kutsua pääsäikeessä tai call_from_thread():n kautta.
        """
        try:
            label_text = {
                "stopped": "\u25a0 STOPPED",
                "step": "\u25a0 STEP",
                "fast": "\u25b6 FAST",
                "max": "\u25b6 MAX",
                "slow": "\u25b6 SLOW",
                "reset": "\u25a0 RESET",
            }.get(self._exec_mode, "\u25a0 STOPPED")
            self.query_one("#run-mode-label", Static).update(label_text)
            btn_full = self.query_one("#btn-run-full", Button)
            btn_max = self.query_one("#btn-run-max", Button)
            btn_slow = self.query_one("#btn-run-slow", Button)
            btn_stop = self.query_one("#btn-stop", Button)
            if self._exec_mode == "fast":
                btn_full.variant = "warning"
                btn_max.variant = "default"
                btn_slow.variant = "default"
                btn_stop.variant = "error"
            elif self._exec_mode == "max":
                btn_full.variant = "default"
                btn_max.variant = "warning"
                btn_slow.variant = "default"
                btn_stop.variant = "error"
            elif self._exec_mode == "slow":
                btn_full.variant = "default"
                btn_max.variant = "default"
                btn_slow.variant = "warning"
                btn_stop.variant = "error"
            else:  # stopped, step, reset
                btn_full.variant = "success"
                btn_max.variant = "success"
                btn_slow.variant = "success"
                btn_stop.variant = "default"
        except Exception:
            pass

    @work(thread=True, exclusive=True)
    def _cpu_run_worker(self, mode: str = "fast") -> None:
        """Aja CPU:ta taustasäikeessä (F5=Fast Speed, F6=Slow Speed).

        Parametrit:
            mode: "fast" = max nopeus, UI päivittyy ~200ms välein.
                  "slow" = ~10 IPS, UI päivittyy jokaisen käskyn jälkeen.

        Suoritus päättyy kun:
        - HALT- tai EXIT-käsky suoritetaan
        - Breakpoint osutaan
        - Worker peruutetaan (Stop/Reset)
        """
        worker = get_current_worker()
        cpu = self.machine.cpu
        total_cycles = 0

        def _done(msg: str) -> None:
            """Kutsutaan pääsäikeessä suorituksen päättyessä."""
            self._exec_mode = "stopped"
            self._update_run_mode_ui()
            if msg:
                self._log(msg)
            self._refresh_all(include_screen=True)

        if mode == "slow":
            # Hidas suoritus: yksi käsky kerrallaan, UI-päivitys joka käskyn jälkeen
            while not worker.is_cancelled:
                if cpu.halted or cpu.process_exit_requested:
                    break
                self.machine.step()
                total_cycles += 1
                if cpu.halted:
                    self.call_from_thread(
                        _done, f"[red]HALTED after {total_cycles} cycles.[/red]"
                    )
                    return
                if cpu.process_exit_requested:
                    self.call_from_thread(
                        _done, f"[yellow]EXIT after {total_cycles} cycles.[/yellow]"
                    )
                    return
                if self.dbg.has_breakpoint(self.machine.regs.pc):
                    addr = self.machine.regs.pc
                    self.call_from_thread(
                        _done,
                        f"[red]Breakpoint at 0x{addr:04X} after {total_cycles} cycles.[/red]",
                    )
                    return
                self.call_from_thread(self._refresh_all, True)
                time.sleep(1.0 / max(1, self._slow_ips * self._slow_multiplier))
        if mode in ("fast", "max"):
            # Täysi nopeus: eräsuoritus, UI päivittyy ~200ms välein
            # MAX-tilassa näyttöä (VRAM) ei päivitetä ajon aikana
            BATCH = 5000
            REFRESH_INTERVAL = 0.2  # sekuntia
            last_refresh = time.monotonic()
            while not worker.is_cancelled:
                for _ in range(BATCH):
                    if cpu.halted or cpu.process_exit_requested:
                        break
                    self.machine.step()
                    total_cycles += 1
                    if self.dbg.has_breakpoint(self.machine.regs.pc):
                        addr = self.machine.regs.pc
                        self.call_from_thread(
                            _done,
                            f"[red]Breakpoint at 0x{addr:04X} after {total_cycles} cycles.[/red]",
                        )
                        return
                # Päivitä UI ~200ms välein
                now = time.monotonic()
                if now - last_refresh >= REFRESH_INTERVAL:
                    last_refresh = now
                    if mode == "max":
                        # MAX-tilassa päivitetään vain Screen (VRAM), ei debug-paneeleja
                        self.call_from_thread(self._refresh_screen_tab)
                    else:
                        self.call_from_thread(self._refresh_all, True)
                if cpu.halted:
                    self.call_from_thread(
                        _done, f"[red]HALTED after {total_cycles} cycles.[/red]"
                    )
                    return
                if cpu.process_exit_requested:
                    self.call_from_thread(
                        _done, f"[yellow]EXIT after {total_cycles} cycles.[/yellow]"
                    )
                    return

        # Worker peruutettu (Stop / Reset)
        self.call_from_thread(_done, "")

    # ------------------------------------------------------------------
    # Näkymien päivitys
    # ------------------------------------------------------------------

    def _refresh_all(self, include_screen: bool = False) -> None:
        """Päivitä kaikki näkymäpaneelit kerralla.

        Kutsutaan jokaisen tilan muutoksen jälkeen (step, run, reset,
        assemble, komentosyöte).

        Parametrit:
            include_screen: Jos True, päivittää myös VRAM-näytön (Screen-tab).
                            Käytä True stepissä ja suoritustilan vaihtuessa.
        """
        self._refresh_disassembly()
        self._refresh_registers()
        self._refresh_flags()
        self._refresh_cpu_status()
        if include_screen:
            self._refresh_screen_tab()
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
                raw = self.disassembler.disassemble(
                    instr_words, start_addr=addr
                ).strip()
                disasm_tail = raw.split(": ", 1)[1] if ": " in raw else raw

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

        self.query_one("#disasm-content", Static).update("\n".join(lines))

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

        self.query_one("#regs-content", Static).update("\n".join(lines))

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

        # Configurable interrupt states
        tmr_str = f"[green]{r.tmr}[/] cyc" if r.tmr > 0 else "[dim]off[/]"
        ctmr_str = f"[green]{r.ctmr}[/] ms" if r.ctmr > 0 else "[dim]off[/]"

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
            f"GFX:  {gfx_str}"
        )
        self.query_one("#flags-content", Static).update(content)

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
            rendered = self.machine.screen.render_auto(self.machine.memory)
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
        self._log(
            f"[dim]IC={ic}[/dim] PC=0x{pc:04X}: " f"[bold]{instr}[/bold]{line_info}"
        )
        if self.machine.cpu.halted:
            self._log("[bold red]CPU halted (HALT).[/bold red]")
        elif self.machine.process_exited:
            self._log("[bold yellow]Process exited (EXIT).[/bold yellow]")

    # ------------------------------------------------------------------
    # Komentotulkki
    # ------------------------------------------------------------------

    def _execute_command(self, command: str) -> CommandResult:
        """Komentotulkki: parsii ja suorittaa komentosyötteen.

        Komennot:
            --- Tiedostot & assembly ---
            load <path>                  -- Avaa .asm tiedosto ja assembloi
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

    # ------------------------------------------------------------------
    # Uudet komentokäsittelijät
    # ------------------------------------------------------------------

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
                    "[yellow]Ei tallennettua levytiedostoa. Käytä: disk save <nimi>[/yellow]",
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
            self.addr_to_line = {}
            self._asm_addr_to_src = {}
            self._asm_addr_to_label = {}
            self._asm_jump_targets = {}
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
            self._asm_addr_to_src = {}
            self._asm_addr_to_label = {}
            self._asm_jump_targets = {}
            self.dbg.snapshot_registers(self.machine.dump_registers())
            self._disk_dirty = False
            self._update_disk_title()
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
            self._output_buffer.append(_RICH_MARKUP_RE.sub("", message))
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
