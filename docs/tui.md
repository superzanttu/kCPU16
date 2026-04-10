# kCPU16 TUI-debuggeri

TUI (Text User Interface) on kCPU16:n interaktiivinen Textual-pohjainen käyttöliittymä.
Se on inspiroitu MARS/RARS-, GDB TUI-, Turbo Debugger- ja emu8086-ohjelmistoista.

---

# 1. Asettelu

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
| Toolbar: Load | Assemble ^B | Step F7 | Fast F5 | Max F4 | Slow F6 | Stop F8 | Reset ^R | BP F2 | ...    |
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
| F4       | Aja MAX-nopeudella (MAX)             |
| F5       | Aja nopeasti (FAST)                  |
| F6       | Aja hitaasti (SLOW)                  |
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

| Tila      | Merkki | Kuvaus                                                                                          | Miten saavutetaan                |
| --------- | ------ | ----------------------------------------------------------------------------------------------- | -------------------------------- |
| `STOPPED` | ■      | CPU pysähtyneenä. Muisti ja rekisterit säilyvät. Askel tai ajo mahdollinen.                     | Ohjelma pysäytetty (F8 / `stop`) |
| `STEP`    | ■      | Yksi käsky suoritettu. CPU odottaa seuraavaa komentoa.                                          | F7 / F10 tai `step`-komento      |
| `FAST`    | ▶      | CPU ajaa maksimiteholla. UI päivittyy noin 200 ms välein.                                       | F5 tai `run`-komento             |
| `MAX`     | ▶      | CPU ajaa maksimiteholla ilman näytön päivitystä ajon aikana. Näyttö päivittyy vain pysähtyessä. | F4                               |
| `SLOW`    | ▶      | CPU ajaa hitaasti (säädettävä nopeus). UI päivittyy jokaisen käskyn jälkeen.                    | F6 tai `slow`-komento            |
| `RESET`   | ■      | Kone on juuri nollattu. Muisti, rekisterit ja laitteet nollattu. Ei ladattua ohjelmaa.          | Ctrl+R tai `reset`-komento       |

## Tilasiirtymät

```
            load / asm
RESET ──────────────────► STOPPED
  ▲                           │
  │ Ctrl+R / reset            │ F7 / step
  │                           ▼
STOPPED ◄──── F8 / stop ── STEP ──► (F4→MAX, F5→FAST, F6→SLOW)
                           │
                    CPU HALT/EXIT ──► (auto uudelleenlataus seuraavalla askeleella)

FAST / MAX / SLOW ──► (HALT/EXIT/BP) ──► STOPPED
```

## Huomioita

- **FAST**-, **MAX**- ja **SLOW**-tiloissa vastaava näppäin (F5/F4/F6) toimii myös pysäytyksenä (toggle): toinen painallus pysäyttää.
- Kun CPU on saavuttanut `HALT`- tai `EXIT`-käskyn, seuraava Step/Fast/Max/Slow-painallus **lataa ohjelman uudelleen** (reassembloi) ja aloittaa alusta.
- Näppäimistösyöte välitetään emulaattorille vain **FAST**-, **MAX**- ja **SLOW**-tiloissa.
- **RESET**-tila siirtyy **STOPPED**-tilaan kun tiedosto ladataan tai assembloidaan (`load`, `asm`, Ctrl+O, Ctrl+B).

---

# 7. Suoritusnopeuden säätö (SLOW-tila)

SLOW-tilassa suoritusnopeutta voidaan säätää portaattomasti käyttöliittymän liukusäätimellä ja kerroinnapeilla.

## Liukusäädin

Toolbarin oikeassa reunassa näkyy **IPS-liukusäädin** (Instructions Per Second):

```
IPS: 1000 [════════════════════════════════════════════════════════●══]  x1  x10  x100
```

- **IPS-arvo** näyttää tehollisen suoritusnopeuden (liukusäädin × kerroin)
- **Liukusäätimen alue**: 1–1000 käskyä/sekunti (logaritminen skala)
- **Raitaa** voi klikata tai raahata arvon muuttamiseksi
- **Hiiren rullalla** säädetään logaritmisesti (±10 % per nykäisy)

## Kerroinnappitapit (x1 / x10 / x100)

Liukusäätimen oikealla puolella on kolme nappia, jotka kertovat liukusäätimen arvon:

| Nappi  | Kerroin | Esimerkki (säädin=50) | Tehokas alue |
| ------ | ------- | --------------------- | ------------ |
| `x1`   | 1       | 50 IPS                | 1–1 000      |
| `x10`  | 10      | 500 IPS               | 10–10 000    |
| `x100` | 100     | 5 000 IPS             | 100–100 000  |

Valittu nappi korostuu. Oletuksena `x1` on valittuna.

## Komentoriviltä

| Komento          | Kuvaus                                    |
| ---------------- | ----------------------------------------- |
| `slow`           | Näytä nykyinen nopeus                     |
| `slow <1–1000>`  | Aseta liukusäätimen arvo (kerroin säilyy) |
| `speed`          | Näytä nykyinen nopeus                     |
| `speed <1–1000>` | Aseta liukusäätimen arvo (kerroin säilyy) |

## Huomioita

- Nopeuden muutos vaikuttaa **heti** jos CPU on käynnissä SLOW-tilassa — uudelleenkäynnistystä ei tarvita.
- Very suuria kerroimen arvoja (x100 + säädin max) käyttäessä suoritusnopeus voi ylittää FULL-tilan nopeuden — tässä tilanteessa suoritus on silti yksikäskyinen eikä yhtä tehokas kuin FULL-tila (erä-suoritus).
- Liukusäädin käyttää **logaritmista asteikkoa**, joten se antaa enemmän tarkkuutta pienillä nopeuksilla (esim. 1–10 IPS) ja suuremmilla harppauksin suurilla nopeuksilla.

---

# 8. Näppäimenpainallukset ja emulaattori

TUI välittää näppäimenpainallukset emulaattorin näppäimistölaitteelle (KeyboardDevice) tietyissä olosuhteissa.

## Milloin näppäimet välitetään

Näppäimenpainallus välitetään emulaattorille **vain** kun kaikki seuraavat ehdot täyttyyvät:

1. Suoritustila on **FAST**, **MAX** tai **SLOW** — CPU on siis käynnissä
2. Emulaattorissa on näppäimistölaite (`keyboard`-laite määritelty)
3. Käyttäjä ei kirjoita komentokenttään (`>`) — komentokenttä on aktiivinen
4. Painettu merkki on tulostettava ASCII-merkki (kooditävälitä 32–126)

## Mitä ei välitetä

- Funktionaäppäimet (F1–F10), nuolinäppäimet, Ctrl-yhdistelmät — nämä ovat TUI:n omia pikavalin-
  toja eivätkä kulje emulaattorille
- Näppäimet **STOPPED**-, **STEP**- tai **RESET**-tiloissa — CPU ei ole käynnissä
- Komentokenttään kirjoitettavat merkit — komento syöte käsitellään TUI:ssa

## Toteutuksen rajoitteet

Terminaali ei tue **näppäimennostoihin** (key release) perustuvia tapahtumia. Jokainen merkki
 lähetetään emulaattorin jonoon sekä painalluksena että vapautuksena peräkkäin saman tapahtuman
 käsittelyn yhteydessä. Tämä riittää useimmille käyttötapauksille, mutta **pitkistä näppäinten painalluksista** (key held down) ei emulaattori saa tietoa.

## Yhteenveto eri suoritustiloissa

| Tila      | Näppäimet emulaattorille |
| --------- | ------------------------ |
| `STOPPED` | Ei                       |
| `STEP`    | Ei                       |
| `FAST`    | Kyllä (ASCII 32–126)     |
| `MAX`     | Kyllä (ASCII 32–126)     |
| `SLOW`    | Kyllä (ASCII 32–126)     |
| `RESET`   | Ei                       |

