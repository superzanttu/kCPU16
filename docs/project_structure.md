# kCPU16 Projektin Rakenne

Tämä dokumentti kuvaa projektin nykyisen tiedosto- ja hakemistorakenteen
sekä pääkomponenttien roolit.

## Yleiskuva

kCPU16 on 16-bittinen emulaattoriprojekti, joka sisältää:

- CPU- ja muistimallin
- Assemblerin ja disassemblerin
- Virtuaalilaitteet (näyttö, näppäimistö, tallennus)
- Textual-pohjaisen TUI-debuggerin
- CLI-käyttöliittymän
- ASM-esimerkit ja laajan regressiotestikokonaisuuden

---

## Hakemistorakenne (nykytila)

```text
kCPU16/
├── main.py
├── README.md
├── LICENSE
├── todo.md
├── docs/
│   ├── architecture.md
│   ├── assembler.md
│   ├── tui.md
│   ├── project_structure.md
│   ├── books/
│   ├── chip-8 info/
│   ├── misc/
│   └── plans/
├── code/
│   └── asm/
│       ├── chip-8/
│       ├── demo/
│       ├── kdos/
│       ├── lib/
│       ├── tut/
│       └── _tmp_disk_min.asm
├── kcpu16/
│   ├── __init__.py
│   ├── assembler.py
│   ├── cli.py
│   ├── constants.py
│   ├── cpu.py
│   ├── debugger.py
│   ├── disassembler.py
│   ├── editor.py
│   ├── exceptions.py
│   ├── instruction.py
│   ├── machine.py
│   ├── memory.py
│   ├── registers.py
│   ├── specs.py
│   ├── testrunner.py
│   ├── tui.py
│   ├── tui_commands.py
│   ├── tui_render.py
│   ├── tui_state.py
│   ├── code/
│   ├── devices/
│   ├── hardware/
│   │   ├── __init__.py
│   │   ├── cpu.py
│   │   ├── cpu_core.py
│   │   ├── cpu_exec.py
│   │   ├── cpu_memcheck.py
│   │   ├── cpu_mmio.py
│   │   ├── machine.py
│   │   ├── memory.py
│   │   ├── registers.py
│   │   └── devices/
│   │       ├── __init__.py
│   │       ├── keyboard.py
│   │       ├── screen.py
│   │       └── storage.py
│   ├── storage/
│   │   ├── demo_boot.dsk
│   │   ├── one.dsk
│   │   └── zero.dsk
│   └── test/
│       ├── includes/
│       ├── test-list.md
│       └── test_*.asm
└── vsc/
    ├── install.ps1
    ├── README.md
    └── kcpu16-asm/
```

---

## Pääkomponentit

### Juuritaso

- main.py: ohjelman aloituspiste (delegoi CLI:hin)
- README.md: projektin käyttöönotto ja yleisesittely
- todo.md: tehtävälista ja toteutusten seuranta
- code/asm: projektin ASM-lähteet kategorioittain (demo, lib, tut, kdos, chip-8)

### docs/

- architecture.md: arkkitehtuurikuvaus
- assembler.md: assembler-syntaksi ja direktiivit
- tui.md: TUI-käyttöohje
- project_structure.md: tämä tiedosto
- plans/: suunnitteludokumentit (tulevat ideat, vaihtoehdot)
- books/, chip-8 info/, misc/: taustamateriaali ja viitedokumentit

### kcpu16/ (Python-paketti)

Ydinmoduulit:

- assembler.py: ASM -> konekieli
- disassembler.py: konekieli -> ASM
- cli.py: komentorivikäyttö
- instruction.py: käskyjen metadata ja taulukot
- constants.py, exceptions.py: arkkitehtuurivakiot ja virhetyypit
- cpu.py, machine.py, memory.py, registers.py: yhteensopivuusrajapinta hardware-toteutukseen
- testrunner.py: ASM-pohjaisten testien ajologiikka

TUI-moduulit (jaettu useaan tiedostoon):

- tui.py: sovellusrunko, layout, tapahtumien ohjaus
- tui_render.py: renderöinti- ja näkymäpäivityslogiikka
- tui_commands.py: komentotulkin käsittelijät
- tui_state.py: tilanhallinnan apufunktiot

Hardware-kerros:

- hardware/cpu.py: CPU-facade
- hardware/cpu_core.py: fetch/decode/run-loop -ydin
- hardware/cpu_exec.py: opcode-exec-handlerit
- hardware/cpu_memcheck.py: muistitarkistuspolut
- hardware/cpu_mmio.py: MMIO-käsittely
- hardware/memory.py, hardware/registers.py, hardware/machine.py
- hardware/devices/: keyboard, screen, storage

Muut alihakemistot:

- kcpu16/devices/: yhteensopivuuswrapperit laitteille
- kcpu16/storage/: levykuvat testaukseen
- kcpu16/test/: regressiotestit (test_*.asm)
- kcpu16/code/: paketin sisäinen koodihakemisto (tällä hetkellä tyhjä)

---

## Arkkitehtuurin käytännön virtaus

1. Käynnistys: main.py -> kcpu16.cli.main()
2. ASM-käännös: assembler.py tuottaa konekielen
3. Lataus: machine/cpu/memory asettavat ohjelman emulaattoriin
4. Suoritus: hardware-kerroksen CPU-ydin ajaa käskyjä
5. Tarkastelu: TUI tai CLI näyttää tilan, muistin, rekisterit ja lokin

---

---

## ASM-tiedostojen nimeämiskäytäntö

### Kirjastot (`code/asm/lib/`)

Kaikki tiedostot `lib/`-hakemistossa ovat jaettuja kirjastoja. Niiden nimi
noudattaa muotoa `lib-NIMI.asm` — siis `lib-`-etuliite ja väliviiva:

| Tiedosto             | Kuvaus                                                                                |
| -------------------- | ------------------------------------------------------------------------------------- |
| `lib-gfx.asm`        | Grafiikkatoiminnot (piirtäminen, flip, koko ruudun fill, kiinteä 8x8 sprite-manageri) |
| `lib-screen.asm`     | Tekstiterminaali (print, input, scroll)                                               |
| `lib-disk.asm`       | Levytoiminnot (format, create, read jne.)                                             |
| `lib-font_small.asm` | 4×5 ASCII-fontti (CHIP-8-yhteensopiva)                                                |
| `lib-font_big.asm`   | Suuri segmenttinäyttöfontti                                                           |
| `lib-3dobjects.asm`  | 3D-objektidata ja apufunktiot                                                         |

**Säännöt kirjastoille:**
- Etuliite on aina `lib-` (väliviiva, ei alaviiva).
- Tiedoston on sijaittava `code/asm/lib/`-hakemistossa.
- Kirjasto ei saa olla itsenäinen suoritettava ohjelma (ei `.origin 0x0200`
  + `JUMP main` -aloitusta ilman, että se on suunniteltu suoritettavaksi
  `.include`-mekanismin kautta).

### Ohjelmat ja demot (`code/asm/demo/`, `tut/`, `kdos/`, `chip-8/`)

Ohjelmat, demot, tutoriaalit ja sovellukset **eivät** käytä `lib-`-
tai `lib_`-etuliitettä nimessään. Tämä estää sekaannuksen kirjastojen kanssa.

Demo-ohjelma, joka esittelee tietyn kirjaston toimintoja, nimetään muodolla
`demo_NIMI.asm`, jossa `NIMI` vastaa kirjaston nimeä ilman `lib-`-etuliitettä:

| Vanha nimi (virheellinen) | Oikea nimi              | Kuvaus                          |
| ------------------------- | ----------------------- | ------------------------------- |
| `demo/lib_gfx.asm`        | `demo/demo_lib_gfx.asm` | Esittelee `lib-gfx.asm`:n API:n |

**Säännöt ohjelmille:**
- Nimi ei aloita `lib-` eikä `lib_`.
- Kirjastoa esittelevä demo nimetään `demo_KIRJASTO.asm`
  (esim. `demo_lib_gfx.asm`, ei `lib_gfx.asm`).
- Ohjelmat voivat vapaasti käyttää muita nimeämistapoja
  (`3dcube.asm`, `clock_text.asm`, `algo_factorial.asm` jne.).

### Yhteenveto

| Hakemisto          | Etuliite/muoto   | Esimerkki          |
| ------------------ | ---------------- | ------------------ |
| `code/asm/lib/`    | `lib-NIMI.asm`   | `lib-gfx.asm`      |
| `code/asm/demo/`   | ei `lib-`/`lib_` | `demo_lib_gfx.asm` |
| `code/asm/tut/`    | ei `lib-`/`lib_` | `arithmetic.asm`   |
| `code/asm/chip-8/` | ei `lib-`/`lib_` | `chip-8.asm`       |
| `code/asm/kdos/`   | ei `lib-`/`lib_` | `kdos.asm`         |

---

## Huomio päivityksistä

Rakenne on muuttunut aiemmasta merkittävästi erityisesti kahdessa kohdassa:

- TUI on jaettu moduuleihin (tui.py + tui_render.py + tui_commands.py + tui_state.py)
- CPU on jaettu hardware-kerroksessa useaan osaan (cpu_core, cpu_exec, cpu_memcheck, cpu_mmio)
- ASM-tiedostojen nimeämiskäytäntö on dokumentoitu (ks. yllä);
  `demo/lib_gfx.asm` on nimetty uudelleen `demo/demo_lib_gfx.asm`:ksi.

Tämä dokumentti kuvaa nykyisen rakenteen ja korvaa aiemmat vanhentuneet
listaukset.
