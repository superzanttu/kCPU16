# kCPU16 — 16-bittinen CPU-emulaattori (Python)

kCPU16 on täysimittainen 16-bittinen CPU-emulaattori, jossa on tekstipohjainen käyttöliittymä.
Projekti sisältää oman assembly-kielen, assemblerin, disassemblerin, virtuaalikoneen sekä
interaktiivisen Textual-pohjaisen käyttöliittymän.

Projektin koodista vähintään 99.999% on kirjoittanut Github Copilot.

## Ominaisuudet

- **CPU-ydin** — Fetch → Privilege Check → Memory Check → Execute → PC Update -sykli
- **16-bittinen sana-osoitettu muisti** — 65 536 sanaa (0x0000–0xFFFF)
- **Rekisterit** — R0–R15 (GPR), FP, SP, PC, SR, MPR, TMR, CTMR
- **Tilarekisteri (SR)** — liput Z, N, C, V, I, P (Zero / Negative / Carry / Overflow / Interrupt / Privilege)
- **Käskykanta** — 53 käskyä (tiedonsiirto, aritmetiikka, logiikka, pino, hyppykäskyt, keskeytykset, järjestelmä)
- **Kolmipassinen assembler** — makrotuki (`.macro`/`.endmacro`), `.origin`-direktiivi, labelit
- **Disassembler** — konekieli → assembly-teksti
- **Muistisuojaus** — MPR-rekisteri rajoittaa User-tilan muistinkäyttöä
- **Keskeytykset** — 10 vektoria (INT 0–9), ohjelmallinen INT-käsky ja laitteistokeskeytykset
- **Virtuaalinen tekstinäyttö** — 80 × 24 merkkiä, 8 edustusväriä (FG) + 8 taustaVäriä (BG), bold
- **Grafiikkatilat** — tekstitila (A), puoliblokkipikseli 80×48 (B), braille 160×96 (C); kaksoisbufferointi ja scroll
- **Näppäimistölaite** — MMIO-luku osoitteista `KBD_DATA` ($0020) ja `KBD_STATUS` ($0021)
- **Satunnaislukugeneraattori** — MMIO-osoite `RAND_MMIO` ($0022), 16-bittinen Galois LFSR
- **Tallennuslaite** — lohkopohjainen levylaite (DREAD/DWRITE, boot-lataus sektorilta 0)
- **TUI-debuggeri** — Textual-pohjainen, ammattitason käyttöliittymä
- **CLI** — komentorivi (`python main.py`)

## Projektihakemisto

```
kCPU16/
├── main.py
├── code/
│   └── asm/
│       ├── chip-8/
│       ├── demo/
│       ├── kdos/
│       ├── lib/
│       └── tut/
├── kcpu16/
│   ├── hardware/
│   │   ├── cpu.py, cpu_core.py, cpu_exec.py, cpu_memcheck.py, cpu_mmio.py
│   │   ├── memory.py, registers.py, machine.py
│   │   └── devices/
│   │       ├── screen.py, keyboard.py, storage.py
│   ├── assembler.py, disassembler.py
│   ├── tui.py, tui_commands.py, tui_render.py, tui_state.py
│   ├── cli.py, debugger.py, editor.py, specs.py
│   ├── constants.py, exceptions.py, instruction.py, testrunner.py
│   ├── cpu.py, memory.py, registers.py, machine.py     # yhteensopivuuswrapperit
│   ├── devices/                                         # yhteensopivuuswrapperit
│   ├── storage/                                         # levykuvat (.dsk)
│   └── test/         # Automaattiset testit (.asm)
└── docs/
    ├── architecture.md
    ├── assembler.md
    ├── tui.md
    └── project_structure.md
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
python main.py code/asm/demo/algo_fibonacci.asm
```

### Lataa .dsk-levykuva tallennuslaitteeseen

```bash
python main.py --dsk levykuva.dsk
```

### Tarkista assembly-tiedoston syntaksi

```bash
python main.py --check ohjelma.asm
```

## Mitä kCPU16 osaa

Tämä kappale kuvaa kattavasti kaiken sen, mitä kCPU16 kokonaisuutena sisältää ja mihin sillä pystyy.

### CPU-arkkitehtuuri ja käskykanta

kCPU16 on täydellinen 16-bittinen prosessori, joka toteuttaa seitsemän käskyryhmää:

| Ryhmä               | Käskyt                                                    |
| ------------------- | --------------------------------------------------------- |
| **Tiedonsiirto**    | LOAD, CPY, READ, STORE, READ\_IND, STORE\_IND, READ\_REL, STORE\_REL, STOREI, STOREI\_IND, STOREI\_REL, FILL, COPY |
| **Aritmetiikka**    | ADD, SUB, MUL, DIV, CMP, ADC                              |
| **Logiikka**        | AND, OR, XOR, NOT, SHL, SHR                               |
| **Pino**            | PUSH, POP, SWSP                                           |
| **Ohjausrakenne**   | JUMP, CALL, RET, JZ, JNZ, JLT, JGT, JLE, JGE, JMPI, CALLI |
| **Keskeytykset**    | INT, IRET, STI, CLI, EXIT, HALT                           |
| **Järjestelmä/IO**  | DREAD, DWRITE, SMPR, STMR, SCTMR, TSL, STATE, NOP        |

Erikoiskäskyjä:
- **FILL / COPY** — täyttää tai kopioi kokonaisen muistialueen yhdellä käskyllä
- **JMPI / CALLI** — indeksoitu taulukkohyppy/-kutsu (`PC ← addr[reg]`): soveltuu esim. switch-case-rakenteisiin
- **TSL** — atominen Test-and-Set Lock mutex-toteutukseen
- **STATE** — 1-sanainen tilasignaali TUI:n state-lokia varten (64 erilaista tilaa, id 0–63)
- **ADC** — yhteenlasku carry-lipulla 32-bittistä laskentaa varten

Prosessori simuloi käskyille yksityiskohtaiset suoritussyklit (esim. MUL = 4 µs, DIV = 8 µs, DREAD/DWRITE = 10 µs) ja 1 MHz:n kellotaajuuden. Simuloitu aika ohjaa ajastin- ja kellokeskeytyksiä sekä uptime-laskuria.

### Muistikartta ja MMIO

Koko 64 KiB (65 536 sanaa) muistiavaruus on jaettu loogisiin alueisiin:

| Alue              | Koko         | Käyttötarkoitus                                                |
| ----------------- | ------------ | -------------------------------------------------------------- |
| $0000 – $000F     | 16 sanaa     | Keskeytysvektoritaulukko (10 vektoria käytössä, 6 varattu)     |
| $0010 – $001F     | 16 sanaa     | Kellokello MMIO: vuosi/kk/pv/hh/mm/ss/ms, 64-bit uptime, CTMR |
| $0020 – $0021     | 2 sanaa      | Näppäimistö MMIO: KBD\_DATA (pop tapahtuma), KBD\_STATUS (jono) |
| $0022             | 1 sana       | Satunnaisluku MMIO (Galois LFSR, jakso 65 535)                 |
| $0100 – $01FF     | 256 sanaa    | Bootloader-alue (ladataan levyltä kylmäkäynnistyksessä)        |
| $0200 – $F7FF     | ~62 976 sanaa | Vapaa ohjelma-RAM                                              |
| $F800 – $FF7F     | 1920 sanaa   | Video RAM (VRAM): 80 × 24 merkkiä väriattribuutteineen         |
| $FF80 – $FF82     | 3 sanaa      | Grafiikkarekisterit: GFX\_MODE\_REG, GFX\_FLIP\_REG, GFX\_SCROLL\_CMD\_REG |
| $FF83 – $FFFF     | 125 sanaa    | Kernel stack                                                   |

### Näyttö ja grafiikkatilat

kCPU16 tukee kolmea grafiikkatilaa, joita vaihdetaan kirjoittamalla `GFX_MODE_REG`-rekisteriin ($FF80):

| Tila   | Arvo | Resoluutio   | Tekniikka                                         |
| ------ | ---- | ------------ | ------------------------------------------------- |
| **A**  | 0    | 80 × 24 merkkiä | Tekstitila — jokainen sana on merkki + väriattribuutti |
| **B**  | 1    | 80 × 48 pikseliä | Puoliblokkipikseli — UTF-8 lohkosymbolit          |
| **C**  | 2    | 160 × 96 pikseliä | Braille-merkit — korkein pikseliresoluutio         |

Tekstitilassa (A) jokainen VRAM-sana sisältää ASCII-merkin (bitit 0–7), edustavärin FG (bitit 8–10, 8 väriä), taustavärin BG (bitit 11–13, 8 väriä) sekä lihavoinnin (bitti 14). Grafiikkatiloissa B ja C käytetään kaksoisbufferointia (`GFX_FLIP_REG`) välkkymisen estämiseksi, sekä `GFX_SCROLL_CMD_REG`-rekisteria näkyvän kehyksen scrollaamiseksi neljään suuntaan.

### Keskeytykset

| Numero | Lähde                          | Laukaistaan                            |
| ------ | ------------------------------ | -------------------------------------- |
| 0      | Jako nollalla                  | DIV-käsky jakajalla 0                  |
| 1      | Tuntematon opcode              | Virheellinen käsky                     |
| 2      | Pinon ylivuoto                 | SP ylittää MPR-rajan User-tilassa      |
| 3      | Breakpoint                     | Ohjelmallinen (INT 3) tai debuggeri    |
| 4      | Privilege Violation            | Kernel-käsky User-tilassa              |
| 5      | Memory Access Fault            | Suojattu muistiosoite User-tilassa     |
| 6      | Näppäimistö (INT\_KEYBOARD)    | Näppäimen painallus tai vapautus       |
| 7      | Ajastinkeskeytys (TMR)         | STMR-käsky, väli mikrosekunneissa      |
| 8      | Prosessin lopetus (EXIT)       | EXIT-käsky                             |
| 9      | Kellokeskeytys (CTMR)          | SCTMR-käsky, väli millisekunteissa     |

Keskeytys tallentaa atomisesti PC:n ja SR:n kernelin pinoon, siirtyy Kernel-tilaan ja estää lisäkeskeytykset. `IRET` palauttaa tilanteen täydellisesti.

### Assembler

Kolmipassinen assembler tukee:

- **Operandisyntaksi:** desimaalit, heksadesimaali (`0xFF`), binääri (`0b1010`), oktaali (`0o52`), labelit, arkkitehtuurivakiot, `.const`-vakiot, `[addr]`-, `[reg]`- ja `[FP+offset]`-muistiosoitteet
- **Direktiivit:**
  - `.origin addr` / `.at addr` — aloitusosoite ja segmenttivaihdot
  - `.dw` / `.db` — 16-bittiset ja 8-bittiset datavakiot
  - `.dstr` — null-terminoitu merkkijono (tuki `\n`, `\t`, `\0`)
  - `.const NIMI, ARVO` — nimetyt vakiot
  - `.macro` / `.endmacro` — parametrittomat makrot
  - `.include "tiedosto"` — muiden .asm-tiedostojen sisällyttäminen (silmukkasuojaus)
  - `.bootblock` / `.endbootblock` — bootsektorin kirjoitus levykuvaan käännösaikana
  - `.diskblock N` — konekielen tallennus suoraan tallennuslaitteen blokkiin N
  - `.state_text N, delay, "teksti"` — STATE-käskyille TUI-lokitusteksti ja viive
- **Testidirektiivit:** `.expect_reg`, `.expect_flag`, `.expect_mem`, `.expect_storage`, `.inject_key`, `.inject_key_release` — automaattitestausta suoraan assembly-lähdekoodissa
- **Automaattinen käskynvalinta:** assembler valitsee oikean konekielikäskyn `[...]`-syntaksin perusteella (READ/READ\_IND/READ\_REL, STORE/STORE\_IND/STORE\_REL jne.)
- **Muistiraportti:** `--asm`-lippu tulostaa konekielilistan segmenteittäin sekä raportin ohjelma-RAM:n käytöstä ja jäljellä olevasta tilasta

### TUI-debuggeri

Textual-pohjainen interaktiivinen käyttöliittymä sisältää:

**Näkymät:**
- **Screen** — 80 × 24 VRAM reaaliajassa (merkit ja värit)
- **Disassembly** — konekielinen muistilista; nykyinen PC merkitty `▶`, breakpointit `●`
- **Memory** — hex-dump 8 sanaa per rivi + ASCII-sarake
- **Stack** — pinon sisältö SP:stä ylöspäin
- **Flags** — SR-liput (Z/N/C/V/I/P), CPU-tila, TMR/CTMR-ajastintilat
- **Registers** — kaikki rekisterit (R0–R15, FP, SP, PC, SR, MPR, TMR, CTMR); muuttuneet arvot korostetaan

**Suoritustilat:**
- **STEP** (F7/F10) — yksi käsky kerrallaan
- **SLOW** (F6) — säädettävä nopeus 1–100 000 IPS logaritmisella liukusäätimellä ja x1/x10/x100 -kertoimilla
- **FAST** (F5) — maksimiteholla, näyttö päivittyy ~200 ms välein
- **MAX** (F4) — maksimiteholla ilman näytön välinäyttöä (vain pysähtyessä)
- **Breakpointit** (F2) — lisää/poista breakpoint millä tahansa muistiosoitteella

**Komentotulkki (`>`):**

| Toiminto           | Komento                           |
| ------------------ | --------------------------------- |
| Suoritus           | `step [n]`, `run`, `stop`, `slow [n]` |
| Lataus ja kääntö   | `load <tiedosto>`, `asm`, `check`, `restart` |
| Nollaus            | `reset`, `reset deep`, `reset cpu` |
| Breakpointit       | `bp <addr>`, `bp list`, `bp clear` |
| Muistin tarkastelu | `mem <addr> [n]`, `mset`, `mfill` |
| Levyoperaatiot     | `disk <blk>`, `disk load`, `disk save`, `dset`, `dfill`, `mem2disk`, `disk2mem` |
| Muut               | `cls`, `gameinput on/off`, `spec`, `version`, `help` |

**Game Input -tila** (`Ctrl+Space`): välittää näppäinpainallukset suoraan emulaattorin KBD-jonoon ohjelmien interaktiivista testausta varten.

**Tiedostoselain:** Load-painike (tai `Ctrl+O`) avaa selausnäkymän `code/`-hakemistosta; kaksoisklikillä lataa ohjelman välittömästi.

### Assembly-kirjastot (`code/asm/lib/`)

| Kirjasto             | Mitä tarjoaa                                                                                              |
| -------------------- | --------------------------------------------------------------------------------------------------------- |
| **lib-screen.asm**   | Tekstitilaterminaali: `scr_cls`, `scr_set_color`, `scr_print` (tuki `\n` ja `\t`), `scr_input` (lue syöte käyttäjältä), automaattinen skrollaus |
| **lib-gfx.asm**      | Grafiikkakirjasto tiloille B ja C: pikselinpiirto, viivanpiirto, suorakaide, ympyrä (täytetty/ääriviiva), tekstinpiirto BIG-fontilla, 16 spritepaikkaa (8×8, törmäystarkistus), scroll neljään suuntaan, XOR/FG/BG-piirtotilat, flip-operaatio |
| **lib-disk.asm**     | Tiedostojärjestelmä tallennuslaitteelle: `disk_format`, `disk_mkdir`, `disk_create`, `disk_write`, `disk_read`, `disk_stat`, `disk_list`, `disk_delete`, `disk_check` — FAT-taulukko + hakemistorakenne 8 merkinnällä |
| **lib-font\_big.asm** | 6 × 8 -pikselifontti: numerot 0–9, erikoismerkit, A–F, Ä/Ö/Å, sekä koko ASCII 0x20–0x7E pienemmästä mikrofontista skaalattuna |
| **lib-font\_small.asm** | 4 × 5 -pikselifontti: CHIP-8-yhteensopivat glyphit 0–F + kaikki tulostettavat ASCII-merkit |
| **lib-3dobjects.asm** | 3D-objektidata ja apufunktiot: kuutio, pyramidi, L- ja J-kirjain (extruded), sinustaulu, etumerkillinen kertolasku/100 |

### Demo-ohjelmat (`code/asm/demo/`)

| Ohjelma                 | Mitä esittelee                                                                                     |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| **algo\_factorial.asm** | Kertoma 5! aliohjelmalla (CALL/RET)                                                                |
| **algo\_fibonacci.asm** | Fibonacci-lukujono iteratiivisesti (F(0)–F(9))                                                     |
| **algo\_gcd.asm**       | Eukleideen GCD-algoritmi jakojäännöslaskennalla                                                    |
| **colors.asm**          | Kaikki 8 × 8 = 64 FG/BG-väriyhdistelmää normaali- ja lihavointitilassa                            |
| **screen.asm**          | lib-screen.asm:n esittely: värilliset tekstit, tabulaattorigrid, käyttäjän nimen kysyminen (scr\_input) |
| **clock\_text.asm**     | Reaaliaikainen päivämäärä+kellonaika (DD.MM.YYYY HH:MM:SS.MSS) CTMR-kellokeskeytyksellä           |
| **clock.asm**           | Iso digitaalikello 6 × 8 BIG-fontilla, vilkkuvat ':'-merkit 1 Hz                                  |
| **keyboard.asm**        | Interaktiivinen näppäimistödemo: INT 6, painallus/vapautus, Q lopettaa                            |
| **interrupt\_timer.asm**| Kaksi keskeytysmekanismia yhtä aikaa: CTMR 500 ms (INT 9) + TMR 50 000 käskyä (INT 7)             |
| **3dcube.asm**          | Pyörivä 3D-wireframe: kuutio → L-kirjain → J-kirjain tiloissa B ja C; rotaatio X+Y+Z-akseleilla   |
| **3dcube2.asm**         | Kuten yllä, mutta näkymättömät särmät piilotetaan (hidden line removal)                            |
| **3d.asm**              | Yhdistetty 3D-demo: wireframe + solid, useita kohtauksia (kuutio/pyramidi/L/J) tiloissa B ja C    |
| **demo\_lib\_gfx.asm**  | lib-gfx.asm:n kattava esittely: satunnaiset pikselit/viivat, scroll neljään suuntaan, kirjaimet A–Z, teksti BIG-fontilla, Pac-Man sprite + törmäystarkistus |
| **benchmark.asm**       | Suorituskykymittaus: CPU (käskyä/s), RAM luku- ja kirjoitusnopeus, levyn luku- ja kirjoitusnopeus  |
| **benchmark2.asm**      | Adaptiivinen suorituskykymittaus: pysähtyy kun tulos vakautuu tai laskee                           |
| **amiga.asm**           | Commodore Amiga "Guru Meditation" -virheruudun simulaatio, vilkkuva punainen kehys 1 Hz           |
| **c64.asm**             | Commodore 64 -käynnistysnäytön simulaatio, vilkkuva kursori sinisellä taustalla                   |
| **disk\_test.asm**      | lib-disk.asm:n testisarja: alustus, hakemistot, tiedostot, kirjoitus/luku, listaus, poisto        |
| **diskboot.asm**        | `.bootblock`-direktiivin demonstraatio: bootsektori levykuvaan + pääohjelma omaan osoitteeseensa  |

### Tutoriaalit (`code/asm/tut/`)

Jokainen tutoriaali on itsenäinen, tiheästi kommentoitu esimerkki yhdestä aihepiiristä:

| Ohjelma               | Aihe                                                             |
| --------------------- | ---------------------------------------------------------------- |
| **arithmetic.asm**    | Peruslaskutoimitukset: `(10 + 5) * 3 - 3 = 42`, tulos VRAM:iin  |
| **loop\_countdown.asm** | Silmukka alaspäin SUB + JNZ                                     |
| **stack.asm**         | PUSH/POP LIFO-toiminta, CALL/RET pinokehyksineen                 |
| **macros.asm**        | `.macro`/`.endmacro`, `.origin`-direktiivi                       |
| **vram\_write.asm**   | Suora VRAM-kirjoitus STORE-käskyllä, merkit ja väriattribuutit   |
| **vram\_fill.asm**    | Koko näytön täyttö FILL-käskyllä toistuvalla tekstillä           |
| **conditionals.asm**  | CMP + kaikki kuusi ehdollista hyppykäskyä (JZ…JGE)              |
| **bitops.asm**        | Kaikki kuusi bittioperaatiokäskyä (AND/OR/XOR/NOT/SHL/SHR)      |
| **exit.asm**          | EXIT vs. HALT — hallittu prosessinlopetus vs. koneen sammutus     |

### CHIP-8-emulaattori (`code/asm/chip-8/`)

kCPU16 pystyy ajamaan CHIP-8-virtuaalikoneita:

- **chip-8.asm** toteuttaa CHIP-8-prosessorin kCPU16 assembly-kielellä:
  - 4 KB CHIP-8-muisti ($6000–$6FFF), 64 × 32 framebuffer XOR-piirtologiikalla, collision-lippu (VF)
  - 16 yleisrekisteriä V0–VF, I-rekisteri, PC, SP (16 tasoa), DT ja ST -ajastimet
  - Koko CHIP-8 opcode-joukko (00E0, 00EE, 1nnn … Fxxx)
  - Näppäimistöintegraatio INT 6:lla, FX0A-odotus (blocking wait for key)
  - DT/ST-ajastimet 60 Hz CTMR-kellokeskeytyksellä (INT 9)
- **chip8-snake.asm** on CHIP-8 Snake-peli, joka ajetaan chip-8.asm-emulaattorin päällä

### KDOS-käyttöjärjestelmä (`code/asm/kdos/`)

**kdos.asm** on täydellinen interaktiivinen komentorivikäyttöjärjestelmä kCPU16:lle. Se käyttää lib-screen.asm- ja lib-disk.asm-kirjastoja ja tarjoaa seuraavat komennot:

| Komento    | Toiminto                                                                  |
| ---------- | ------------------------------------------------------------------------- |
| `fdisk`    | Alusta tallennuslaitteen partitiointi (FAT + hakemistorakenne)            |
| `format`   | Alusta tiedostojärjestelmä (tyhjennä FAT ja hakemisto)                    |
| `check`    | Tarkista tiedostojärjestelmän eheys                                       |
| `sync`     | Varmista datan kirjoittuminen levylle                                     |
| `ls` / `dir` | Listaa hakemiston sisältö (tiedostot + alihakemistot + vapaatila)      |
| `stat`     | Näytä tiedoston tai hakemiston metatiedot (koko, luonti-/muokkausaika)   |
| `find`     | Etsi tiedostoja/hakemistoja nimellä                                       |
| `mkdir`    | Luo hakemisto                                                             |
| `cd`       | Vaihda nykyinen hakemisto                                                 |
| `rmdir`    | Poista tyhjä hakemisto                                                    |
| `touch`    | Luo tyhjä tiedosto                                                        |
| `write`    | Kirjoita tekstiä tiedostoon                                               |
| `lorem`    | Täytä tiedosto Lorem Ipsum -datalla                                       |
| `read`     | Lue ja näytä tiedosto (heksana)                                           |
| `more`     | Sivuttainen tiedoston lukeminen (tekstimuoto, N riviä/sivu)               |
| `copy`     | Kopioi tiedosto                                                           |
| `rm` / `del` | Poista tiedosto                                                         |
| `run`      | Lataa ohjelma levyltä muistiin ja suorita se                              |
| `..`       | Nouse ylähakemistoon                                                      |
| `help`     | Näytä komentojen ohje                                                     |

KDOS käynnistyy kylmäkäynnistyksellä levykuvan bootsektorista ja jää odottamaan käyttäjän syötettä.

### Automaattinen testijärjestelmä

`kcpu16/test/`-hakemistossa on 179 automaattista testitiedostoa (`.asm`), jotka kattavat kaikki käskyt, reunatapaukset ja laitteistotoiminnot:

- ADC, ADD, SUB, MUL, DIV, CMP, AND, OR, XOR, NOT, SHL, SHR
- PUSH, POP, SWSP, FILL, COPY, READ/STORE (ind/rel/abs/imm)
- JUMP, CALL, RET, JMPI, CALLI, kaikki ehdolliset hypyt
- INT, IRET, STI, CLI, TSL, EXIT, HALT, NOP
- Näppäimistö- (kbd), ajastin- (TMR/CTMR), kellokeskeytykset (clock/uptime)
- DREAD/DWRITE, satunnaisluku (rand), muistisuojaus (smpr/privilege)
- Grafiikkatilat (gfx), bootblock, include, direktiivit, negatiiviluvut, sisäkkäiset kutsut

Testit ajetaan CLI:llä: `python main.py --test kcpu16/test/test_add.asm`

### Mitä kCPU16:lla pystyy rakentamaan

kCPU16 on riittävän täysiverinen alusta seuraavien toteuttamiseen assembly-kielellä:

- **Grafiikkaohjelmat ja demot**: pikseligrafiikkaa 160 × 96 resoluutiolla, animaatioita, 3D-pyöriviä objekteja, sprite-pelejä törmäystarkistuksella
- **Interaktiiviset ohjelmat**: näppäimistön lukeminen keskeytyspohjaisesti, käyttäjäsyötteet, tekstipohjainen käyttöliittymä lib-screen.asm:lla
- **Reaaliaikaiset ohjelmat**: kello, ajastimet, millisekuntitarkkuus CTMR:llä
- **Levyjärjestelmä**: tiedostojen luonti, kirjoitus, luku, hakemistorakenne FAT-pohjaisella lib-disk.asm:lla
- **Käyttöjärjestelmä**: KDOS osoittaa, että kCPU16:lla voi rakentaa toimivan komentorivijärjestelmän tiedostonhallinnalla
- **Virtuaalikoneet**: CHIP-8-emulaattori osoittaa, että kCPU16 on riittävä toisen prosessorin emulointiin assembly-kielellä
- **Suorituskykymittaukset**: benchmark-ohjelmat mittaavat CPU-, RAM- ja levynopeuksia reaaliajassa
- **Retronostagia**: C64- ja Amiga-käynnistysnäytöt, CHIP-8 Snake -peli

## Dokumentaatio

| Tiedosto                                               | Sisältö                                                                     |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| [docs/architecture.md](docs/architecture.md)           | CPU-arkkitehtuurispesifikaatio: rekisterit, muistikartta, ISA, keskeytykset |
| [docs/assembler.md](docs/assembler.md)                 | Assembly-kielen syntaksi, direktiivit, arkkitehtuurivakiot, esimerkit       |
| [docs/tui.md](docs/tui.md)                             | TUI-debuggerin asettelu, näppäinsidonnaisuudet ja komennot                  |
| [docs/project_structure.md](docs/project_structure.md) | Projektin hakemistorakenne ja moduulien kuvaukset                           |
| [docs/plans/grafiikkatila.md](docs/plans/grafiikkatila.md) | Grafiikkatila: Textual-kirjaston mahdollisuudet ja suositeltu toteutus      |

## Esimerkkiohjelmat

| Tiedosto                   | Kuvaus                                                     |
| -------------------------- | ---------------------------------------------------------- |
| `tut/arithmetic.asm`       | Peruslaskutoimitukset: (10+5)×3−3 = 42, kirjoitus VRAM:iin |
| `tut/loop_countdown.asm`   | Silmukka ja laskuri alaspäin                               |
| `tut/stack.asm`            | Pinokäskyjen demonstraatio (PUSH/POP/CALL/RET)             |
| `tut/macros.asm`           | Makrojen käyttöesimerkki                                   |
| `tut/vram_write.asm`       | Suora VRAM-kirjoitus, värit ja attribuutit                 |
| `tut/vram_fill.asm`        | Tekstin täyttö koko näytölle VRAM:n kautta                 |
| `tut/conditionals.asm`     | Ehdolliset hypyt (JZ/JNZ/JLT/JGT/JLE/JGE)                  |
| `tut/bitops.asm`           | Bittioperaatiot (AND/OR/XOR/NOT/SHL/SHR)                   |
| `algo_factorial.asm`       | Kertoman laskenta aliohjelmalla (CALL/RET)                 |
| `algo_fibonacci.asm`       | Fibonacci-lukujen laskenta iteratiivisesti                 |
| `algo_gcd.asm`             | Eukleideen GCD-algoritmi                                   |
| `demo/clock_text.asm`      | Päivämäärä + kellonaika tekstimuodossa                     |
| `demo/colors.asm`          | FG/BG-väriyhdistelmien visualisointi                       |
| `demo/keyboard.asm`        | Interaktiivinen näppäimistödemo (INT 6)                    |
| `demo/interrupt_timer.asm` | Ajastin- ja kellokeskeytysten demo (INT 7 + INT 9)         |
| `demo/benchmark.asm`       | Suorituskykymittaus (CPU/RAM/levy)                         |
| `demo/algo_fibonacci.asm`  | Fibonacci-lukujen laskenta demokansiosta                   |
| `lib/lib-font_big.asm`     | BIG-fonttidata demoja varten                               |

### Suositeltu opintopolku (ajettava)

Suorita ohjelmat tässä järjestyksessä:

1. `python main.py code/asm/tut/arithmetic.asm`
2. `python main.py code/asm/tut/loop_countdown.asm`
3. `python main.py code/asm/tut/stack.asm`
4. `python main.py code/asm/tut/macros.asm`
5. `python main.py code/asm/tut/vram_write.asm`
6. `python main.py code/asm/tut/vram_fill.asm`
7. `python main.py code/asm/tut/conditionals.asm`
8. `python main.py code/asm/tut/bitops.asm`
9. `python main.py code/asm/demo/algo_factorial.asm`
10. `python main.py code/asm/demo/algo_fibonacci.asm`
11. `python main.py code/asm/demo/algo_gcd.asm`
12. `python main.py code/asm/demo/colors.asm`
13. `python main.py code/asm/demo/clock_text.asm`
14. `python main.py code/asm/demo/interrupt_timer.asm`
15. `python main.py code/asm/demo/keyboard.asm`
16. `python main.py code/asm/demo/benchmark.asm`

Vinkki: voit tarkistaa syntaksin ilman ajoa komennolla `python main.py --check code/asm/tiedosto.asm`.

## Lisenssi

Katso [LICENSE](LICENSE).
