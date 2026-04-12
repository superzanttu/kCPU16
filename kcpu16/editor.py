# pyright: reportMissingImports=false
"""Assembly-editori kCPU16:lle.

Tarjoaa syntaksivärityksen ja peruseditorin toiminnallisuudet.
Integroituu TUI:hin TextArea-pohjaisen interaktiivisen editorin kautta.

Tämä moduuli on tarkoitettu ensisijaisesti CLI/REPL-käyttöön, jossa
Rich-pohjainen tekstirenderöinti on käytössä. TUI:ssa (``tui.py``)
varsinainen editointi tapahtuu Textualin ``TextArea``-widgetissä, joka
ei käytä tämän moduulin ``SimpleEditor``-luokkaa, mutta
``AssemblySyntaxHighlighter``-luokkaa käytetään myös TUI:n
disassembly-paneelissa.

Moduuli sisältää kaksi luokkaa:

- ``AssemblySyntaxHighlighter`` -- Staattinen apuluokka, joka muuntaa
  yhden assembly-rivin Rich-markup-muotoon (värikoodit). Ei ylläpidä
  tilaa, joten sitä voi kutsua mistä tahansa.
- ``SimpleEditor`` -- Tilallinen editori, joka pitää muistissa
  tiedoston sisällön ja tiedostonimen. Tarjoaa lataus-, tallennus- ja
  renderöintimetodit.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional


class AssemblySyntaxHighlighter:
    """Assembly-kielen syntaksin väritys Rich-muodossa.

    Luokka tunnistaa kCPU16-arkkitehtuurin assembly-kielen osat
    (mnemonicit, rekisterit, direktiivit, labelit, numerot ja
    kommentit) ja lisää niihin Rich-markup-tagit väritystä varten.

    Kaikki toiminnallisuus on staattisissa metodeissa ja
    luokkamuuttujissa, joten instanssia ei tarvitse luoda.

    Attributes
    ----------
    MNEMONICS : set[str]
        kCPU16-käskykantaan kuuluvat mnemonicit isoilla kirjaimilla.
        Sisältää muistikäskyt (LOAD, STORE, ...), aritmetiikan
        (ADD, SUB, ...), logiikan (AND, OR, ...), hyppykäskyt
        (JUMP, JZ, ...), pinokäskyt (PUSH, POP), keskeytykset
        (INT, IRET, ...) ja erikoiskäskyt (HALT, EXIT, DREAD, ...).
        Käytetään highlight_line-metodissa tunnistamaan käskysanat
        regex-haulla.
    REGISTERS : set[str]
        CPU:n rekisterinimet: R0-R3 (yleiskäyttöiset),
        FP (frame pointer) ja SP (stack pointer). Väritys: syaani.
    DIRECTIVES : set[str]
        Assemblerin direktiivit (.ORIGIN, .ORG, .MACRO, .ENDMACRO).
        Nämä eivät tuota konekieltä, vaan ohjaavat assemblerin
        toimintaa. Väritys: magenta.
    """

    MNEMONICS = {
        "LOAD", "CPY", "READ", "STORE", "READ_IND", "STORE_IND",
        "ADD", "SUB", "MUL", "DIV", "CMP",
        "AND", "OR", "XOR", "NOT", "SHL", "SHR",
        "PUSH", "POP",
        "JUMP", "CALL", "RET", "JZ", "JNZ", "JLT", "JGT", "JLE", "JGE",
        "INT", "IRET", "STI", "CLI", "HALT",
        "EXIT", "DREAD", "DWRITE", "SMPR", "STMR",
    }

    REGISTERS = {"R0", "R1", "R2", "R3", "FP", "SP"}

    DIRECTIVES = {".ORIGIN", ".ORG", ".MACRO", ".ENDMACRO"}

    # Esikäännetyt regexpit: yksi kutsu per rivityyppi (ei silmukkaa per mnemonic/rekisteri)
    _MNEMONIC_RE: re.Pattern[str] = re.compile(
        r"\b(" + "|".join(sorted(MNEMONICS, key=len, reverse=True)) + r")\b",
        re.IGNORECASE,
    )
    _REGISTER_RE: re.Pattern[str] = re.compile(
        r"\b(" + "|".join(sorted(REGISTERS, key=len, reverse=True)) + r")\b",
        re.IGNORECASE,
    )
    _NUMBER_RE: re.Pattern[str] = re.compile(
        r"(0x[0-9A-Fa-f]+|#?0x[0-9A-Fa-f]+|#\d+|\$[0-9A-Fa-f]+|\b\d+\b)"
    )
    _DIRECTIVE_RE: re.Pattern[str] = re.compile(
        r"\.(origin|org|macro|endmacro)\b", re.IGNORECASE
    )

    @staticmethod
    def highlight_line(line: str) -> str:
        """Väritä yksi assembly-rivi Rich-muodossa.

        Metodi käsittelee rivin seuraavassa järjestyksessä:

        1. **Kommentit**: Jos rivi sisältää puolipisteen (``;``),
           kaikki sen jälkeen merkitään himmennetyksi
           (``[dim]...[/dim]``).
        2. **Labelit**: Jos rivin sisältö (ilman sisennystä) päättyy
           kaksoispisteeseen, se on label ja renderöidään valkoisella
           lihavoinnilla.
        3. **Mnemonicit**: Käskysanat korostetaan keltaisella
           lihavoinnilla (regex sanarajoineen, case-insensitive).
        4. **Rekisterit**: Rekisterinimet korostetaan syaanilla.
        5. **Numerot**: Heksadesimaalit (``0xFF``), desimaalit,
           ``#``-prefiksoidut numerot ja ``$``-prefiksoidut
           heksadesimaalit korostetaan vihreällä.
        6. **Direktiivit**: ``.origin``, ``.org``, ``.macro``,
           ``.endmacro`` korostetaan magentalla lihavoinnilla.

        Parameters
        ----------
        line : str
            Yksi assembly-lähdekoodirivi (ilman rivinvaihtoa).

        Returns
        -------
        str
            Rivi Rich-markup-tageilla varustettuna, valmis
            Rich-konsolin tai -paneelin renderöitäväksi.
        """
        if ";" in line:
            code, comment = line.split(";", 1)
            comment = f"[dim];{comment}[/dim]"
        else:
            code = line
            comment = ""

        # Labelit (rivi päättyy kaksoispisteeseen)
        stripped = code.strip()
        if stripped.endswith(":"):
            label = stripped[:-1]
            indent = code[:len(code) - len(code.lstrip())]
            return f"{indent}[bold white]{label}[/bold white]:" + comment

        # Mnemonicit
        code = AssemblySyntaxHighlighter._MNEMONIC_RE.sub(
            lambda m: f"[bold yellow]{m.group().upper()}[/bold yellow]", code
        )

        # Rekisterit
        code = AssemblySyntaxHighlighter._REGISTER_RE.sub(
            lambda m: f"[cyan]{m.group().upper()}[/cyan]", code
        )

        # Numerot (hex, decimal, $ prefix)
        code = AssemblySyntaxHighlighter._NUMBER_RE.sub(r"[green]\1[/green]", code)

        # Direktiivit
        code = AssemblySyntaxHighlighter._DIRECTIVE_RE.sub(
            r"[bold magenta].\1[/bold magenta]", code
        )

        return code + comment


class SimpleEditor:
    """Yksinkertainen tekstieditori-luokka CLI/REPL-käyttöön.

    Ylläpitää yhtä avointa tiedostoa muistissa ja tarjoaa metodit
    sen lataamiseen, tallentamiseen ja renderöintiin syntaksivärein.

    TUI:ssa (``tui.py``) tämä luokka ei ole käytössä, koska siellä
    editointi tapahtuu Textualin ``TextArea``-widgetissä. Tätä luokkaa
    käytetään CLI-pohjaisessa REPL-tilassa.

    Attributes
    ----------
    content : str
        Editorin nykyinen tekstisisältö yhtenä merkkijonona.
        Rivit erotetaan ``\\n``-merkillä.
    filename : Path | None
        Viimeksi ladatun tai tallennetun tiedoston polku.
        ``None`` jos tiedostoa ei ole vielä avattu tai tallennettu.
    """

    def __init__(self) -> None:
        """Alusta tyhjä editori ilman avattua tiedostoa."""
        self.content = ""
        self.filename: Optional[Path] = None

    def load_file(self, path: Path) -> None:
        """Lataa tiedoston sisältö editoriin.

        Parameters
        ----------
        path : Path
            Ladattavan assembly-tiedoston polku. Tiedosto luetaan
            UTF-8-koodauksella.
        """
        self.content = path.read_text(encoding="utf-8")
        self.filename = path

    def save_file(self, path: Optional[Path] = None) -> None:
        """Tallenna editorin sisältö tiedostoon.

        Jos ``path`` annetaan, se tulee uudeksi oletustiedostonimeksi.
        Muuten käytetään viimeksi asetettua ``self.filename``-polkua.
        Jos kumpikaan ei ole asetettu, tallennus ohitetaan hiljaisesti.

        Parameters
        ----------
        path : Path | None
            Tallennuskohde. Jos ``None``, käytetään aiemmin asetettua
            tiedostonimeä.
        """
        if path:
            self.filename = path
        if self.filename:
            self.filename.write_text(self.content, encoding="utf-8")

    def get_content(self) -> str:
        """Palauta editorin nykyinen tekstisisältö."""
        return self.content

    def set_content(self, content: str) -> None:
        """Aseta editorin tekstisisältö.

        Parameters
        ----------
        content : str
            Uusi tekstisisältö, joka korvaa edellisen kokonaan.
        """
        self.content = content

    def render_highlighted(self, max_lines: int = 100, highlight_line: int = -1) -> str:
        """Renderoi editorin sisältö syntaksivärein Rich-muodossa.

        Jokainen rivi saa rivinumeron vasempaan laitaan. Rivinumerot
        ovat 1-pohjaisia. Jos ``highlight_line`` osoittaa johonkin
        riviin, kyseinen rivi korostetaan vihreällä taustalla
        (``[on dark_green]``) -- tätä käytetään näyttämään CPU:n
        nykyinen suoritusrivi CLI-tilassa.

        Parameters
        ----------
        max_lines : int
            Näytettävien rivien enimmäismäärä (oletus 100).
            Ylimääräiset rivit jätetään pois.
        highlight_line : int
            Korostettavan rivin numero (1-pohjainen). Arvo ``-1``
            (oletus) tarkoittaa, ettei mitään riviä korosteta.
            Tyypillisesti tähän asetetaan CPU:n PC:tä vastaava
            lähdekoodirivi, jolloin käyttäjä näkee missä suoritus on.

        Returns
        -------
        str
            Moniriviset Rich-merkintämerkkijono, jossa jokainen
            rivi on muotoa ``"  42 LOAD R0, #10"`` Rich-tageilla
            väritettynä.
        """
        lines = self.content.split("\n")
        output = []
        for i, line in enumerate(lines[:max_lines], 1):
            colored = AssemblySyntaxHighlighter.highlight_line(line)
            if i == highlight_line:
                output.append(f"[on dark_green][bold]>{i:4d}[/bold] {colored}[/on dark_green]")
            else:
                output.append(f"[dim]{i:4d}[/dim] {colored}")
        return "\n".join(output)
