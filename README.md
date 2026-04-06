# kCPU16 — 16-bittinen CPU-emulaattori (Python)

kCPU16 on täysimittainen 16-bittinen CPU-emulaattori, jossa on tekstipohjainen käyttöliittymä.
Projekti sisältää oman assembly-kielen, assemblerin, disassemblerin, virtuaalikoneen sekä
interaktiivisen Textual-pohjaisen käyttöliittymän.

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
- **Virtuaalinen tekstinäyttö** — 80 × 24 merkkiä, 8 edustusväriä (FG) + 8 taustaväriä (BG), bold/blink
- **Näppäimistölaite** — KGET-käsky lukee näppäinpuskurin
- **Tallennuslaite** — lohkopohjainen levylaite (DREAD/DWRITE, boot-lataus sektorilta 0)
- **TUI-debuggeri** — Textual-pohjainen, ammattitason käyttöliittymä
- **CLI** — komentorivi (`python main.py`)

## Projektihakemisto

```
kCPU16/
├── main.py
├── kcpu16/
│   ├── cpu.py, memory.py, registers.py, machine.py
│   ├── assembler.py, disassembler.py
│   ├── tui.py, cli.py, debugger.py, editor.py, specs.py
│   ├── constants.py, exceptions.py, instruction.py, testrunner.py
│   ├── devices/
│   │   ├── screen.py, keyboard.py, storage.py
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

## Esimerkkiohjelmat

| Tiedosto                 | Kuvaus                                                     |
| ------------------------ | ---------------------------------------------------------- |
| `hello_regs.asm`         | Peruslaskutoimitukset: (10+5)×3−3 = 42, kirjoitus VRAM:iin |
| `fibonacci.asm`          | Fibonacci-lukujen laskenta iteratiivisesti                 |
| `factorial.asm`          | Kertoman laskenta aliohjelmalla (CALL/RET)                 |
| `countdown.asm`          | Laskulaskuri silmukalla                                    |
| `stack_demo.asm`         | Pinokäskyjen demonstraatio (PUSH/POP/CALL/RET)             |
| `screen_hello_fill.asm`  | Tekstin kirjoitus näytölle VRAM:n kautta                   |
| `test_screen_colors.asm` | FG/BG-värien testaus näytöllä                              |
| `test_macros.asm`        | Makrojen käyttöesimerkki                                   |
| `exit_demo.asm`          | EXIT-käskyn demonstraatio                                  |

## Lisenssi

Katso [LICENSE](LICENSE).
