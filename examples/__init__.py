"""Registry of built-in example programs."""

from __future__ import annotations

from pathlib import Path

_HERE = Path(__file__).parent

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
    meta = EXAMPLES.get(name)
    if meta is None:
        raise KeyError(f"Unknown example: '{name}'. Try 'examples list'.")
    return (_HERE / meta["file"]).read_text(encoding="utf-8")


def list_examples() -> list[tuple[str, str]]:
    return [(name, meta["description"]) for name, meta in EXAMPLES.items()]
