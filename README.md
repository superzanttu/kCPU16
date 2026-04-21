# kCPU16 — 16-bittinen CPU-emulaattori (Python)

kCPU16 on täysimittainen 16-bittinen CPU-emulaattori, jossa on tekstipohjainen käyttöliittymä.
Projekti sisältää oman assembly-kielen, assemblerin, disassemblerin, virtuaalikoneen sekä
interaktiivisen Textual-pohjaisen käyttöliittymän.

Projektin koodista vähintään 99.999% on kirjoittanut Github Copilot.

## Ominaisuudet

- **CPU-ydin** — Fetch → Privilege Check → Memory Check → Execute → PC Update -sykli
- **16-bittinen sana-osoitettu muisti** — 65 536 sanaa (0x0000–0xFFFF)
- **Rekisterit** — R0–R3 (GPR), FP, SP, PC, SR, MPR, TMR
- **Tilarekisteri (SR)** — liput Z, N, C, V, I, P (Zero / Negative / Carry / Overflow / Interrupt / Privilege)
- **Käskykanta** — 45 käskyä (tiedonsiirto, aritmetiikka, logiikka, pino, hyppykäskyt, keskeytykset, järjestelmä)
- **Kolmipassinen assembler** — makrotuki (`.macro`/`.endmacro`), `.origin`-direktiivi, labelit
- **Disassembler** — konekieli → assembly-teksti
- **Muistisuojaus** — MPR-rekisteri rajoittaa User-tilan muistinkäyttöä
- **Keskeytykset** — 9 vektoria (INT 0–8), ohjelmallinen INT-käsky ja laitteistokeskeytykset
- **Virtuaalinen tekstinäyttö** — 80 × 24 merkkiä, 8 edustusväriä (FG) + 8 taustaVäriä (BG), bold
- **Näppäimistölaite** — MMIO-luku osoitteista `KBD_DATA` ($0020) ja `KBD_STATUS` ($0021)
- **Tallennuslaite** — lohkopohjainen levylaite (DREAD/DWRITE, boot-lataus sektorilta 0)
- **TUI-debuggeri** — Textual-pohjainen, ammattitason käyttöliittymä
- **CLI** — komentorivi (`python main.py`)

## Projektihakemisto

```
kCPU16/
├── main.py
├── kcpu16/
│   ├── hardware/
│   │   ├── cpu.py, memory.py, registers.py, machine.py
│   │   └── devices/
│   │       ├── screen.py, keyboard.py, storage.py
│   ├── assembler.py, disassembler.py
│   ├── tui.py, cli.py, debugger.py, editor.py, specs.py
│   ├── constants.py, exceptions.py, instruction.py, testrunner.py
│   ├── cpu.py, memory.py, registers.py, machine.py     # yhteensopivuuswrapperit
│   ├── devices/                                         # yhteensopivuuswrapperit
│   ├── code/         # Esimerkkiohjelmat (.asm)
│   └── test/         # Automaattiset testit (.asm)
└── docs/
    ├── architecture.md
    ├── assembler.md
    ├── tui.md
    └── PROJECT_STRUCTURE.md
```

## Käynnistys

### Riippuvuudet

```bash
pip install textual
```

### TUI-käyttöliittymä (suositeltu)

```bash
python main.py
```

### Lataa .asm-tiedosto TUI:hin käynnistettäessä

```bash
python main.py kcpu16/code/fibonacci.asm
```

### Lataa .dsk-levykuva tallennuslaitteeseen

```bash
python main.py --dsk levykuva.dsk
```

### Tarkista assembly-tiedoston syntaksi

```bash
python main.py --check ohjelma.asm
```

## Dokumentaatio

| Tiedosto                                               | Sisältö                                                                     |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| [docs/architecture.md](docs/architecture.md)           | CPU-arkkitehtuurispesifikaatio: rekisterit, muistikartta, ISA, keskeytykset |
| [docs/assembler.md](docs/assembler.md)                 | Assembly-kielen syntaksi, direktiivit, arkkitehtuurivakiot, esimerkit       |
| [docs/tui.md](docs/tui.md)                             | TUI-debuggerin asettelu, näppäinsidonnaisuudet ja komennot                  |
| [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) | Projektin hakemistorakenne ja moduulien kuvaukset                           |
| [doc/grafiikkatila.md](doc/grafiikkatila.md)           | Grafiikkatila: Textual-kirjaston mahdollisuudet ja suositeltu toteutus      |

## Esimerkkiohjelmat

| Tiedosto                   | Kuvaus                                                     |
| -------------------------- | ---------------------------------------------------------- |
| `tut_arithmetic.asm`       | Peruslaskutoimitukset: (10+5)×3−3 = 42, kirjoitus VRAM:iin |
| `tut_loop_countdown.asm`   | Silmukka ja laskuri alaspäin                               |
| `tut_stack.asm`            | Pinokäskyjen demonstraatio (PUSH/POP/CALL/RET)             |
| `tut_macros.asm`           | Makrojen käyttöesimerkki                                   |
| `tut_vram_write.asm`       | Suora VRAM-kirjoitus, värit ja attribuutit                 |
| `tut_vram_fill.asm`        | Tekstin täyttö koko näytölle VRAM:n kautta                 |
| `tut_conditionals.asm`     | Ehdolliset hypyt (JZ/JNZ/JLT/JGT/JLE/JGE)                  |
| `tut_bitops.asm`           | Bittioperaatiot (AND/OR/XOR/NOT/SHL/SHR)                   |
| `algo_factorial.asm`       | Kertoman laskenta aliohjelmalla (CALL/RET)                 |
| `algo_fibonacci.asm`       | Fibonacci-lukujen laskenta iteratiivisesti                 |
| `algo_gcd.asm`             | Eukleideen GCD-algoritmi                                   |
| `demo_clock_text.asm`      | Päivämäärä + kellonaika tekstimuodossa                     |
| `demo_clock_bigfont.asm`   | Iso pikselikello BIG-fontilla                              |
| `demo_colors.asm`          | FG/BG-väriyhdistelmien visualisointi                       |
| `demo_keyboard.asm`        | Interaktiivinen näppäimistödemo (INT 6)                    |
| `demo_interrupt_timer.asm` | Ajastin- ja kellokeskeytysten demo (INT 7 + INT 9)         |
| `demo_benchmark.asm`       | Suorituskykymittaus (CPU/RAM/levy)                         |
| `lib_font_big.asm`         | BIG-fonttidata demoja varten                               |

### Suositeltu opintopolku (ajettava)

Suorita ohjelmat tässä järjestyksessä:

1. `python main.py kcpu16/code/tut_arithmetic.asm`
2. `python main.py kcpu16/code/tut_loop_countdown.asm`
3. `python main.py kcpu16/code/tut_stack.asm`
4. `python main.py kcpu16/code/tut_macros.asm`
5. `python main.py kcpu16/code/tut_vram_write.asm`
6. `python main.py kcpu16/code/tut_vram_fill.asm`
7. `python main.py kcpu16/code/tut_conditionals.asm`
8. `python main.py kcpu16/code/tut_bitops.asm`
9. `python main.py kcpu16/code/algo_factorial.asm`
10. `python main.py kcpu16/code/algo_fibonacci.asm`
11. `python main.py kcpu16/code/algo_gcd.asm`
12. `python main.py kcpu16/code/demo_colors.asm`
13. `python main.py kcpu16/code/demo_clock_text.asm`
14. `python main.py kcpu16/code/demo_clock_bigfont.asm`
15. `python main.py kcpu16/code/demo_interrupt_timer.asm`
16. `python main.py kcpu16/code/demo_keyboard.asm`
17. `python main.py kcpu16/code/demo_benchmark.asm`

Vinkki: voit tarkistaa syntaksin ilman ajoa komennolla `python main.py --check kcpu16/code/tiedosto.asm`.

## Lisenssi

Katso [LICENSE](LICENSE).
