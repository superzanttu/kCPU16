"""
Yksinkertainen tekstieditori kCPU16 koodille.

Käytetään Textual-widgetillä. Tämä moduuli tarjoaa assembly-syntaksivärityksen
ja perusominaisuudet editoreille.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

from textual.widgets import Static
from textual.message import Message


class AssemblySyntaxHighlighter:
    """Assembly-kielen syntaksin väritys."""

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

    @staticmethod
    def highlight_line(line: str) -> str:
        """Väritä yksi assembly-rivi Rich-muodossa."""
        if ";" in line:
            code, comment = line.split(";", 1)
            comment = f"[dim];{comment}[/dim]"
        else:
            code = line
            comment = ""

        # Mnemonicit
        for m in AssemblySyntaxHighlighter.MNEMONICS:
            code = re.sub(r"\b" + m + r"\b", f"[yellow]{m}[/yellow]", code, flags=re.IGNORECASE)

        # Rekisterit
        for r in AssemblySyntaxHighlighter.REGISTERS:
            code = re.sub(r"\b" + r + r"\b", f"[blue]{r}[/blue]", code, flags=re.IGNORECASE)

        # Numerot
        code = re.sub(r"(0x[0-9A-Fa-f]+|#?\d+|\$[0-9A-Fa-f]+)", r"[green]\1[/green]", code)

        # Direktiivit
        code = re.sub(r"\.(origin|org|macro|endmacro)", r"[cyan].\1[/cyan]", code, flags=re.IGNORECASE)

        return code + comment


class SimpleEditor:
    """Yksinkertainen tekstieditori-luokka."""

    def __init__(self):
        self.content = ""
        self.filename: Optional[Path] = None

    def load_file(self, path: Path) -> None:
        """Lataa tiedosto."""
        self.content = path.read_text(encoding="utf-8")
        self.filename = path

    def save_file(self, path: Optional[Path] = None) -> None:
        """Tallenna tiedosto."""
        if path:
            self.filename = path
        if self.filename:
            self.filename.write_text(self.content, encoding="utf-8")

    def get_content(self) -> str:
        """Hae sisältö."""
        return self.content

    def set_content(self, content: str) -> None:
        """Aseta sisältö."""
        self.content = content

    def render_highlighted(self, max_lines: int = 50) -> str:
        """Renderoi sisältö väreillä."""
        lines = self.content.split("\n")
        output = []
        for i, line in enumerate(lines[:max_lines], 1):
            colored = AssemblySyntaxHighlighter.highlight_line(line)
            output.append(f"[dim]{i:4d}[/dim] {colored}")
        return "\n".join(output)
