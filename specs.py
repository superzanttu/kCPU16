"""
Arkkitehtuuriraportin muotoilu CLI:lle.

Tama moduuli tuottaa siistin tekstipohjaisen raportin kCPU16-prosessorin
arkkitehtuurista. Raportissa kerrotaan prosessorin perusrakenne, keskeytykset,
muistikartta ja tallennuslaitteen maaritykset.

KAYTTOTAPA:
-----------
    python main.py spec

Tulostaa:
    kCPU16 maaritykset
    Prosessorin suoritussykli:
    1. Fetch
    2. Privilege Check
    ...

Tama on hyvä lähtökohta arkkitehtuurin ymmärtämiseen ilman
täyttä dokumentaatiota.
"""

from __future__ import annotations

from .constants import (
    BOOT_RAM_END,
    BOOT_RAM_START,
    INT_BREAKPOINT,
    INT_DIV_ZERO,
    INT_INVALID_OPCODE,
    INT_KEYBOARD,
    INT_MEMORY_ACCESS_FAULT,
    INT_PROCESS_EXIT,
    INT_PRIVILEGE_VIOLATION,
    INT_STACK_OVERFLOW,
    INT_TIMER,
    KERNEL_STACK_END,
    KERNEL_STACK_START,
    MEMORY_WORDS,
    VRAM_END,
    VRAM_START,
    WORD_MASK,
)
from .devices.storage import BlockStorageDevice


# =============================================================================
# KESKEYTYSTAULUKKO
# Jokainen keskeytys: (numero, vektoriosoite, kuvaus)
# =============================================================================

INTERRUPTS: list[tuple[int, int, str]] = [
    (INT_DIV_ZERO, 0x0000, "Jako nollalla (DIV jakaja = 0)"),
    (INT_INVALID_OPCODE, 0x0001, "Tuntematon kasky (Invalid Opcode)"),
    (INT_STACK_OVERFLOW, 0x0002, "Pinon ylivuoto"),
    (INT_BREAKPOINT, 0x0003, "Debug / Breakpoint"),
    (INT_PRIVILEGE_VIOLATION, 0x0004, "Privilege Violation"),
    (INT_MEMORY_ACCESS_FAULT, 0x0005, "Memory Access Fault"),
    (INT_KEYBOARD, 0x0006, "Nappaimistokeskeytys"),
    (INT_TIMER, 0x0007, "Ajastinkeskeytys"),
    (INT_PROCESS_EXIT, 0x0008, "Prosessin hallittu lopetus (EXIT)"),
]


# =============================================================================
# MUISTIKARTTA
# Jokainen alue: (alkuosoite, loppuosoite, kuvaus)
# =============================================================================

MEMORY_MAP: list[tuple[int, int, str]] = [
    (0x0000, 0x0008, "Keskeytysvektoritaulukko"),
    (0x0009, 0x00FF, "Varattu kayttojarjestelman sisaiselle kaytolle"),
    (BOOT_RAM_START, BOOT_RAM_END, "Bootloaderin latausalue"),
    (0x0200, 0xF7FF, "Vapaa RAM (OS asettaa MPR:n tanne)"),
    (VRAM_START, VRAM_END, "Video RAM (nayttomuisti, MMIO)"),
    (KERNEL_STACK_START, KERNEL_STACK_END, "Kernel Stack"),
]


def _fmt_row(columns: list[str], widths: list[int]) -> str:
    """
    Muotoile yksi taulukon rivi.

    Args:
        columns: Sarakkeiden arvot
        widths: Kunkin sarakkeen leveys

    Returns:
        Muotoiltu rivi pilkkuerottimilla
    """
    parts = []
    for value, width in zip(columns, widths):
        # Tayta valilyonneilla haluttuun leveyteen
        parts.append(value.ljust(width))
    return " | ".join(parts)


def _render_table(headers: list[str], rows: list[list[str]]) -> str:
    """
    Renderoi tekstipohjainen taulukko.

    Laskee automaattisesti sarakeleveydet sisallon mukaan
    ja muotoilee otsikot, viivan ja rivit.

    Args:
        headers: Otsikkorivin sarakkeet
        rows: Lista riveista, kukin rivi on lista sarakkeista

    Returns:
        Monirivinen merkkijono sisaltaen taulukon

    Example:
        >>> _render_table(["Nimi", "Arvo"], [["R0", "0"], ["R1", "42"]])
        'Nimi | Arvo\\n---- | ----\\nR0   | 0   \\nR1   | 42  '
    """
    # Laske minimileveydet otsikoista
    widths = [len(h) for h in headers]

    # Laajenna leveyksia jos rivien sisalto on levempaa
    for row in rows:
        for i, col in enumerate(row):
            widths[i] = max(widths[i], len(col))

    out: list[str] = []
    # Otsikkorivi
    out.append(_fmt_row(headers, widths))
    # Viivarivi (---- | ----)
    out.append(_fmt_row(["-" * w for w in widths], widths))
    # Datarivit
    for row in rows:
        out.append(_fmt_row(row, widths))

    return "\n".join(out)


def format_arch_spec_report() -> str:
    """
    Luo taysi arkkitehtuuriraportti merkkijonona.

    Raportti sisaltaa:
    1. Prosessorin suoritussyklin kuvauksen
    2. Muistiavaruuden koon
    3. Keskeytystaulukon
    4. Muistikartan
    5. Tallennuslaitteen maaritykset

    Returns:
        Monirivinen merkkijono tulostettavaksi
    """
    lines: list[str] = []

    # Luo tallennuslaitteen instanssi speksien lukemiseksi
    storage_spec = BlockStorageDevice()

    # Otsikko
    lines.append("kCPU16 maaritykset")
    lines.append("")

    # Prosessorin suoritussykli
    lines.append("Prosessorin suoritussykli:")
    lines.append("1. Fetch")
    lines.append("2. Privilege Check")
    lines.append("3. Memory Check")
    lines.append("4. Execute")
    lines.append("5. PC Update")
    lines.append("")

    # Muistiavaruus
    lines.append(f"Muistiavaruus: 0x0000 - 0x{WORD_MASK:04X} ({MEMORY_WORDS} sanaa)")
    lines.append("")

    # Keskeytystaulukko
    interrupt_rows: list[list[str]] = []
    for int_id, vector, desc in INTERRUPTS:
        interrupt_rows.append([str(int_id), f"0x{vector:04X}", desc])

    lines.append("Keskeytykset:")
    lines.append(
        _render_table(
            headers=["Nro", "Vektori", "Kuvaus"],
            rows=interrupt_rows,
        )
    )
    lines.append("")

    # Muistikartta
    map_rows: list[list[str]] = []
    for start, end, purpose in MEMORY_MAP:
        map_rows.append([f"0x{start:04X} - 0x{end:04X}", purpose])

    lines.append("Muistikartta:")
    lines.append(
        _render_table(
            headers=["Osoitealue", "Kayttotarkoitus"],
            rows=map_rows,
        )
    )
    lines.append("")

    # Tallennuslaite
    lines.append("Tallennuslaite:")
    storage_rows = [
        ["Laitetyyppi", "Blokkipohjainen (sektorit)"],
        ["Blokin koko", f"{storage_spec.block_size_words} sanaa"],
        ["Blokkien maara", str(storage_spec.block_count)],
        ["Kokonaiskapasiteetti", f"{storage_spec.total_words} sanaa"],
        [
            "Bootloaderin tallennusalue",
            "0x0000 - 0x00FF (luetaan kaynnistyksessa RAM-alueelle 0x0100 - 0x01FF)",
        ],
        ["Kaytto", "DREAD / DWRITE (kernel-tila)"],
    ]
    lines.append(
        _render_table(
            headers=["Maaraitys", "Arvo"],
            rows=storage_rows,
        )
    )

    return "\n".join(lines)
