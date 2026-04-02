"""
Esimerkkiohjelmien rekisteri.

Sisaltaa kaikki valmiit esimerkkiohjelmat, niiden kuvaukset
ja funktiot niiden lataamiseen.

KAYTTO:
-------
    from kcpu16.examples import get_source, list_examples

    # Listaa kaikki esimerkit
    for name, desc in list_examples():
        print(f"{name}: {desc}")

    # Lataa yksittainen esimerkki
    source = get_source("hello_regs")
    print(source)

ESIMERKIT:
----------
- hello_regs: Peruslaskutoimitukset (10+5)*3-3 = 42
- countdown: Laskuri alaspain silmukalla
- fibonacci: Fibonacci-lukujen laskenta
- factorial: Kertoman laskenta aliohjelmalla
- stack_demo: PUSH/POP-demonstraatio
- exit_demo: EXIT-kaskyn kaytto
- screen_hello_fill: Nayttoon kirjoittaminen
"""

from __future__ import annotations

from pathlib import Path

# Hakemistopolku tahan tiedostoon (examples/)
_HERE = Path(__file__).parent


# =============================================================================
# ESIMERKKIEN REKISTERI
# Jokainen esimerkki: nimi -> {description, file}
# =============================================================================

EXAMPLES: dict[str, dict[str, str]] = {
    "hello_regs": {
        "description": "Peruslaskutoimitukset: (10 + 5) * 3 - 3 = 42. Tulos: R0 = 42.",
        "file": "hello_regs.asm",
    },
    "countdown": {
        "description": "Laske alaspain 10 -> 0 silmukalla (SUB + JNZ). Tulos: R0 = 0.",
        "file": "countdown.asm",
    },
    "fibonacci": {
        "description": "Laske Fibonacci-luku F(9) = 34 iteratiivisesti. Tulos: R1 = 34.",
        "file": "fibonacci.asm",
    },
    "factorial": {
        "description": "Laske 5! = 120 aliohjelmalla (CALL/RET). Tulos: R0 = 120.",
        "file": "factorial.asm",
    },
    "stack_demo": {
        "description": "Demonstroi LIFO-pinoa (PUSH/POP). Tulos: R0=3, R1=2, R2=1.",
        "file": "stack_demo.asm",
    },
    "exit_demo": {
        "description": "Demonstroi EXIT-kaaskya: user-tilan hallittu prosessin lopetus.",
        "file": "exit_demo.asm",
    },
    "screen_hello_fill": {
        "description": "Kirjoittaa nayttomuistin tayteen toistuvaa tekstiA 'HELLO! '.",
        "file": "screen_hello_fill.asm",
    },
}


def get_source(name: str) -> str:
    """
    Lataa esimerkin lahdekoodi tiedostosta.

    Args:
        name: Esimerkin nimi (esim. "hello_regs")

    Returns:
        Assembly-lahdekoodi merkkijonona

    Raises:
        KeyError: Jos annettu nimi ei vastaa mitaan esimerkkia

    Example:
        >>> source = get_source("hello_regs")
        >>> print(source[:50])
        '; hello_regs.asm\\n; Peruslaskutoimitukset rekister'
    """
    meta = EXAMPLES.get(name)
    if meta is None:
        raise KeyError(f"Unknown example: '{name}'. Try 'examples list'.")
    # Lue tiedosto ja palauta sisalto
    return (_HERE / meta["file"]).read_text(encoding="utf-8")


def list_examples() -> list[tuple[str, str]]:
    """
    Listaa kaikki esimerkit nimiseen ja kuvauksnieen.

    Returns:
        Lista (nimi, kuvaus) -pareja

    Example:
        >>> for name, desc in list_examples():
        ...     print(f"{name}: {desc}")
        hello_regs: Peruslaskutoimitukset: (10 + 5) * 3 - 3 = 42. Tulos: R0 = 42.
        countdown: Laske alaspain 10 -> 0 silmukalla (SUB + JNZ). Tulos: R0 = 0.
        ...
    """
    return [(name, meta["description"]) for name, meta in EXAMPLES.items()]
