# pyright: reportMissingImports=false
"""
Assembly-editori kCPU16:lle.

Tarjoaa syntaksivärityksen ja peruseditorin toiminnallisuudet.
Integroituu TUI:hin TextArea-pohjaisen interaktiivisen editorin kautta.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional


class AssemblySyntaxHighlighter:
    """Assembly-kielen syntaksin väritys Rich-muodossa."""

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

    @staticmethod
    def highlight_line(line: str) -> str:
        """Väritä yksi assembly-rivi Rich-muodossa."""
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
        for m in AssemblySyntaxHighlighter.MNEMONICS:
            code = re.sub(r"\b" + m + r"\b", f"[bold yellow]{m}[/bold yellow]", code, flags=re.IGNORECASE)

        # Rekisterit
        for r in AssemblySyntaxHighlighter.REGISTERS:
            code = re.sub(r"\b" + r + r"\b", f"[cyan]{r}[/cyan]", code, flags=re.IGNORECASE)

        # Numerot (hex, decimal, $ prefix)
        code = re.sub(r"(0x[0-9A-Fa-f]+|#?0x[0-9A-Fa-f]+|#\d+|\$[0-9A-Fa-f]+|\b\d+\b)", r"[green]\1[/green]", code)

        # Direktiivit
        code = re.sub(r"\.(origin|org|macro|endmacro)\b", r"[bold magenta].\1[/bold magenta]", code, flags=re.IGNORECASE)

        return code + comment


class SimpleEditor:
    """Yksinkertainen tekstieditori-luokka."""

    def __init__(self) -> None:
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
        return self.content

    def set_content(self, content: str) -> None:
        self.content = content

    def render_highlighted(self, max_lines: int = 100, highlight_line: int = -1) -> str:
        """Renderoi sisältö väreillä. highlight_line = korostettava rivi (1-pohjainen)."""
        lines = self.content.split("\n")
        output = []
        for i, line in enumerate(lines[:max_lines], 1):
            colored = AssemblySyntaxHighlighter.highlight_line(line)
            if i == highlight_line:
                output.append(f"[on dark_green][bold]>{i:4d}[/bold] {colored}[/on dark_green]")
            else:
                output.append(f"[dim]{i:4d}[/dim] {colored}")
        return "\n".join(output)
