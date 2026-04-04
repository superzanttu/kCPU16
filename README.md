# kCPU16 — 16-bittinen CPU-emulaattori (Python)

kCPU16 on täysimittainen 16-bittinen CPU-emulaattori, jossa on ammattitason TUI-debuggeri.
Projekti sisältää oman assembly-kielen, assemblerin, disassemblerin, virtuaalikoneen sekä
interaktiivisen Textual-pohjaisen käyttöliittymän.

## Ominaisuudet

- **CPU-ydin** — Fetch → Privilege Check → Memory Check → Execute → PC Update -sykli
- **16-bittinen sana-osoitettu muisti** — 65 536 sanaa (0x0000–0xFFFF)
- **Rekisterit** — R0–R3 (GPR), FP, SP, PC, SR, MPR, TMR
- **Tilarekisteri (SR)** — liput Z, N, C, V, I, P (Zero / Negative / Carry / Overflow / Interrupt / Privilege)
- **Käskykanta** — 44 käskyä (tiedonsiirto, aritmetiikka, logiikka, pino, hyppykäskyt, keskeytykset, järjestelmä)
- **Kolmipassinen assembler** — makrotuki (`.macro`/`.endmacro`), `.origin`-direktiivi, labelit
- **Disassembler** — konekieli → assembly-teksti
- **Muistisuojaus** — MPR-rekisteri rajoittaa User-tilan muistinkäyttöä
- **Keskeytykset** — 9 vektoria (INT 0–8), ohjelmallinen INT-käsky ja laitteistokeskeytykset
- **Virtuaalinen tekstinäyttö** — 80 × 24 merkkiä, 8 edustusväriä (FG) + 8 taustaväriä (BG), bold/blink
- **Näppäimistölaite** — KGET-käsky lukee näppäinpuskurin
- **Tallennuslaite** — lohkopohjainen levylaite (DREAD/DWRITE, boot-lataus sektorilta 0)
- **TUI-debuggeri** — Textual-pohjainen, ammattitason käyttöliittymä (ks. alla)
- **CLI** — komentorivi (`python main.py`)

## Projektihakemisto

```
kCPU16/
├── main.py                   # Entry point
├── kcpu16/
│   ├── __init__.py
│   ├── cli.py                # Komentoriviliittymä
│   ├── tui.py                # Textual TUI -debuggeri (~1100 riviä)
│   ├── machine.py            # KCPU16Machine — kokonaiskoneen wrapper
│   ├── cpu.py                # CPU-ydin (Fetch-Decode-Execute)
│   ├── memory.py             # Sana-osoitettu muisti + MPR-suojaus
│   ├── registers.py          # Rekisteritiedosto
│   ├── instruction.py        # Käskytaulukko (OPCODE_TABLE)
│   ├── assembler.py          # 3-passinen assembler
│   ├── disassembler.py       # Disassembler
│   ├── debugger.py           # DebugState — breakpointit ja rekisteriseuranta
│   ├── editor.py             # Yksinkertainen assembly-editori (CLI/REPL)
│   ├── specs.py              # Arkkitehtuuriraportti (tekstimuotoinen)
│   ├── constants.py          # Arkkitehtuurivakiot
│   ├── exceptions.py         # Emulaattoripoikkeukset
│   ├── devices/
│   │   ├── screen.py         # Virtuaalinen tekstinäyttö (VRAM)
│   │   ├── keyboard.py       # Näppäimistöpuskuri
│   │   └── storage.py        # Lohkopohjainen tallennuslaite
│   └── code/                 # Esimerkkiohjelmat (.asm)
│       ├── hello_regs.asm
│       ├── fibonacci.asm
│       ├── factorial.asm
│       ├── countdown.asm
│       ├── stack_demo.asm
│       ├── screen_hello_fill.asm
│       ├── test_screen_colors.asm
│       ├── test_macros.asm
│       └── exit_demo.asm
└── docs/
    ├── architecture.md
    ├── screenlayout.md
    ├── PROJECT_STRUCTURE.md
    └── IMPLEMENTATION_SUMMARY.md
```

## Käynnistys

### TUI-debuggeri (suositeltu)

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

### Riippuvuudet

```bash
pip install textual
```

## TUI-debuggeri

TUI on inspiroitu MARS/RARS-, GDB TUI-, Turbo Debugger- ja emu8086-ohjelmistoista.

### Layout

```
┌─ Toolbar (Open|Save|New | Assemble ^B | Step F7|Run F5|Reset ^R | BP F2)
├──────────────┬─────────────────────┬─────────────────────────────┤
│ SCREEN       │ DISASSEMBLY/MEM/STK │ SOURCE EDITOR               │
│ (80×24 VRAM) │ (TabbedContent)     │ (TextArea, muokattava)      │
│              │ ●=breakpoint        │ rivinumerot                 │
│              │ ▶=nykyinen PC       │ kursori seuraa PC:tä        │
├──────────────┴─────────────────────┤                             │
│ LOG (lokiviestit)                  │                             │
├────────────────────────────────────┤                             │
│ COMMANDS (komentotulosteet)        │                             │
├────────────────────────────────────┴─────────────────────────────┤
│ > komentosyöte      │ FLAGS Z N C V I P  │ REGISTERS             │
│                     │ CPU state/cycles   │ (muuttuneet=punainen) │
└─────────────────────┴────────────────────┴───────────────────────┘
```

### Näppäinsidonnaisuudet

| Näppäin  | Toiminto                          |
|----------|-----------------------------------|
| F1       | Ohje                              |
| F2       | Vaihda breakpoint nykyisellä rivillä |
| F5       | Run (pysähtyy breakpointiin)      |
| F7 / F10 | Step (1 käsky kerrallaan)         |
| F9       | Tyhjennä VRAM                     |
| Ctrl+B   | Assembloi koodi                   |
| Ctrl+O   | Avaa tiedosto                     |
| Ctrl+S   | Tallenna tiedosto                 |
| Ctrl+R   | Reset kone                        |
| Ctrl+Q   | Lopeta                            |

### Komentotulkki

TUI:n komentoriviltä (`>`) voidaan antaa komentoja kuten:

| Komento            | Kuvaus                                      |
|--------------------|---------------------------------------------|
| `step` / `s`       | Suorita yksi käsky                          |
| `run` / `r`        | Aja ohjelmaa (pysähtyy breakpointiin/HALT)  |
| `reset`            | Nollaa kone                                 |
| `bp <addr>`        | Lisää/poista breakpoint osoitteessa         |
| `mem <addr>`       | Näytä muisti osoitteesta                    |
| `reg`              | Tulosta rekisterit                          |
| `load <tiedosto>`  | Lataa .asm-tiedosto editoriin               |

## Käskykanta (ISA)

### Tiedonsiirtokäskyt

| Käsky           | Kuvaus                                        |
|-----------------|-----------------------------------------------|
| `LOAD reg, imm` | Lataa välitön arvo rekisteriin                |
| `CPY regD, regS`| Kopioi rekisterin arvo toiseen                |
| `READ reg, addr`| Lue muistiosoitteesta rekisteriin             |
| `STORE reg, addr`| Tallenna rekisteri muistiosoitteeseen        |
| `READ_IND regD, regS` | Lue epäsuorasti: regD ← [regS]          |
| `STORE_IND regD, regS`| Kirjoita epäsuorasti: [regD] ← regS     |
| `READ_REL reg, imm`   | Lue [FP + imm] → rekisteriin            |
| `STORE_REL reg, imm`  | Kirjoita rekisteri → [FP + imm]         |

### Aritmetiikka

| Käsky           | Kuvaus                                        |
|-----------------|-----------------------------------------------|
| `ADD regD, regS`| regD = regD + regS                            |
| `SUB regD, regS`| regD = regD − regS                            |
| `MUL regD, regS`| regD = regD × regS                            |
| `DIV regD, regS`| regD = regD / regS (INT 0 jos jakaja = 0)     |
| `CMP regA, regB`| Vertailu: asettaa liput, ei tallenna tulosta  |
| `ADC regD, regS`| regD = regD + regS + Carry                    |

### Logiikka

| Käsky           | Kuvaus                                        |
|-----------------|-----------------------------------------------|
| `AND regD, regS`| Bittitason AND                                |
| `OR  regD, regS`| Bittitason OR                                 |
| `XOR regD, regS`| Bittitason XOR                                |
| `NOT reg`       | Bittitason NOT                                |
| `SHL regD, regS`| Bittisiirto vasemmalle                        |
| `SHR regD, regS`| Bittisiirto oikealle                          |

### Pino-operaatiot

| Käsky           | Kuvaus                                        |
|-----------------|-----------------------------------------------|
| `PUSH reg`      | Tallenna rekisteri pinoon                     |
| `POP reg`       | Hae pinosta rekisteriin                       |
| `SWSP regD, regS`| regD = SP; SP = regS                         |

### Hyppykäskyt

| Käsky      | Kuvaus                                             |
|------------|----------------------------------------------------|
| `JUMP addr`| Ehdoton hyppy                                      |
| `CALL addr`| Aliohjelmakutsu (PUSH PC+koko, JUMP addr)          |
| `RET`      | Paluu aliohjelmasta (POP PC)                       |
| `JZ addr`  | Hyppy jos Z=1 (tulos oli nolla)                    |
| `JNZ addr` | Hyppy jos Z=0 (tulos ei ollut nolla)               |
| `JLT addr` | Hyppy jos N≠V (pienempi kuin, etumerkillinen)      |
| `JGT addr` | Hyppy jos Z=0 ja N=V (suurempi kuin)               |
| `JLE addr` | Hyppy jos Z=1 tai N≠V (pienempi tai yhtä suuri)    |
| `JGE addr` | Hyppy jos N=V (suurempi tai yhtä suuri)            |

### Keskeytykset ja järjestelmä

| Käsky           | Tila   | Kuvaus                                        |
|-----------------|--------|-----------------------------------------------|
| `INT imm`       | User   | Ohjelmallinen keskeytys (syscall)             |
| `IRET`          | Kernel | Paluu keskeytyksenkäsittelijästä (POP SR, PC) |
| `STI`           | Kernel | Salli keskeytykset (I=1)                      |
| `CLI`           | Kernel | Estä keskeytykset (I=0)                       |
| `HALT`          | Kernel | Pysäytä prosessori                            |
| `EXIT`          | User   | Prosessin hallittu lopetus (INT 8)            |
| `DREAD regD, regS` | Kernel | Lue lohko tallennuslaitteelta             |
| `DWRITE regS, regD`| Kernel | Kirjoita lohko tallennuslaitteelle        |
| `SMPR reg`      | Kernel | Aseta MPR (muistisuojaraja)                   |
| `STMR reg`      | Kernel | Aseta TMR (ajastinväli)                       |
| `KGET reg`      | User   | Lue näppäinpuskuri rekisteriin                |
| `TSL reg, addr` | User   | Test and Set Lock (atominen)                  |

## Muistikartta

```
0x0000 – 0x0008   Keskeytysvektorit (9 kpl, INT 0–8)
0x0009 – 0x00FF   OS:lle varattu
0x0100 – 0x01FF   Bootloader-latausalue (256 sanaa)
0x0200 – 0xF7FF   Vapaa RAM (ohjelmat ja data)
0xF800 – 0xFF7F   Video RAM, VRAM (80×24 = 1920 sanaa)
0xFF80 – 0xFFFF   Kernel Stack (128 sanaa)
```

## VRAM-sanan rakenne

Jokainen VRAM-sana on 16-bittinen:

```
Bitit  0–7:   ASCII-merkki (0–127)
Bitit  8–10:  Edustaväri, FG (3 bittiä = 8 väriä)
Bitit 11–13:  Taustaväri, BG (3 bittiä = 8 väriä)
Bitti  14:    Lihavointi (1 = päällä)
Bitti  15:    Vilkkuminen (1 = päällä)
```

Värikoodit: 0=Musta, 1=Punainen, 2=Vihreä, 3=Keltainen, 4=Sininen, 5=Magenta, 6=Syaani, 7=Valkoinen.

## Keskeytykset

| Numero | Vektori  | Kuvaus                                 |
|--------|----------|----------------------------------------|
| INT 0  | 0x0000   | Jako nollalla (DIV, jakaja = 0)        |
| INT 1  | 0x0001   | Tuntematon käsky (Invalid Opcode)      |
| INT 2  | 0x0002   | Pinon ylivuoto                         |
| INT 3  | 0x0003   | Debug / Breakpoint                     |
| INT 4  | 0x0004   | Privilege Violation                    |
| INT 5  | 0x0005   | Memory Access Fault                    |
| INT 6  | 0x0006   | Näppäimistökeskeytys                   |
| INT 7  | 0x0007   | Ajastinkeskeytys (TMR)                 |
| INT 8  | 0x0008   | Prosessin hallittu lopetus (EXIT)      |

## Assembly-syntaksi

```asm
; Kommentit alkavat puolipisteellä
.origin 0x0200        ; Ohjelman aloitusosoite

.macro INIT_REGS      ; Makron määrittely
    LOAD R0, 0
    LOAD R1, 0
.endmacro

START:                ; Label (päättyy kaksoispisteeseen)
    INIT_REGS         ; Makron käyttö
    LOAD  R0, 42      ; Lataa vakio (desimaalina)
    LOAD  R1, 0xFF    ; Lataa vakio (heksana)
    LOAD  R2, $F800   ; $ = heksaprefiksi
    ADD   R0, R1      ; Rekisterioperaatio
    STORE R0, 0x0200  ; Tallenna muistiin
    JUMP  START       ; Hyppy labeliin
    HALT
```

Rekisterit: `R0`, `R1`, `R2`, `R3`, `FP`, `SP` (kirjainkoosta riippumaton).

## Esimerkkiohjelmat

| Tiedosto                  | Kuvaus                                              |
|---------------------------|-----------------------------------------------------|
| `hello_regs.asm`          | Peruslaskutoimitukset: (10+5)×3−3 = 42, kirjoitus VRAM:iin |
| `fibonacci.asm`           | Fibonacci-lukujen laskenta iteratiivisesti          |
| `factorial.asm`           | Kertoman laskenta aliohjelmalla (CALL/RET)          |
| `countdown.asm`           | Laskulaskuri silmukalla                             |
| `stack_demo.asm`          | Pinokäskyjen demonstraatio (PUSH/POP/CALL/RET)      |
| `screen_hello_fill.asm`   | Tekstin kirjoitus näytölle VRAM:n kautta            |
| `test_screen_colors.asm`  | FG/BG-värien testaus näytöllä                       |
| `test_macros.asm`         | Makrojen käyttöesimerkki                            |
| `exit_demo.asm`           | EXIT-käskyn demonstraatio                           |

## Lisenssi

Katso [LICENSE](LICENSE).
