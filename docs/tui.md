# kCPU16 TUI-debuggeri

TUI (Text User Interface) on kCPU16:n interaktiivinen Textual-pohjainen käyttöliittymä.
Se on inspiroitu MARS/RARS-, GDB TUI-, Turbo Debugger- ja emu8086-ohjelmistoista.

---

# 1. Asettelu

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Toolbar: Load | Assemble ^B | Step F7 | Full F5 | Slow F6 | Stop F8 | Reset ^R | BP F2 | ...    │
├────────────────────────────┬─────────────────────────────────────────────────────────────────────┤
│ Screen (80×24 VRAM)        │ [Disassembly | Memory | Stack]                                      │
│                            │ ●=breakpoint  ▶=nykyinen PC                                        │
├────────────────────────────┴─────────────────────────────────────────────────────────────────────┤
│ Flags / CPU-tila    │ Registers (R0–R15, FP, SP …)    │ Output (loki + > komentosyöte)          │
└─────────────────────┴─────────────────────────────────┴─────────────────────────────────────────┘
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

## Flags
Prosessorin tilarekisterin liput (Z/N/C/V/I/P) ja CPU:n tila (STOPPED / RUNNING / HALTED / EXITED).
Kiinteä koko, ei skrollattava.

## Registers
Kaikkien rekisterien arvot: R0–R15 (yleiskäyttöiset), FP, SP, PC, SR, MPR, TMR, CTMR.
Muuttuneet arvot korostetaan punaisella.
Kiinteä koko, ei skrollattava.

## Output
Komentojen tulosteet ja lokitiedot. Sijaitsee alarivillä Flagsin ja Registersin oikealla puolella.
Sisältö skrollautuu pystysuunnassa. Alareunassa komentorivisyöte (`>`).

---

# 3. Näppäinsidonnaisuudet

| Näppäin  | Toiminto                             |
| -------- | ------------------------------------ |
| F1       | Ohje                                 |
| F2       | Vaihda breakpoint nykyisellä rivillä |
| F5       | Aja täydellä nopeudella              |
| F6       | Aja hitaalla nopeudella              |
| F7 / F10 | Step (1 käsky kerrallaan)            |
| F8       | Pysäytä ajo                          |
| F9       | Tyhjennä VRAM                        |
| Ctrl+B   | Assembloi koodi                      |
| Ctrl+O   | Avaa tiedosto                        |
| Ctrl+R   | Reset kone                           |
| Ctrl+Q   | Lopeta                               |

---

# 4. Komentotulkki

TUI:n syöttökentästä (`>`) voidaan antaa seuraavat komennot:

| Komento                       | Kuvaus                                       |
| ----------------------------- | -------------------------------------------- |
| `step [n]`                    | Suorita 1 tai n käskyä                       |
| `run [n]`                     | Aja ohjelmaa (pysähtyy breakpointiin/HALT)   |
| `stop`                        | Keskeytä ajaminen                            |
| `reset`                       | Nollaa muisti + CPU (storage säilyy)         |
| `reset deep`                  | Nollaa muisti + CPU + storage                |
| `reset cpu`                   | Nollaa vain CPU (muisti säilyy)              |
| `restart`                     | Käännä uudelleen ja aloita alusta            |
| `asm`                         | Assembloi ladattu tiedosto (= Ctrl+B)        |
| `check`                       | Tarkista syntaksi ilman lataamista           |
| `load <tiedosto>`             | Lataa .asm-tiedosto ja assembloi             |
| `bp <addr>`                   | Lisää/poista breakpoint osoitteessa          |
| `bp list`                     | Listaa kaikki breakpointit                   |
| `bp clear`                    | Poista kaikki breakpointit                   |
| `mem <addr> [count]`          | Näytä muisti osoitteesta                     |
| `mset <addr> <val>`           | Kirjoita arvo muistiosoitteeseen             |
| `mfill <addr> <count> <val>`  | Täytä muistialue vakioarvolla                |
| `disk <block>`                | Näytä tallennuslaitteen blokki               |
| `disk load <polku>`           | Lataa .dsk-levykuva tallennuslaitteeseen     |
| `disk save [polku]`           | Tallenna tallennuslaite .dsk-tiedostoon      |
| `dset <block> <offset> <val>` | Kirjoita arvo blokkiin                       |
| `dfill <block> <val>`         | Täytä koko blokki vakioarvolla               |
| `mem2disk <addr> <block>`     | Kopioi muistista yhden blokin verran levylle |
| `disk2mem <block> <addr>`     | Kopioi levyblokki muistiin                   |
| `cls`                         | Tyhjennä VRAM-näyttö                         |
| `spec`                        | Näytä arkkitehtuurispesifikaatio             |
| `version`                     | Näytä versiotiedot                           |
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

---

# 6. Suoritustilat

Ohjelman suoritustila näytetään toolbarin oikeassa yläkulmassa. Tila päivittyy reaaliaikaisesti kaikissa näppäin- ja painike-toiminnoissa.

| Tila      | Merkki | Kuvaus                                                                                 | Miten saavutetaan                |
| --------- | ------ | -------------------------------------------------------------------------------------- | -------------------------------- |
| `STOPPED` | ■      | CPU pysähtyneenä. Muisti ja rekisterit säilyvät. Askel tai ajo mahdollinen.            | Ohjelma pysäytetty (F8 / `stop`) |
| `STEP`    | ■      | Yksi käsky suoritettu. CPU odottaa seuraavaa komentoa.                                 | F7 / F10 tai `step`-komento      |
| `FULL`    | ▶      | CPU ajaa maksimiteholla. UI päivittyy noin 200 ms välein.                              | F5 tai `run`-komento             |
| `SLOW`    | ▶      | CPU ajaa hitaasti (~10 käskyä/s). UI päivittyy jokaisen käskyn jälkeen.                | F6 tai `slow`-komento            |
| `RESET`   | ■      | Kone on juuri nollattu. Muisti, rekisterit ja laitteet nollattu. Ei ladattua ohjelmaa. | Ctrl+R tai `reset`-komento       |

## Tilasiirtymät

```
            load / asm
RESET ──────────────────► STOPPED
  ▲                           │
  │ Ctrl+R / reset            │ F7 / step
  │                           ▼
STOPPED ◄──── F8 / stop ── STEP ──► (F5→FULL, F6→SLOW)
                           │
                    CPU HALT/EXIT ──► (auto uudelleenlataus seuraavalla askeleella)

FULL / SLOW ──► (HALT/EXIT/BP) ──► STOPPED
```

## Huomioita

- **FULL**- ja **SLOW**-tiloissa F5 tai F6 toimii myös pysäytyksenä (toggle): toinen painallus pysäyttää.
- Kun CPU on saavuttanut `HALT`- tai `EXIT`-käskyn, seuraava Step/Full/Slow-painallus **lataa ohjelman uudelleen** (reassembloi) ja aloittaa alusta.
- Näppäimistösyöte välitetään emulaattorille vain **FULL**- ja **SLOW**-tiloissa.
- **RESET**-tila siirtyy **STOPPED**-tilaan kun tiedosto ladataan tai assembloidaan (`load`, `asm`, Ctrl+O, Ctrl+B).

