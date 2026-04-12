# kCPU16 Projektin Rakenne

Tämä dokumentti kuvaa projektin tiedosto- ja hakemistorakenteen sekä jokaisen
komponentin tarkoituksen.

## Yleiskuva

kCPU16 on 16-bittinen virtuaalinen prosessori (emulaattori), joka perustuu
von Neumann -arkkitehtuuriin. Projekti sisältää:

- **CPU-emulaattorin** — rekisterit, muisti, käskyjen suoritus (Fetch-Decode-Execute)
- **Assemblerin** — kolmipassinen (makrotuki, .origin-direktiivi, .diskblock-direktiivi)
- **Disassemblerin** — konekielestä luettavaan muotoon
- **Virtuaaliset laitteet** — näyttö (80×24, FG/BG-värit, bold), näppäimistö, tallennuslaite
- **Debuggeri-TUI** — ammattimainen Textual-pohjainen käyttöliittymä (MARS/GDB TUI -inspiroitu)
- **CLI** — komentorivi

---

## Hakemistorakenne

```
kCPU16/
├── main.py                      # Ohjelman aloituspiste → kcpu16.cli:main()
├── README.md                    # Projektin yleiskuvaus ja käyttöohjeet
├── docs/
│   ├── architecture.md          # CPU-arkkitehtuurispesifikaatio
│   ├── assembler.md             # Assembly-kielen syntaksi ja direktiivit
│   ├── tui.md                   # TUI-debuggerin käyttöohje
│   ├── project_structure.md     # Tämä tiedosto
│   └── suunnitelmat/            # Selvitykset ja suunnitelmat (ei nykytila)
│       ├── basic.md             # Suunnitelma BASIC-tulkin toteuttamiseksi
│       └── grafiikkatila.md     # Selvitys grafiikkatilasta Textual-kirjaston rajoissa
│
├── kcpu16/                      # Päämoduuli — kaikki logiikka
│   ├── __init__.py              # Paketin alustus, vie KCPU16Machine-luokan
│   ├── constants.py             # Vakiot: muistiosoitteet, keskeytykset, liput, värit
│   ├── exceptions.py            # Virheluokat (InvalidOpcode, MemoryFault jne.)
│   ├── instruction.py           # Käskyjen metatiedot ja opcode-taulukko
│   ├── registers.py             # Rekisteritiedosto (R0-R3, SP, FP, PC, SR, MPR, TMR)
│   ├── memory.py                # Muistimalli (65536 sanaa, suojaustarkistukset)
│   ├── hardware/                # Laiterakenteen mukainen ydin
│   │   ├── cpu.py               # CPU-ydin: Fetch-Decode-Execute -sykli
│   │   ├── memory.py            # Muistimalli (65536 sanaa, suojaustarkistukset)
│   │   ├── registers.py         # Rekisteritiedosto (R0-R15, SP, FP, PC, SR, MPR, TMR)
│   │   ├── machine.py           # Korkeantason konewrapper (CPU + laitteet yhdessä)
│   │   └── devices/             # Virtuaalilaitteet
│   │       ├── __init__.py      # Vie laiteluokat (Screen, Keyboard, Storage)
│   │       ├── screen.py        # Tekstinäyttö (80×24, FG/BG-värit, Rich-renderöinti)
│   │       ├── keyboard.py      # Näppäimistöpuskuri (FIFO-jono)
│   │       └── storage.py       # Blokkipohjainen tallennuslaite (256×256 sanaa)
│   ├── cpu.py                   # Yhteensopivuuswrapper → kcpu16.hardware.cpu
│   ├── machine.py               # Yhteensopivuuswrapper → kcpu16.hardware.machine
│   ├── assembler.py             # Assembler: assembly → konekieli (3-passinen)
│   ├── disassembler.py          # Disassembler: konekieli → assembly
│   ├── debugger.py              # DebugState: breakpointit + rekisterimuutosten seuranta
│   ├── editor.py                # Assembly-editori syntaksivärityksellä (CLI/REPL)
│   ├── tui.py                   # Ammattimainen Textual TUI -debuggeri
│   ├── cli.py                   # Komentoriviliittymä (run, disasm, tui jne.)
│   ├── specs.py                 # Arkkitehtuuriraportin muotoilu CLI:lle
│   ├── testrunner.py            # Automaattinen testien suoritus (.expect_*-direktiivit)
│   │
│   ├── devices/                 # Yhteensopivuuswrapperit → kcpu16.hardware.devices
│   │
│   ├── code/                    # Esimerkkiohjelmat (.asm)
│   │   ├── hello_regs.asm
│   │   ├── fibonacci.asm
│   │   ├── factorial.asm
│   │   ├── countdown.asm
│   │   ├── stack_demo.asm
│   │   ├── screen_hello_fill.asm
│   │   ├── test_screen_colors.asm
│   │   ├── test_macros.asm
│   │   └── exit_demo.asm
│   │
│   └── test/                    # Automaattiset yksikkötestit (.asm)
│       └── test_*.asm           # 65+ testitiedostoa käskykannalle
```

---

## Tiedostojen Kuvaukset

### Juurihakemisto

| Tiedosto    | Tarkoitus                                                              |
| ----------- | ---------------------------------------------------------------------- |
| `main.py`   | Ohjelman Entry Point. Kutsuu `kcpu16.cli:main()`.                      |
| `README.md` | Projektin yleinen README: asennus, käynnistys, linkit dokumentaatioon. |

### docs/ — Dokumentaatio

| Tiedosto               | Tarkoitus                                                                    |
| ---------------------- | ---------------------------------------------------------------------------- |
| `architecture.md`      | CPU-arkkitehtuurispesifikaatio: rekisterit, muistikartta, ISA, keskeytykset. |
| `assembler.md`         | Assembly-kielen syntaksi, direktiivit, arkkitehtuurivakiot, esimerkit.       |
| `tui.md`               | TUI-debuggerin käyttöohje: asettelu, näppäinsidonnaisuudet, komennot.        |
| `project_structure.md` | Tämä dokumentti — projektin rakenne.                                         |

### docs/suunnitelmat/ — Selvitykset ja Suunnitelmat

Tämä hakemisto sisältää dokumentit, jotka eivät kuvaa projektin nykytilaa vaan
kartoittavat mahdollisia tulevia ominaisuuksia tai analysoivat toteutusvaihtoehtoja.

| Tiedosto            | Tarkoitus                                                                    |
| ------------------- | ---------------------------------------------------------------------------- |
| `basic.md`          | Suunnitelma yksinkertaisen BASIC-tulkin toteuttamiseksi kCPU16-assemblerilla. |
| `grafiikkatila.md`  | Selvitys grafiikkatilan mahdollisuuksista Textual-kirjaston rajoissa.         |

---

### kcpu16/ — Päämoduuli

#### `__init__.py` — Paketin Alustus
- Vie `KCPU16Machine`-luokan, joka on päärajapinta emulaattoriin.
- Import: `from kcpu16 import KCPU16Machine`

#### `constants.py` — Arkkitehtuurin Vakiot
Määrittää kaikki numeriset vakiot:
- **Muistivakiot**: `WORD_MASK` (0xFFFF), `MEMORY_WORDS` (65536)
- **Keskeytysvektorit**: `INT_DIV_ZERO` (0), `INT_INVALID_OPCODE` (1), `INT_STACK_OVERFLOW` (2), `INT_BREAKPOINT` (3), `INT_PRIVILEGE_VIOLATION` (4), `INT_MEMORY_ACCESS_FAULT` (5), `INT_KEYBOARD` (6), `INT_TIMER` (7), `INT_PROCESS_EXIT` (8)
- **Muistialueet**: `VRAM_START` (0xF800), `VRAM_END` (0xFF7F, 80×24), `KERNEL_STACK_START` (0xFF80), `BOOT_RAM_START` (0x0100)
- **Tilaliput**: `SR_FLAG_Z` (0), `SR_FLAG_N` (1), `SR_FLAG_C` (2), `SR_FLAG_V` (3), `SR_FLAG_I` (4), `SR_FLAG_P` (5)
- **Suoritustilat**: `MODE_KERNEL` (1), `MODE_USER` (0)
- **Värijärjestelmä**: `VRAM_FG_MASK`, `VRAM_BG_MASK`, `COLOR_BLACK`…`COLOR_WHITE`, attribuutti BOLD (bitti 14), bitti 15 varattu

#### `exceptions.py` — Poikkeusluokat
CPU:n sisäiset virheet, jotka muunnetaan keskeytyksiksi:
- `KCPU16Error` — kantaluokka
- `InvalidOpcodeError` → INT 1 (tuntematon opcode)
- `PrivilegeViolationError` → INT 4 (User ajaa Kernel-käskyä)
- `MemoryAccessFaultError` → INT 5 (User lukee suojattua muistia)
- `StackOverflowError` → INT 2 (pino ylittää MPR:n)

#### `instruction.py` — Käskyjen Metatiedot
- `DecodedInstruction` — dataluokka puretulle käskylle (mnemonic, operandit, koko, privileged)
- `OPCODE_TABLE` — sanakirja: opcode → (mnemonic, operandien_määrä, vaatiiko_kernelin)
- Käskykategoriat: tiedonsiirto (6), aritmetiikka (5), logiikka (6), pino (2), hyppykäskyt (9), keskeytykset (4), järjestelmä (5)

#### `hardware/registers.py` — Rekisteritiedosto
`RegisterFile`-dataluokka:
- **GPR**: R0, R1, R2, R3 (yleiskäyttöiset)
- **Erikois**: FP (Frame Pointer), SP (Stack Pointer, alkaa 0xFFFF), PC (Program Counter, alkaa 0x0100), SR (Status Register)
- **Järjestelmä**: MPR (Memory Protection Register), TMR (Timer Register)
- **Metodit**: `get_flag()`, `set_flag()`, `set_zn_flags()`, `set_carry_overflow()`, `in_kernel_mode`-property

#### `hardware/memory.py` — Muistimalli
`Memory`-dataluokka:
- 65536 sanaa (16-bittisiä), von Neumann -arkkitehtuuri
- `read(addr)` / `write(addr, value)` — automaattinen osoite/arvo-maskaus
- `check_user_access(addr, mpr)` — muistisuojaustarkistus (VRAM aina sallittu)
- `load_words(start, data)` — ohjelman lataus muistiin

#### `hardware/cpu.py` — CPU-ydin
`CPU`-dataluokka toteuttaa 5-vaiheisen suoritussyklin:
1. **Fetch/Decode**: `_fetch_decode()` — lue opcode + operandit muistista
2. **Privilege Check**: `_check_privilege()` — User ei saa ajaa Kernel-käskyjä
3. **Memory Check**: `_check_memory_access()` — tarkista muistiviittaukset
4. **Execute**: `_execute()` — suorita käsky (kaikki 37 käskyä)
5. **PC Update**: kasvata PC käskyn koolla

Lisäksi: keskeytysten käsittely (`_trigger_interrupt()`), pinooperaatiot (`_push()`, `_pop()`), ajastinkeskeytys (`_handle_timer_interrupt_if_needed()`).

#### `hardware/machine.py` — Korkeantason Wrapper
`KCPU16Machine`-dataluokka yhdistää komponentit:
- CPU, Memory, RegisterFile, ScreenDevice, KeyboardDevice, BlockStorageDevice
- `cold_reset()` — kylmäkäynnistys (nollaa muisti + rekisterit)
- `boot_from_storage()` — lataa bootloader sektori 0:sta
- `load_program(words)` — lataa ohjelma suoraan muistiin
- `run(max_cycles)` / `step()` — suorita ohjelmaa
- `dump_registers()` — kaikki rekisteriarvot dict:inä
- `render_screen()` / `clear_screen_memory()` — VRAM-operaatiot

#### `assembler.py` — Assembler
`Assembler`-luokka, kolmipassinen:
- **Pass 0**: `_pass0_expand_macros_and_origin()` — makrojen ekspansointi, `.origin`/`.org` direktiivin käsittely
- **Pass 1**: `_pass1_collect_labels()` — labelien keräys ja osoitteiden laskenta
- **Pass 2**: `_pass2_emit()` — lopullinen konekieli (opcodet + operandit)
- `_parse_operand()` — rekisterit (R0-SP), labelit, numeroliteraalit (42, 0xFF, 0b1010, 0o52)
- `REGISTER_TO_ID` — rekisterinimet → indeksit
- `MNEMONIC_TO_OPCODE` — käänteinen hakutaulukko
- `ARCH_SYMBOLS` — arkkitehtuurivakiot injektoidaan automaattisesti label-nimiksi

#### `disassembler.py` — Disassembler
`Disassembler`-luokka:
- `disassemble(words, start_addr)` — muuntaa konekielen luettavaksi
- Tulosformaatti: `0100: LOAD 0x0000, 0x000A`
- Tuntemattomat opcodet: `.word 0x1234`
- Lineaarinen skannaus (ei rekursiivinen)

#### `debugger.py` — Debug-tila (UUSI v1.0)
`DebugState`-dataluokka:
- `breakpoints: set[int]` — aktiivisten breakpointien muistiosoitteet
- `prev_registers: dict[str, int]` — edelliset rekisteriarvot vertailua varten
- `toggle_breakpoint(addr)` — lisää/poista breakpoint, palauttaa True jos lisättiin
- `has_breakpoint(addr)` — tarkista onko breakpoint asetettu
- `snapshot_registers(regs)` — vertaa nykyisiä edellisiin, palauttaa dict muutoksista
- `clear_breakpoints()` — poista kaikki breakpointit

Erillinen luokka, koska Textual `App`-luokalla on sisäänrakennettu `debug`-property.

#### `editor.py` — Assembly-editori
Kaksi luokkaa:

**`AssemblySyntaxHighlighter`**:
- Rich-markup-pohjainen syntaksiväritys assembly-kielelle
- Regex-korvauksia: mnemonicit (keltainen), rekisterit (sininen), numerot (vihreä), direktiivit (magenta), kommentit (dim)

**`SimpleEditor`**:
- Peruseditori CLI/REPL-käyttöön (TUI käyttää Textual TextAreaa)
- `load_file()`, `save_file()`, `render_highlighted()` (rivinumeroin + värit)

#### `tui.py` — Debuggeri-TUI (UUSI v1.0)
`KCPU16TUI(App)` — päätason Textual-sovellus (~1100 riviä):

**Layout (3 saraketta + välilehdet):**
```
┌─ Toolbar: [Open|Save|New|Assemble ^B|Step F7|Run F5|Reset ^R|BP F2|Clear F9|Help F1]
├──────────────────────┬──────────────────────┬─────────────────────────────┤
│ SOURCE EDITOR        │ DISASSEMBLY          │ REGISTERS                   │
│ (TextArea, muokatt.) │ (Static, värikood.)  │ (muuttuneet = punainen)     │
│                      │ ●=breakpoint         ├─────────────────────────────┤
│                      │ ▶=nykyinen PC        │ FLAGS  Z:0 N:0 C:0 V:0 I:0 │
│                      │                      ├─────────────────────────────┤
│                      │                      │ CPU: READY/HALTED/EXITED    │
├──────────────────────┴──────────────────────┴─────────────────────────────┤
│ [Log] [Screen] [Memory] [Stack]   <- TabbedContent                       │
├──────────────────────────────────────────────────────────────────────────┤
│ > komentosyöte                                                    Footer│
└──────────────────────────────────────────────────────────────────────────┘
```

**Ominaisuudet:**
- Muokattava koodieditori rivinumeroin (Textual TextArea)
- Reaaliaikainen disassembly-näkymä PC:n ympärillä
- Breakpoint-tuki (F2 toggle, punainen ●-merkki disassemblyssä)
- Rekisterimuutosten korostus (muuttuneet punaisella, DebugState.snapshot_registers)
- Flags-paneeli (Z/N/C/V/I/P erikseen, KERNEL/USER-moodi)
- VRAM-värinäyttö (render_with_rich_colors, 0.5s intervalli)
- Muistinäkymä (hex dump, 8 sanaa/rivi + ASCII)
- Pinonäkymä (SP:stä ylöspäin 20 sanaa)
- Editorikursorin synkronointi PC:n kanssa (addr_to_line -mapping)
- Komentotulkki (help, step, run, bp, mem, load, open, save, assemble, regs, status, spec, disasm, examples, screen)

**Näppäinsidonnaisuudet:**

| Näppäin  | Toiminto                                |
| -------- | --------------------------------------- |
| F1       | Help                                    |
| F2       | Toggle breakpoint                       |
| F5       | Run (max 10000 sykliä, pysähtyy BP:hen) |
| F7 / F10 | Step (1 käsky)                          |
| F9       | Tyhjennä VRAM                           |
| Ctrl+B   | Assemble editorin koodi                 |
| Ctrl+O   | Avaa tiedosto                           |
| Ctrl+S   | Tallenna tiedosto                       |
| Ctrl+R   | Reset kone                              |
| Ctrl+Q   | Lopeta                                  |

#### `cli.py` — Komentoriviliittymä
Toteuttaa CLI-komennot argparse:lla:
- `run <tiedosto>` — assembloi ja suorita
- `disasm <sanat>` — disassembloi konekielisanoja
- `spec` — tulosta arkkitehtuurimääritykset
- `examples [nimi] [--run]` — listaa/suorita esimerkkejä
- `repl` — interaktiivinen debuggeri-shell
- `tui` — käynnistä Textual-TUI
- `screen-clear` — tyhjennä VRAM

#### `specs.py` — Arkkitehtuuriraportti
- Tuottaa tekstipohjaisen raportin prosessorin arkkitehtuurista
- Sisältää: suoritussykli, muistiavaruus, keskeytystaulukko, muistikartta, tallennuslaitteen tiedot

---

### kcpu16/devices/ — Virtuaalilaitteet

#### `__init__.py`
Vie laiteluokat: `KeyboardDevice`, `ScreenDevice`, `BlockStorageDevice`

#### `screen.py` — Tekstinäyttö
`ScreenDevice`-dataluokka:
- 80 saraketta × 24 riviä = 1920 sanaa VRAM:ssa (0xF800–0xFF7F)
- VRAM-sanan rakenne: bitit 0–7 = ASCII-merkki, bitit 8–10 = FG-väri (0–7), bitit 11–13 = BG-väri (0–7), bitti 14 = lihavointi, bitti 15 = varattu (0)
- `render_text(memory)` — pelkkä teksti ilman värejä
- `render_with_rich_colors(memory)` — Rich-muotoiltu teksti väreillä ja attribuuteilla (TUI:n käyttöön)
- `extract_char_with_attrs(word)` — erota merkki, FG, BG ja attribuutit VRAM-sanasta

#### `keyboard.py` — Näppäimistö
`KeyboardDevice`-luokka:
- FIFO-jono näppäinpainalluksille (deque)
- `push_key(ascii)` — lisää painallus jonoon
- `pop_key()` — hae seuraava (palauttaa 0 jos tyhjä)

#### `storage.py` — Tallennuslaite
`BlockStorageDevice`-dataluokka:
- 256 blokkia × 256 sanaa = 65536 sanaa (128 KB)
- Sanaosoitus: `read_word()` / `write_word()` (DREAD/DWRITE-käskyille)
- Blokkiosoitus: `read_block()` / `write_block()` (boot-prosessille ja OS:lle)
- Alue-operaatiot: `read_range()` / `write_range()`
- Boot: sektori 0 → RAM 0x0100–0x01FF

---

### kcpu16/code/ — Esimerkkiohjelmat

| Tiedosto                 | Kuvaus                                     |
| ------------------------ | ------------------------------------------ |
| `hello_regs.asm`         | Peruslaskutoimitukset: (10+5)×3−3 = 42     |
| `countdown.asm`          | Laskuri 10→0 silmukalla (SUB + JNZ)        |
| `fibonacci.asm`          | Fibonacci-lukujen laskenta iteratiivisesti |
| `factorial.asm`          | Kertoman laskenta aliohjelmalla (CALL/RET) |
| `stack_demo.asm`         | PUSH/POP/LIFO-demonstraatio                |
| `exit_demo.asm`          | EXIT-käskyn käyttö                         |
| `screen_hello_fill.asm`  | VRAM-kirjoitus, tekstiä näytölle           |
| `test_screen_colors.asm` | FG/BG-värien testaus                       |
| `test_macros.asm`        | Makrojen käyttöesimerkki                   |

### kcpu16/test/ — Automaattiset testit

Sisältää 65+ .asm-testitiedostoa, joista jokainen testaa yhtä käskyä tai tilannetta
`.expect_reg`, `.expect_flag` ja `.expect_mem` -direktiivien avulla.

---

## Arkkitehtuurin Yleiskuva

```
                  Assembly-lähdekoodi
                         │
                         ▼
                  ┌─────────────┐
                  │  Assembler  │  3-passinen: makrot → labelit → konekieli
                  └──────┬──────┘
                         │ lista 16-bit sanoja
                         ▼
    ┌───────────────────────────────────────────────────────┐
    │                    KCPU16Machine                      │
    │                                                       │
    │  ┌─────────────────────────────────────────────────┐  │
    │  │                      CPU                        │  │
    │  │  ┌────────────┐  ┌───────────┐  ┌───────────┐  │  │
    │  │  │ Registers  │  │  Memory   │  │  Decoder  │  │  │
    │  │  │ R0-R3, FP  │  │ 64K words │  │  OPCODE   │  │  │
    │  │  │ SP, PC, SR │  │ Von Neum. │  │  TABLE    │  │  │
    │  │  │ MPR, TMR   │  │           │  │           │  │  │
    │  │  └────────────┘  └───────────┘  └───────────┘  │  │
    │  │  Fetch → Priv.Check → Mem.Check → Exec → PC++  │  │
    │  └─────────────────────────────────────────────────┘  │
    │                                                       │
    │  ┌────────────┐  ┌────────────┐  ┌────────────────┐  │
    │  │   Screen   │  │  Keyboard  │  │    Storage     │  │
    │  │ 80×24 VRAM │  │ FIFO-jono  │  │ 256×256 blokki│  │
    │  │ FG/BG värit│  │            │  │ Boot sektori 0 │  │
    │  └────────────┘  └────────────┘  └────────────────┘  │
    └───────────────────────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    ┌──────────┐  ┌──────────┐  ┌──────────────┐
    │   CLI    │  │   REPL   │  │  TUI v1.0    │
    │ run/spec │  │ step/run │  │ Debuggeri    │
    │ disasm   │  │ regs     │  │ Breakpoints  │
    │ examples │  │ load     │  │ Disassembly  │
    └──────────┘  └──────────┘  └──────────────┘
```

---

## Suoritusjärjestys

1. **Käynnistys**: `main.py` → `cli.main()`
2. **Koneen alustus**: `KCPU16Machine()` luo CPU:n, muistin ja laitteet
3. **Ohjelman lataus**: Assembler muuntaa .asm → konekieli → `load_program()` → muistiin
4. **Suoritus**: CPU ajaa Fetch-Decode-Execute -sykliä kunnes HALT, EXIT tai raja
5. **Tulos**: Rekisterit, näyttö ja muisti tarkasteltavissa

---

## Käskyjen Suorittamisen Vaiheet

```
Fetch → Privilege Check → Memory Check → Execute → PC Update
  │            │                  │            │           │
  │            │                  │            │           └→ PC += käskyn koko
  │            │                  │            └→ Suorita operaatio
  │            │                  └→ Tarkista muistiviittausten laillisuus
  │            └→ Tarkista onko User-tilalla oikeus käskyyn
  └→ Lue käsky muistista PC:n osoitteesta

Virhetilanteessa: poikkeus → _trigger_interrupt(INT_X)
  1. PUSH PC, PUSH SR
  2. P=1 (Kernel Mode), I=0 (keskeytykset pois)
  3. PC = [vektori]
```

---

## Muistikartta

```
Osoite          Koko       Käyttö
──────────────────────────────────────────────────
0x0000 - 0x0008    9 sanaa   Keskeytysvektoritaulukko (9 vektoria)
0x0009 - 0x00FF  247 sanaa   Varattu käyttöjärjestelmälle
0x0100 - 0x01FF  256 sanaa   Bootloaderin latausalue (ohjelma ladataan tähän)
0x0200 - 0xF7FF  ~61K sanaa  Vapaa RAM (käyttäjän ohjelmat ja data)
0xF800 - 0xFF7F 1920 sanaa   Video RAM (80×24 merkkiä, FG/BG-värit, bold)
0xFF80 - 0xFFFF  128 sanaa   Kernel Stack
```

---

## Värijärjestelmä (VRAM-sanan rakenne)

```
Bitti 15       : Varattu (0)
Bitti 14       : Lihavointi (1 = päällä)
Bitit 11-13    : Taustaväri BG (0–7: musta..valkoinen)
Bitit  8-10    : Edustaväri FG (0–7: musta..valkoinen)
Bitit  0-7     : ASCII-merkki (0–127)
```

---

## Käynnistys

```bash
# TUI-debuggeri (suositeltu)
python main.py tui

# REPL-debuggeri
python main.py repl

# Assembloi ja suorita tiedosto
python main.py run ohjelma.asm --cycles 10000

# Disassembloi konekielisanoja
python main.py disasm 0x0001 0x0000 0x002A

# Listaa esimerkit
python main.py examples

# Aja esimerkki
python main.py examples hello_regs --run

# Tulosta arkkitehtuurimääritykset
python main.py spec
```

---

## Riippuvuudet

| Paketti | Versio               | Käyttö                                  |
| ------- | -------------------- | --------------------------------------- |
| Python  | ≥ 3.10               | Kielivaatimus (match/case, type unions) |
| textual | 8.2.1                | TUI-framework (tui.py)                  |
| rich    | (textual-riippuvuus) | Värimuotoilu logissa ja disassemblyssä  |

---

## Moduulien Riippuvuusketju

```
tui.py ─┬─ machine.py ─── cpu.py ─┬─ memory.py ── constants.py
        │                         ├─ registers.py ── constants.py
        ├─ assembler.py           ├─ instruction.py
        ├─ disassembler.py        └─ exceptions.py
        ├─ debugger.py
        └─ specs.py

cli.py ─┬─ machine.py
        ├─ assembler.py
        ├─ disassembler.py
        ├─ specs.py
        └─ tui.py (lazy import)
```
