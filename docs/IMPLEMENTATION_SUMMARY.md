# kCPU16 — Toteutushistoria ja Päivitysloki

## Versio 1.0 (2026-04-02)

### Yleiskatsaus

kCPU16 v1.0 on täysimittainen 16-bittinen CPU-emulaattori ammattimaisella
debuggeri-käyttöliittymällä. Kaikki pääkomponentit ovat toteutettu ja dokumentoitu.

### Arkkitehtuuri

```
Assembly  →  Assembler (3-pass)  →  Konekieli  →  Memory
                                                     │
                                              CPU (F-D-E sykli)
                                                     │
                                              TUI / CLI / REPL
```

### Komponentit

| Komponentti | Tiedosto | Rivejä | Tila |
|-------------|----------|--------|------|
| CPU-ydin | cpu.py | ~780 | Valmis |
| Muistimalli | memory.py | ~150 | Valmis |
| Rekisterit | registers.py | ~190 | Valmis |
| Käskytaulukko | instruction.py | ~150 | Valmis |
| Assembler | assembler.py | ~330 | Valmis (3-passinen, makrotuki) |
| Disassembler | disassembler.py | ~110 | Valmis |
| Konewrapper | machine.py | ~220 | Valmis |
| Debug-tila | debugger.py | ~60 | Valmis (breakpointit, reg-seuranta) |
| **TUI-debuggeri** | **tui.py** | **~1100** | **Valmis (v1.0 redesign)** |
| Editori | editor.py | ~100 | Valmis (CLI/REPL-käyttöön) |
| CLI | cli.py | ~380 | Valmis |
| Vakiot | constants.py | ~150 | Valmis (värijärjestelmä) |
| Poikkeukset | exceptions.py | ~70 | Valmis |
| Speksiraportti | specs.py | ~220 | Valmis |
| Näyttölaite | devices/screen.py | ~230 | Valmis (FG/BG-värit, Rich) |
| Näppäimistö | devices/keyboard.py | ~80 | Valmis |
| Tallennuslaite | devices/storage.py | ~270 | Valmis |
| Esimerkit | examples/ | 7 .asm | Valmis |

### v1.0 — TUI-uudistus (Debuggeri-redesign)

Aiempi TUI (v0.x) oli yksinkertainen 3-osainen layout (Editor | Screen | Registers).
v1.0 uudistus toi ammattilaistason debuggeriominaisuudet, inspiroituna MARS/RARS,
GDB TUI, Turbo Debugger ja emu8086 -ohjelmistoista.

**Uudet tiedostot:**
- `kcpu16/debugger.py` — DebugState-luokka breakpointeille ja rekisterimuutosten seurannalle

**Merkittävät muutokset:**
- `kcpu16/tui.py` — Täysi uudelleenkirjoitus (~1100 riviä):
  - 3-sarakelayout: Source Editor | Disassembly | Registers+Flags+CPU
  - TabbedContent-välilehdet: Log | Screen | Memory | Stack
  - Reaaliaikainen disassembly-näkymä PC:n ympärillä
  - Breakpoint-tuki (F2, `bp <addr>`, punaiset ●-markerit)
  - Rekisterimuutosten korostus punaisella
  - Flags-paneeli (Z/N/C/V/I/P erikseen, KERNEL/USER-moodi)
  - VRAM-värinäyttö (render_with_rich_colors)
  - Muistinäkymä (hex dump + ASCII)
  - Pinonäkymä (SP:stä ylöspäin)
  - Editorikursorin synkronointi PC:n kanssa
  - Komentotulkki 15+ komennolla

**Näppäinsidonnaisuudet:**

| Näppäin | Toiminto |
|---------|----------|
| F1 | Help |
| F2 | Toggle breakpoint |
| F5 | Run (pysähtyy breakpointiin) |
| F7 / F10 | Step (1 käsky) |
| F9 | Tyhjennä VRAM |
| Ctrl+B | Assemble koodi |
| Ctrl+O | Avaa tiedosto |
| Ctrl+S | Tallenna tiedosto |
| Ctrl+R | Reset kone |
| Ctrl+Q | Lopeta |

### Aiemmat muutokset (pre-v1.0)

#### Värijärjestelmä
- VRAM-sanan rakenne: merkki (8 bit) + attribuutit (5 bit) + FG (3 bit) + BG (1 bit)
- `render_with_rich_colors()` — Rich-muotoiltu renderöinti TUI:lle
- 8 FG-väriä (COLOR_BLACK…COLOR_WHITE), 2 BG-väriä
- Attribuutit: BOLD, ITALIC, BLINK, UNDERLINE, STRIKETHROUGH

#### Makrotuki assembleriin
- `.origin OSOITE` — ohjelman aloitusosoitteen asetus
- `.macro NIMI ... .endmacro` — makrojen määrittely ja ekspansointi
- 3-passinen prosessi: Pass 0 (makrot) → Pass 1 (labelit) → Pass 2 (emit)

#### Näyttö 80×25
- SCREEN_ROWS: 24 → 25
- VRAM_WORDS: 1920 → 2000
- VRAM_END: 0xFF7F → 0xFFCF
- KERNEL_STACK_START: 0xFF80 → 0xFFD0

#### Assembly-editori
- `AssemblySyntaxHighlighter` — Rich-muotoinen syntaksiväritys
- `SimpleEditor` — peruseditori CLI/REPL-käyttöön

### Muistikartta

```
0x0000 - 0x0008   Keskeytysvektorit (9 kpl)
0x0009 - 0x00FF   OS:lle varattu
0x0100 - 0x01FF   Bootloader (256 sanaa)
0x0200 - 0xF7FF   Vapaa RAM
0xF800 - 0xFFCF   Video RAM (80×25 = 2000 sanaa)
0xFFD0 - 0xFFFF   Kernel Stack (48 sanaa)
```

### Teknisiä huomioita

- `self.dbg` (ei `self.debug`) koska Textual `App`-luokalla on sisäänrakennettu `debug`-property
- `_build_addr_to_line()` mappaa PC-osoitteet alkuperäisiin lähdekoodiriveihin (makrotuki)
- RichLog vaatii `markup=True` Rich-markup-renderöintiin
- TextArea: `language=None` (ei tree-sitter-tukea assembly-kielelle)
- Screen-renderöinti: `render_with_rich_colors()`, 0.5s intervallilla
- Breakpoint-näkyvyys disassemblyssä: sekä `.word 0x0000`-suodatin että backward-scan huomioivat breakpointit

### Käynnistys

```bash
# TUI-debuggeri (suositeltu)
python main.py tui

# REPL
python main.py repl

# Assembloi ja aja
python main.py run ohjelma.asm

# Esimerkit
python main.py examples hello_regs --run
```
