"""
Automaattinen testin suoritus kCPU16-ohjelmille.

Lukee .asm-tiedoston, ajaa sen virtuaalikoneessa ja vertaa lopputilaa
tiedostoon kirjoitettuihin odotuksiin (.expect_*-direktiivit).

DIREKTIIVIT:
------------
Kirjoita .asm-tiedostoon ennen HALT-käskyä tai sen jälkeen:

    .expect_reg   REK, ARVO      ; Rekisterin tulee olla ARVO
    .expect_flag  LIPPU, ARVO    ; Lipun tulee olla 0 tai 1
    .expect_mem   OSOITE, ARVO   ; Muistisanan tulee olla ARVO
    .expect_storage OSOITE, ARVO ; Tallennuslaitteen sanan tulee olla ARVO

Rekisterit:   R0, R1, R2, R3, FP, SP, PC, SR
Liput:        Z, N, C, V, I, P
Osoitteet:    desimaali, 0x-hex tai 0b-binääri

ESIMERKKI:
----------
    JARI  R0, 5
    CALL  factorial
    HALT

    .expect_reg  R0, 120    ; 5! = 120
    .expect_flag Z, 0       ; tulos ei ole nolla
    .expect_flag N, 0       ; tulos ei ole negatiivinen

RAPORTTI:
---------
    ══════════════════ TEST: factorial.asm ══════════════════
    PASS  reg      R0  = 120           (got 120)
    FAIL  flag     Z   = 0             (got 1)
    ─────────────────────────────────────────────────────────
    Tulos: 1/2 läpi  ✗ FAIL
    ═════════════════════════════════════════════════════════
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

from .assembler import Assembler
from .constants import SR_FLAG_C, SR_FLAG_I, SR_FLAG_N, SR_FLAG_P, SR_FLAG_V, SR_FLAG_Z
from .machine import KCPU16Machine


# =============================================================================
# ODOTUKSEN TIETOMALLI
# =============================================================================


@dataclass
class TestExpectation:
    """Yksi odotus ohjelman lopputilalle."""

    kind: str  # "reg" | "flag" | "mem" | "storage"
    target: str  # "R0", "Z", "0x0300", "256" — aina merkkijonona
    expected: int  # Odotettu numeerinen arvo
    line_no: int  # Lähdekoodirivi (virheraportointia varten)


# SR-lipun nimestä bitti-indeksiin
_FLAG_NAME_TO_BIT: dict[str, int] = {
    "Z": SR_FLAG_Z,
    "N": SR_FLAG_N,
    "C": SR_FLAG_C,
    "V": SR_FLAG_V,
    "I": SR_FLAG_I,
    "P": SR_FLAG_P,
}

# Rekisterinimistä hakuavain
_VALID_REGS = {"R0", "R1", "R2", "R3", "FP", "SP", "PC", "SR"}


# =============================================================================
# ODOTUSTEN PARSIMINEN
# =============================================================================


def parse_expectations(source: str) -> list[TestExpectation]:
    """
    Parsii .expect_*-direktiivit lähdekoodista.

    Direktiivit voivat sijaita missä tahansa tiedostossa (myös koodin jälkeen).
    Ne eivät tuota konekieltä.

    Args:
        source: Assembly-lähdekoodi merkkijonona.

    Returns:
        Lista TestExpectation-olioita.

    Raises:
        ValueError: Jos direktiivin syntaksi on virheellinen.
    """
    expectations: list[TestExpectation] = []

    for line_no, raw_line in enumerate(source.splitlines(), 1):
        line = raw_line.split(";", 1)[0].strip()
        if not line:
            continue

        low = line.lower()

        if low.startswith(".expect_reg"):
            rest = line[len(".expect_reg") :].strip()
            reg, val = _split_two(rest, line_no)
            reg_up = reg.upper()
            if reg_up not in _VALID_REGS:
                raise ValueError(f"Rivi {line_no}: tuntematon rekisteri '{reg}'")
            expectations.append(
                TestExpectation("reg", reg_up, _parse_int(val, line_no), line_no)
            )

        elif low.startswith(".expect_flag"):
            rest = line[len(".expect_flag") :].strip()
            flag, val = _split_two(rest, line_no)
            flag_up = flag.upper()
            if flag_up not in _FLAG_NAME_TO_BIT:
                raise ValueError(
                    f"Rivi {line_no}: tuntematon lippu '{flag}'. "
                    f"Sallitut: {', '.join(_FLAG_NAME_TO_BIT)}"
                )
            ival = _parse_int(val, line_no)
            if ival not in (0, 1):
                raise ValueError(
                    f"Rivi {line_no}: lipun arvo täytyy olla 0 tai 1, saatiin {ival}"
                )
            expectations.append(TestExpectation("flag", flag_up, ival, line_no))

        elif low.startswith(".expect_storage"):
            rest = line[len(".expect_storage") :].strip()
            addr_str, val = _split_two(rest, line_no)
            expectations.append(
                TestExpectation(
                    "storage",
                    addr_str,
                    _parse_int(val, line_no),
                    line_no,
                )
            )

        elif low.startswith(".expect_mem"):
            rest = line[len(".expect_mem") :].strip()
            addr_str, val = _split_two(rest, line_no)
            expectations.append(
                TestExpectation(
                    "mem",
                    addr_str,
                    _parse_int(val, line_no),
                    line_no,
                )
            )

    return expectations


def _split_two(rest: str, line_no: int) -> tuple[str, str]:
    """Pilko 'TARGET, VALUE' kahdeksi osaksi."""
    parts = rest.replace(",", " ").split()
    if len(parts) < 2:
        raise ValueError(f"Rivi {line_no}: odotettiin 'KOHDE, ARVO', saatiin '{rest}'")
    return parts[0], parts[1]


def _parse_int(s: str, line_no: int) -> int:
    """Muunna merkkijono kokonaisluvuksi (desimaali / 0x / 0b)."""
    try:
        return int(s, 0)
    except ValueError:
        raise ValueError(f"Rivi {line_no}: '{s}' ei ole kelvollinen kokonaisluku")


# =============================================================================
# TILAN LUKEMINEN KONEESTA
# =============================================================================


def _read_actual(machine: KCPU16Machine, exp: TestExpectation) -> int:
    """Lue todellinen arvo koneesta annetun odotuksen mukaan."""
    if exp.kind == "reg":
        reg_map = {
            "R0": machine.regs.r0,
            "R1": machine.regs.r1,
            "R2": machine.regs.r2,
            "R3": machine.regs.r3,
            "FP": machine.regs.fp,
            "SP": machine.regs.sp,
            "PC": machine.regs.pc,
            "SR": machine.regs.sr,
        }
        return reg_map[exp.target]

    if exp.kind == "flag":
        bit = _FLAG_NAME_TO_BIT[exp.target]
        return machine.regs.get_flag(bit)

    if exp.kind == "mem":
        addr = int(exp.target, 0)
        return machine.memory.read(addr)

    if exp.kind == "storage":
        addr = int(exp.target, 0)
        return machine.storage.read_word(addr)

    raise ValueError(f"Tuntematon odotustyyppi: {exp.kind}")


# =============================================================================
# TESTIN SUORITUS
# =============================================================================


@dataclass
class TestResult:
    """Yhden testiodotuksen tulos."""

    expectation: TestExpectation
    actual: int
    passed: bool


def run_test(path: Path) -> int:
    """
    Suorita testiohjelma ja vertaa tulosta odotuksiin.

    Args:
        path: Polku .asm-tiedostoon.

    Returns:
        0 jos kaikki odotukset täyttyvät, 1 muuten (tai virhetilanteessa).
    """
    WIDTH = 57

    header = f" TEST: {path.name} "
    print(
        "═" * ((WIDTH - len(header)) // 2)
        + header
        + "═" * ((WIDTH - len(header) + 1) // 2)
    )

    # --- Lataa lähdekoodi ---
    if not path.exists():
        print(f"VIRHE: Tiedostoa ei löydy: {path}", file=sys.stderr)
        return 1

    source = path.read_text(encoding="utf-8")

    # --- Parsii odotukset ---
    try:
        expectations = parse_expectations(source)
    except ValueError as exc:
        print(f"VIRHE odotuksissa: {exc}", file=sys.stderr)
        return 1

    if not expectations:
        print("HUOM: Ei .expect_*-direktiivejä — ei mitään tarkistettavaa.")
        print("═" * WIDTH)
        return 0

    # --- Assembloi ---
    asm = Assembler()
    try:
        segments = asm.assemble(source)
    except Exception as exc:
        print(f"VIRHE assembloinnissa: {exc}", file=sys.stderr)
        return 1

    # --- Suorita koneessa (ilman boot-prosessia) ---
    machine = KCPU16Machine()
    machine.reset_for_test()
    machine.load_segments(segments)
    try:
        machine.run()
    except Exception as exc:
        print(f"VIRHE suorituksessa: {exc}", file=sys.stderr)
        return 1

    # --- Vertaa odotuksiin ---
    results: list[TestResult] = []
    for exp in expectations:
        try:
            actual = _read_actual(machine, exp)
            results.append(TestResult(exp, actual, actual == exp.expected))
        except Exception as exc:
            print(f"VIRHE odotuksen lukemisessa (rivi {exp.line_no}): {exc}")
            results.append(TestResult(exp, -1, False))

    # --- Tulosta raportti ---
    passed = sum(1 for r in results if r.passed)
    total = len(results)

    for r in results:
        exp = r.expectation
        status = "PASS" if r.passed else "FAIL"

        # Muotoile kohde luettavasti
        if exp.kind == "mem":
            target_str = f"mem[{exp.target}]"
        elif exp.kind == "storage":
            target_str = f"storage[{exp.target}]"
        else:
            target_str = exp.target

        expected_str = f"{exp.expected}"
        actual_str = f"{r.actual}"

        # Hex-esitys suurille arvoille
        if exp.expected > 9 or (r.actual > 9 and r.actual >= 0):
            expected_str = f"{exp.expected} (0x{exp.expected:04X})"
            actual_str = f"{r.actual} (0x{r.actual:04X})"

        line = f"{status}  {exp.kind:<8}  {target_str:<12}= {expected_str:<22} saatiin: {actual_str}"
        print(line)

    print("─" * WIDTH)
    if passed == total:
        verdict = "PASS"
        verdict_sym = "✓"
    else:
        verdict = "FAIL"
        verdict_sym = "✗"

    print(f"Tulos: {passed}/{total} läpi  {verdict_sym} {verdict}")
    print("═" * WIDTH)

    return 0 if passed == total else 1


# =============================================================================
# KAIKKIEN TESTIEN SUORITUS
# =============================================================================


def run_test_all(test_dir: Path) -> int:
    """
    Suorita kaikki .asm-testitiedostot hakemistosta ja tulosta yhteenveto.

    Args:
        test_dir: Hakemisto josta .asm-tiedostot haetaan.

    Returns:
        0 jos kaikki testit menivät läpi, 1 muuten.
    """
    WIDTH = 57

    asm_files = sorted(test_dir.glob("*.asm"))
    if not asm_files:
        print(f"VIRHE: Ei .asm-tiedostoja hakemistossa: {test_dir}", file=sys.stderr)
        return 1

    # Suorita jokainen testi ja kerää tulokset
    summary: list[tuple[str, int, int]] = []  # (nimi, passed, total)
    errors: list[str] = []  # virheelliset tiedostonimet

    for path in asm_files:
        print()  # tyhjä rivi testien väliin
        exit_code = run_test(path)
        # Lue passed/total uudelleen jotta saadaan numerot yhteenvetoon
        try:
            source = path.read_text(encoding="utf-8")
            expectations = parse_expectations(source)
            total = len(expectations)
        except Exception:
            total = 0
        passed = total if exit_code == 0 else 0
        summary.append((path.name, passed, total))
        if exit_code != 0:
            errors.append(path.name)

    # Yhteenveto
    tests_total = len(summary)
    tests_passed = sum(1 for _, p, t in summary if p == t)
    checks_passed = sum(p for _, p, _ in summary)
    checks_total = sum(t for _, _, t in summary)

    print()
    header = " YHTEENVETO "
    print(
        "═" * ((WIDTH - len(header)) // 2)
        + header
        + "═" * ((WIDTH - len(header) + 1) // 2)
    )

    col_w = max(len(n) for n, _, _ in summary)
    for name, passed, total in summary:
        if total == 0:
            status = "SKIP"
            detail = "(ei odotuksia)"
        elif passed == total:
            status = "PASS"
            detail = f"{passed}/{total}"
        else:
            status = "FAIL"
            detail = f"{passed}/{total}"
        print(f"  {status}  {name:<{col_w}}  {detail}")

    print("─" * WIDTH)
    all_ok = tests_passed == tests_total
    verdict = "PASS ✓" if all_ok else "FAIL ✗"
    print(f"Testit:     {tests_passed}/{tests_total} läpi")
    print(f"Tarkistukset: {checks_passed}/{checks_total} läpi")
    print(f"Tulos: {verdict}")
    print("═" * WIDTH)

    return 0 if all_ok else 1
