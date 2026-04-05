# kCPU16 TUI-debuggeri

TUI (Text User Interface) on kCPU16:n interaktiivinen Textual-pohjainen käyttöliittymä.
Se on inspiroitu MARS/RARS-, GDB TUI-, Turbo Debugger- ja emu8086-ohjelmistoista.

---

# 1. Asettelu

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Toolbar                                                                 │
├──────────────┬──────────────────────┬──────────────────────────────────┤
│ Screen       │ Disassembly          │ Editor                           │
│ (80×24 VRAM) │ [Disassembly|        │                                  │
│              │  Memory|Stack]       │                                  │
├──────────────┴──────────────────────┤                                  │
│ Output                              │                                  │
│                                     │                                  │
├─────────────────────────────────────┼──────────────────┬───────────────┤
│ Input                               │ Flags            │ Registers     │
└─────────────────────────────────────┴──────────────────┴───────────────┘
```

---

# 2. Paneelien kuvaukset

## Toolbar
Pikavalinnat tärkeimmille toiminnoille. Vie koko terminaalin leveyden.
Ei reunusta, kiinteä korkeus.

## Screen
Näyttää 80×24 VRAM-sisällön. Kiinteän kokoinen, ei skrollattava.
Reunus ympärillä.

## Disassembly
Kolme välilehteä:
- **Disassembly** — muistin sisältö assembly-listauksenä; nykyinen PC merkitty `▶`-symbolilla, breakpointit `●`-symbolilla
- **Memory** — muistin sisältö hex-dumpina (8 sanaa/rivi + ASCII)
- **Stack** — pinon sisältö SP:stä ylöspäin

Ikkunan korkeus säätyy automaattisesti, sisältö skrollautuu pystysuunnassa.

## Output
Komentojen tulosteet ja lokitiedot. Yhtä leveä kuin Screen- ja Disassembly-ikkunat yhteensä.
Sisältö skrollautuu pystysuunnassa.

## Input
Komentorivikehote (`>`). Sijaitsee terminaalin alareunassa.
Kiinteästi yksi rivi korkea, ei reunusta.

## Flags
Prosessorin tilarekisterin liput (Z/N/C/V/I/P) ja CPU:n tila (READY / HALTED / EXITED / RUNNING).
Muuttuneet rekisteriarvot korostetaan punaisella.
Kiinteä koko, ei skrollattava.

## Registers
Kaikkien rekisterien arvot (R0–R3, FP, SP, PC, SR, MPR, TMR).
Kiinteä koko, ei skrollattava.
Flags- ja Registers-ikkunat ovat yhteensä yhtä leveitä kuin Editor-ikkuna.

## Editor
Muokattava assembly-koodieditori rivinumeroin ja syntaksivärityksin.
Täyttää terminaalista jäljelle jäävän tilan.
Sisältö skrollautuu pystysuunnassa.

---

# 3. Näppäinsidonnaisuudet

| Näppäin  | Toiminto                             |
| -------- | ------------------------------------ |
| F1       | Ohje                                 |
| F2       | Vaihda breakpoint nykyisellä rivillä |
| F5       | Run (pysähtyy breakpointiin)         |
| F7 / F10 | Step (1 käsky kerrallaan)            |
| F9       | Tyhjennä VRAM                        |
| Ctrl+B   | Assembloi koodi                      |
| Ctrl+O   | Avaa tiedosto                        |
| Ctrl+S   | Tallenna tiedosto                    |
| Ctrl+R   | Reset kone                           |
| Ctrl+Q   | Lopeta                               |

---

# 4. Komentotulkki

TUI:n syöttökentästä (`>`) voidaan antaa seuraavat komennot:

| Komento                       | Kuvaus                                       |
| ----------------------------- | -------------------------------------------- |
| `step` / `s`                  | Suorita yksi käsky                           |
| `run` / `r`                   | Aja ohjelmaa (pysähtyy breakpointiin/HALT)   |
| `stop`                        | Keskeytä ajaminen                            |
| `reset`                       | Nollaa kone                                  |
| `restart`                     | Kääntää koodin uudelleen ja nollaa koneen    |
| `asm`                         | Käännä editorin koodi (= Ctrl+B)             |
| `check`                       | Tarkista syntaksi ilman lataamista           |
| `bp <addr>`                   | Lisää/poista breakpoint osoitteessa          |
| `mem <addr>`                  | Näytä muisti osoitteesta                     |
| `mset <addr> <val>`           | Kirjoita arvo muistiosoitteeseen             |
| `mfill <addr> <count> <val>`  | Täytä muistialue vakioarvolla                |
| `disk <block>`                | Näytä tallennuslaitteen blokki               |
| `dset <block> <offset> <val>` | Kirjoita arvo blokkiin                       |
| `dfill <block> <val>`         | Täytä koko blokki vakioarvolla               |
| `mem2disk <addr> <block>`     | Kopioi muistista yhden blokin verran levylle |
| `disk2mem <block> <addr>`     | Kopioi levyblokki muistiin                   |
| `load <tiedosto>`             | Lataa .asm-tiedosto editoriin                |
| `save <tiedosto>`             | Tallenna editorin sisältö tiedostoon         |
| `cls`                         | Tyhjennä VRAM-näyttö                         |
| `spec`                        | Näytä arkkitehtuurispesifikaatio             |
| `help`                        | Näytä komentojen ohjeet                      |

---

# 5. Käynnistys

```bash
# Käynnistä TUI
python main.py

# Lataa .asm-tiedosto suoraan avattuna
python main.py kcpu16/code/fibonacci.asm

# Lataa .dsk-levykuva tallennuslaitteeseen
python main.py --dsk levykuva.dsk
```
