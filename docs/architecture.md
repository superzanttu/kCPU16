# kCPU16 Arkkitehtuurispesifikaatio

Versio 5.0

Tämä dokumentti on kCPU16-prosessorin virallinen tekninen spesifikaatio. Se sisältää kaikki tarvittavat tiedot emulaattorin rakentamiseksi tai assembly-ohjelmien kirjoittamiseksi.

---

# 1. Yleiskatsaus

kCPU16 on 16-bittinen von Neumann -arkkitehtuuriin perustuva prosessori.

| Ominaisuus         | Arvo                                              |
| ------------------ | ------------------------------------------------- |
| Sanan leveys       | 16 bittiä                                         |
| Muistiavaruus      | 65 536 sanaa (0x0000–0xFFFF)                      |
| Osoitustyyppi      | Sana-osoitettu (word-addressed)                   |
| Arkkitehtuurimalli | Von Neumann (koodi ja data samassa muistissa)     |
| Tavujärjestys      | Ei oleellinen (sana = pienin osoitettava yksikkö) |
| Suojaustilat       | Kernel Mode ja User Mode                          |
| Käskyn koko        | 1–3 sanaa (opcode + 0–2 operandia)                |

---

# 2. Rekisterit

## 2.1 Yleiskäyttöiset rekisterit (GPR)

16 kpl 16-bittistä yleiskäyttöistä rekisteriä. Käskyissä koodataan 5-bittisellä indeksillä.

| Rekisteri | Indeksi | Kuvaus                               |
| --------- | ------- | ------------------------------------ |
| R0        | 0       | Yleiskäyttöinen datarekisteri        |
| R1        | 1       | Yleiskäyttöinen datarekisteri        |
| R2        | 2       | Yleiskäyttöinen datarekisteri        |
| R3        | 3       | Yleiskäyttöinen / paluuarvorekisteri |
| R4        | 4       | Yleiskäyttöinen datarekisteri        |
| R5        | 5       | Yleiskäyttöinen datarekisteri        |
| R6        | 6       | Yleiskäyttöinen datarekisteri        |
| R7        | 7       | Yleiskäyttöinen datarekisteri        |
| R8        | 8       | Yleiskäyttöinen datarekisteri        |
| R9        | 9       | Yleiskäyttöinen datarekisteri        |
| R10       | 10      | Yleiskäyttöinen datarekisteri        |
| R11       | 11      | Yleiskäyttöinen datarekisteri        |
| R12       | 12      | Yleiskäyttöinen datarekisteri        |
| R13       | 13      | Yleiskäyttöinen datarekisteri        |
| R14       | 14      | Yleiskäyttöinen datarekisteri        |
| R15       | 15      | Yleiskäyttöinen datarekisteri        |

## 2.2 Erikoisrekisterit

| Rekisteri | Indeksi | Kuvaus                                                                         |
| --------- | ------- | ------------------------------------------------------------------------------ |
| FP        | 16      | Frame Pointer — aliohjelman pinokehyksen pohja                                 |
| SP        | 17      | Stack Pointer — pinon huippu, pino kasvaa alasпäin                             |
| PC        | —       | Program Counter — seuraavan käskyn osoite (ei suoraan käytettävissä käskyissä) |
| SR        | —       | Status Register — tilaliput (ks. 2.4)                                          |

## 2.3 Järjestelmärekisterit

Vain Kernel-tilassa kirjoitettavissa (SMPR, STMR -käskyillä).

| Rekisteri | Kuvaus                                                                       |
| --------- | ---------------------------------------------------------------------------- |
| MPR       | Memory Protection Register — User-muistin alaraja                            |
| TMR       | Timer Register — ajastinkeskeytyksen väli **mikrosekunneissa** (0 = pois)    |
| CTMR      | Clock Timer Register — kellokeskeytyksen väli **millisekunteina** (0 = pois) |

## 2.4 Tilarekisteri (SR)

SR on 16-bittinen, josta bitit 0–5 ovat käytössä.

| Bitti | Nimi | Kuvaus                                                                  |
| ----- | ---- | ----------------------------------------------------------------------- |
| 0     | Z    | **Zero** — 1 jos operaation tulos on nolla                              |
| 1     | N    | **Negative** — 1 jos tuloksen ylin bitti (bitti 15) on 1                |
| 2     | C    | **Carry** — 1 jos tapahtui etumerkitön ylivuoto (unsigned overflow)     |
| 3     | V    | **Overflow** — 1 jos tapahtui etumerkillinen ylivuoto (signed overflow) |
| 4     | I    | **Interrupt Enable** — 1 = laitteistokeskeytykset sallittu, 0 = estetty |
| 5     | P    | **Privilege** — 1 = Kernel Mode, 0 = User Mode                          |
| 6–15  | —    | Varattu (tulee olla 0)                                                  |

**V-lipun laskenta:**
- ADD/ADC: `V = ((a ^ tulos) & (b ^ tulos) & 0x8000) != 0`
- SUB/CMP: `V = ((a ^ b) & (a ^ tulos) & 0x8000) != 0`

---

# 3. Suojaustilat

## 3.1 Kernel Mode (P = 1)

- Täysi pääsy kaikkeen muistiin (0x0000–0xFFFF)
- Kaikki käskyt sallittu
- Aktiivinen käynnistyksen ja keskeytysten aikana

## 3.2 User Mode (P = 0)

- Muistipääsy rajoitettu: vain osoitteet ≥ MPR sallittu
  - **Poikkeus:** Video RAM ($F800–$FF7F) on aina kirjoitettavissa
- Etuoikeutetut käskyt (K) laukaisevat Int 4 (Privilege Violation)
- Siirtyminen User → Kernel tapahtuu vain keskeytysten kautta

---

# 4. Muistikartta

| Osoitealue    | Koko         | Kuvaus                                                      |
| ------------- | ------------ | ----------------------------------------------------------- |
| $0000 – $000F | 16 sanaa     | Keskeytysvektoritaulukko                                    |
| $0010 – $001F | 16 sanaa     | Kellokello MMIO (vain luettava, paitsi $001B kirjoitettava) |
| $0020 – $0021 | 2 sanaa      | Näppäimistö MMIO (KBD_DATA, KBD_STATUS)                     |
| $0022         | 1 sana       | Satunnaisluku MMIO (RAND_MMIO, LFSR)                        |
| $0023 – $00FF | 221 sanaa    | Käyttöjärjestelmän varattu alue                             |
| $0100 – $01FF | 256 sanaa    | Bootloaderin latausalue                                     |
| $0200 – $F7FF | 62 976 sanaa | Vapaa RAM (ohjelmat ja data)                                |
| $F800 – $FF7F | 1920 sanaa   | Video RAM (80 × 24, MMIO)                                   |
| $FF80 – $FFFF | 128 sanaa    | Kernel Stack                                                |

## 4.1 Keskeytysvektoritaulukko ($0000–$000F)

Jokainen vektoripaikka sisältää keskeytyskäsittelijän muistiosoitteen.

| Vektori | Osoite      | Keskeytys                    |
| ------- | ----------- | ---------------------------- |
| 0       | $0000       | Jako nollalla                |
| 1       | $0001       | Tuntematon käsky             |
| 2       | $0002       | Pinon ylivuoto               |
| 3       | $0003       | Debug / Breakpoint           |
| 4       | $0004       | Privilege Violation          |
| 5       | $0005       | Memory Access Fault          |
| 6       | $0006       | Näppäimistökeskeytys         |
| 7       | $0007       | Ajastinkeskeytys             |
| 8       | $0008       | Prosessin lopetus (EXIT)     |
| 9       | $0009       | Kellokeskeytys (CTMR)        |
| 10–15   | $000A–$000F | Varattu tulevaisuutta varten |

## 4.1b Kellokello MMIO ($0010–$001F)

Osoitteet ovat vain luettavia lukuun ottamatta $001B (kirjoitus asettaa CTMR-arvon).
Lukeminen palauttaa reaaliaikaisen järjestelmäkellon arvon.
Uptime-laskuri on 32-bittinen *simuloitu* sekuntilaskuri. Se lasketaan
käskyjen suoritussyklien kertymästä (ks. luku 12 Suoritusajat), ei reaaliajasta.

| Osoite      | Vakio              | Kuvaus                                                     |
| ----------- | ------------------ | ---------------------------------------------------------- |
| $0010       | CLOCK_YEAR         | Vuosi (esim. 2026)                                         |
| $0011       | CLOCK_MONTH        | Kuukausi (1–12)                                            |
| $0012       | CLOCK_DAY          | Päivä (1–31)                                               |
| $0013       | CLOCK_HOUR         | Tunti (0–23, 24 h)                                         |
| $0014       | CLOCK_MINUTE       | Minuutti (0–59)                                            |
| $0015       | CLOCK_SECOND       | Sekunti (0–59)                                             |
| $0016       | CLOCK_MILLIS       | Millisekunti (0–999)                                       |
| $0017       | UPTIME_W3          | 64-bit sekuntilaskuri bitit 48–63 (korkein)                |
| $0018       | UPTIME_W2          | 64-bit sekuntilaskuri bitit 32–47                          |
| $0019       | UPTIME_W1          | 64-bit sekuntilaskuri bitit 16–31                          |
| $001A       | UPTIME_W0          | 64-bit sekuntilaskuri bitit 0–15 (matalin)                 |
| $001B       | CLOCK_INT_INTERVAL | CTMR: kellokeskeytyksen väli ms (0 = pois, luku/kirjoitus) |
| $001C–$001F | —                  | Varattu                                                    |

## 4.1c Näppäimistö MMIO ($0020–$0021)

| Osoite | Vakio      | Kuvaus                                                                  |
| ------ | ---------- | ----------------------------------------------------------------------- |
| $0020  | KBD_DATA   | Lue: pops seuraava näppäintapahtuma puskurista (0 jos puskuri on tyhjä) |
| $0021  | KBD_STATUS | Lue: tapahtumien määrä puskurissa (0 = tyhjä)                           |

**Skannikoodin rakenne (KBD_DATA):**

| Bitit | Kuvaus                                         |
| ----- | ---------------------------------------------- |
| 6–0   | Näppäinkoodi (ASCII-arvo tai scan code, 0–127) |
| 7     | 0 = painallus, 1 = vapautus                    |

Esimerkki: `A` painetaan → KBD_DATA = 0x41; `A` vapautetaan → KBD_DATA = 0xC1.
Keskeytys **Int 6** laukeaa jokaisesta painalluksesta ja vapautuksesta (kun `I = 1`).

## 4.1d Satunnaisluku MMIO ($0022)

| Osoite | Vakio     | Kuvaus                                                                |
| ------ | --------- | --------------------------------------------------------------------- |
| $0022  | RAND_MMIO | Lue: seuraava 16-bittinen pseudosatunnaisluku; kirjoita: aseta siemen |

Toteutus: 16-bittinen Galois LFSR, polynomi x¹⁶+x¹⁵+x¹³+x⁴+1 (mask 0xB400). Jakso 65 535.
Kirjoittaminen asettaa siemenen (arvo 0 nollataan arvoon 1 automaattisesti).

## 4.2 Video RAM ($F800–$FF7F)

Näyttö on 80 saraketta × 24 riviä = 1920 sanaa. Ensimmäinen osoite ($F800) vastaa ruudun vasenta ylänurkkaa. Osoitteet kasvavat vasemmalta oikealle, rivi kerrallaan.

Yhden sanan bittirakenne:

| Bitit   | Kuvaus                              |
| ------- | ----------------------------------- |
| 0 – 7   | ASCII-merkkikoodi (0–127)           |
| 8 – 10  | Edustaväri, FG (3 bittiä = 8 väriä) |
| 11 – 13 | Taustaväri, BG (3 bittiä = 8 väriä) |
| 14      | Lihavointi (1 = päällä)             |
| 15      | Varattu (0)                         |

Värikoodit (FG, bitit 13–15):

| Koodi | Väri      |
| ----- | --------- |
| 0     | Musta     |
| 1     | Punainen  |
| 2     | Vihreä    |
| 3     | Keltainen |
| 4     | Sininen   |
| 5     | Magenta   |
| 6     | Syaani    |
| 7     | Valkoinen |

User Mode saa aina lukea ja kirjoittaa Video RAM -aluetta riippumatta MPR:n arvosta.

---

# 5. Keskeytykset

## 5.1 Keskeytyksen laukeaminen

Kun keskeytys tapahtuu, CPU suorittaa atomisesti:

1. `PUSH PC` — nykyinen ohjelmalaskuri pinoon
2. `PUSH SR` — tilarekisteri pinoon
3. `P ← 1` — siirtyminen Kernel-tilaan
4. `I ← 0` — lisäkeskeytykset estetään
5. `PC ← [vektori]` — käsittelijän osoite ladataan vektoritaulukosta

## 5.2 Paluu keskeytyksestä

`IRET`-käsky suorittaa käänteisen operaation:

1. `POP SR` — palauttaa tilaliput (mukaan lukien P- ja I-bitit)
2. `POP PC` — palauttaa ohjelmalaskurin

Tämä palauttaa automaattisesti edellisen suojaustilan (User/Kernel) ja keskeytysasetuksen.

## 5.3 Keskeytysten luokittelu

| Tyyppi           | Numerot | Laukeaistapa                                            |
| ---------------- | ------- | ------------------------------------------------------- |
| Virhepoikkeukset | 0–2     | Automaattinen: DIV/0, tuntematon opcode, stack overflow |
| Ohjelmistokesk.  | 3, 8    | `INT`-käskyllä tai `EXIT`-käskyllä                      |
| Suojausvirheet   | 4–5     | Automaattinen: käsky- tai muistisuojausrikkomus         |
| Laitekesk.       | 6–7     | Laitteiston laukaisema (näppäimistö, käskylaskuri)      |
| Kellokeskeytys   | 9       | Reaaliaikatimer (CTMR ms-väli, `SCTMR`-käsky)           |
| Varattu          | 10–15   | Tulevaisuuden käyttöön                                  |

## 5.4 Ajastinkeskeytys (TMR)

- TMR-rekisteri määrittää aikavälin **mikrosekunneissa** (simuloitua aikaa)
- TMR = 0 → ajastin pois päältä
- Int 7 laukeaa kun simuloitu aika saavuttaa seuraavan laukaisuhetken **ja** `I = 1`
- Laukaisuhetki alustetaan STMR-käskyllä: `next = kertyma + TMR`
- Laukaisun jälkeen laukaisuhetki siirtyy eteenpäin: `next += TMR`
- Ajastinta ei tarkisteta jos I = 0

## 5.5 Kellokeskeytys (CTMR, Int 9)

- CTMR-rekisteri määrittää aikavälin **millisekunteina** (simuloitua aikaa)
- CTMR = 0 → kellokeskeytys pois päältä
- Int 9 laukeaa kun simuloitu aika saavuttaa seuraavan laukaisuhetken **ja** `I = 1`
- Laukaisuhetki alustetaan SCTMR-käskyllä: `next = kertyma + CTMR × 1000 µs`
- Asetetaan `SCTMR reg` -käskyllä (Kernel-tila); myös $001B-kirjoitus asettaa CTMR:n

---

# 6. Suoritussykli

Jokainen `step()` suorittaa yhden käskyn seuraavassa järjestyksessä:

| Vaihe | Nimi      | Kuvaus                                                           |
| ----- | --------- | ---------------------------------------------------------------- |
| 1     | FETCH     | Lue opcode-sana osoitteesta [PC] ja 0–2 operandisanaa            |
| 2     | PRIVILEGE | Tarkista käskyoikeus (Kernel-käsky User-tilassa → Int 4)         |
| 3     | MEMORY    | Tarkista muistiviittausten laillisuus (User: addr < MPR → Int 5) |
| 4     | EXECUTE   | Suorita käsky, päivitä rekisterit ja liput                       |
| 5     | PC UPDATE | PC ← PC + käskyn sanamäärä                                       |
| 6     | TIMER     | Tarkista ja laukaise ajastinkeskeytys (TMR) tarvittaessa         |
| 7     | UPTIME    | Kasvata 64-bittista sekuntilaskuria tarvittaessa                 |
| 8     | CLOCK INT | Tarkista ja laukaise kellokeskeytys (CTMR) tarvittaessa          |

Jos vaiheissa 2–3 tapahtuu virhe, suoritetaan vastaava keskeytys eikä vaiheita 4–6 tehdä.

---

# 7. Käskykanta

## 7.1 Operandityypit

| Merkintä | Kuvaus                                                                     |
| -------- | -------------------------------------------------------------------------- |
| `reg`    | Rekisteri: R0–R15, FP, SP (koodattu 5-bittisellä indeksillä, R0=0 … SP=17) |
| `regD`   | Kohderekisteri (destination)                                               |
| `regS`   | Lähderekisteri (source)                                                    |
| `imm`    | 16-bittinen välitön arvo (immediate)                                       |
| `addr`   | 16-bittinen absoluuttinen muistiosoite                                     |

Käskyissä kohde (destination) on aina **ensimmäisenä** ja lähde (source) **toisena**.

## 7.2 Lippujen merkintätapa

| Merkintä | Selitys                                      |
| -------- | -------------------------------------------- |
| `—`      | Käsky ei muuta lippuja                       |
| `ZNCV`   | Päivittää nimetyt liput tuloksen perusteella |
| `ZN——`   | Päivittää vain Z ja N; C ja V nollataan      |
| `ZNC—`   | Päivittää Z, N ja C; V nollataan             |

## 7.3 Opcode-bittikentät

Jokainen opcode on 16-bittinen sana jolla on neljä bittikenttiä:

```
 Bitti 15   14–12   11–8    7–6    5–0
      P      GRP     ID     OPS    (varattu, 0)
```

| Kenttä | Bitit | Kuvaus                            |
| ------ | ----- | --------------------------------- |
| P      | 15    | Oikeusbitti: 0 = User, 1 = Kernel |
| GRP    | 14–12 | Käskyryhmä (1–7)                  |
| ID     | 11–8  | Käskyindeksi ryhmässä (0–15)      |
| OPS    | 7–6   | Operandien lukumäärä (0–2)        |

**Koodauskaava:** `opcode = (P << 15) | (GRP << 12) | (ID << 8) | (OPS << 6)`

Käskyn koko sanoina on `1 + OPS` (opcode-sana + operandisanat).

**Ryhmäkoodit (GRP):**

| GRP | P   | Opcode-alue   | Ryhmä                                               |
| --- | --- | ------------- | --------------------------------------------------- |
| 0   | 0   | 0x0000–0x0FFF | Virheellinen (nollamuisti, ei koskaan suoritettava) |
| 1   | 0   | 0x1000–0x1FFF | Tiedonsiirto                                        |
| 2   | 0   | 0x2000–0x2FFF | Aritmetiikka                                        |
| 3   | 0   | 0x3000–0x3FFF | Logiikka                                            |
| 4   | 0   | 0x4000–0x4FFF | Pino                                                |
| 5   | 0   | 0x5000–0x5FFF | Ohjausrakenne                                       |
| 6   | 0   | 0x6000–0x6FFF | Keskeytykset (User)                                 |
| 7   | 0   | 0x7000–0x7FFF | Järjestelmä (User)                                  |
| 6   | 1   | 0xE000–0xEFFF | Keskeytykset (Kernel)                               |
| 7   | 1   | 0xF000–0xFFFF | Järjestelmä (Kernel)                                |

## 7.4 Tiedonsiirtokäskyt

| Opcode | Käsky      | Operandit  | Tila | Liput | Kuvaus                             |
| ------ | ---------- | ---------- | ---- | ----- | ---------------------------------- |
| 0x1080 | LOAD       | reg, imm   | U    | —     | `reg ← imm`                        |
| 0x1180 | CPY        | regD, regS | U    | —     | `regD ← regS`                      |
| 0x1280 | READ       | reg, addr  | U    | —     | `reg ← [addr]`                     |
| 0x1380 | STORE      | reg, addr  | U    | —     | `[addr] ← reg`                     |
| 0x1480 | READ_IND   | regD, regS | U    | —     | `regD ← [regS]`                    |
| 0x1580 | STORE_IND  | regD, regS | U    | —     | `[regD] ← regS`                    |
| 0x1680 | READ_REL   | reg, imm   | U    | —     | `reg ← [FP + imm]`                 |
| 0x1780 | STORE_REL  | reg, imm   | U    | —     | `[FP + imm] ← reg`                 |
| 0x1880 | STOREI     | imm, addr  | U    | —     | `[addr] ← imm`                     |
| 0x1980 | STOREI_IND | regD, imm  | U    | —     | `[regD] ← imm`                     |
| 0x1A80 | STOREI_REL | imm, offs  | U    | —     | `[FP + offs] ← imm`                |
| 0x1BC0 | FILL       | rS, rE, rV | U    | —     | `[rS..rE] ← rV` (täytä muistialue) |

> **Huom:** Assemblerissa käytetään `LOAD`- ja `STORE`-käskyistä `[...]`-hakasulkunotaatiota. Assembler valitsee oikean konekielikäskyn (READ/STORE/READ_IND/STORE_IND/READ_REL/STORE_REL/STOREI jne.) automaattisesti syntaksin perusteella. Suoria `READ_IND`, `STORE_REL` jne. -mnemoniikkita ei suositella kirjoittaa käsin.

**LOAD** lataa 16-bittisen välittömän arvon (immediate) suoraan rekisteriin. Tämä on ainoa tapa saada vakioarvo rekisteriin. Käsky on 3 sanaa pitkä: opcode, rekisteri-indeksi ja 16-bittinen arvo.

**CPY** kopioi lähderekisterin arvon kohderekisteriin. Lähderekisterin sisältö säilyy muuttumattomana. Käytetään rekisterien väliseen tiedonsiirtoon, esimerkiksi pinon osoittimen kopiointiin yleisrekisteriin.

**READ** lukee muistiosoitteesta yhden sanan ja tallentaa sen rekisteriin. Osoite annetaan absoluuttisena 16-bittisenä arvona käskyn operandina. User-tilassa osoitteen on oltava ≥ MPR tai Video RAM -alueella.

**STORE** kirjoittaa rekisterin arvon annettuun absoluuttiseen muistiosoitteeseen. Samat muistisuojasäännöt pätevät kuin READ-käskyssä.

**READ_IND** lukee muistista epäsuorasti: lähderekisterin arvo tulkitaan muistiosoitteeksi, ja kyseisestä osoitteesta luettu sana tallennetaan kohderekisteriin. Käytetään osoitintietorakenteiden (taulukot, listat) käsittelyyn.

**STORE_IND** kirjoittaa lähderekisterin arvon muistiin osoitteeseen, jonka kohderekisteri ilmoittaa. Tämä on epäsuoran lukemisen vastapari ja mahdollistaa osoittimen kautta kirjoittamisen.

**READ_REL** lukee muistista kehysosoittimen (FP) suhteen: osoite lasketaan summana FP + imm. Käytetään aliohjelmien paikallisten muuttujien ja parametrien käsittelyyn pinokehyksessä.

**STORE_REL** kirjoittaa rekisterin arvon FP-suhteelliseen muistiosoitteeseen (FP + imm). Käytetään paikallisten muuttujien tallentamiseen aliohjelman pinokehykseen.

**FILL** täyttää muistialueen `[rS..rE]` (inklusiivinen molemmista päistä) rekisterin `rV` arvolla. Täyttö etenee osoitteesta `rS` osoitteeseen `rE` yksi sana kerrallaan. Jos `rS > rE`, täyttö kiertää muistin yli: ensin `rS → 0xFFFF`, sitten `0x0000 → rE`. Lippuja ei muokata. Käytetään taulukkojen alustamiseen, muistialueiden nollaamiseen ja Video-RAM:n tyhjentämiseen nopeasti.

> **Kirjoitussuojaus:** Ennen täytön aloitusta FILL tarkistaa, että koko kohdealue `[rS..rE]` on kirjoitettavissa. Jos jokin osoite kuuluu kirjoitussuojattuun alueeseen (MMIO-rekisterit, ROM), prosessori nostaa `ReadOnlyMemoryError`-keskeytyksen (INT 5) ennen kuin yhtäkään sanaa on kirjoitettu. Tämä koskee kaikkia suoritustiloja — myös kernel-tilaa.

```asm
; Täytä taulukko 0x0400–0x043F arvolla 0xFFFF
LOAD  R0, 0x0400     ; alkuosoite
LOAD  R1, 0x043F     ; loppuosoite (inklusiivinen)
LOAD  R2, 0xFFFF     ; täytettävä arvo
FILL  R0, R1, R2

; Tyhjennä VRAM (arvo 0x0000 = tyhjä merkki, musta tausta)
LOAD  R0, VRAM_START ; 0xF800
LOAD  R1, VRAM_END   ; 0xFF7F
LOAD  R2, 0
FILL  R0, R1, R2
```

## 7.5 Aritmetiikkakäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                                                      |
| ------ | ----- | ---------- | ---- | ----- | ----------------------------------------------------------- |
| 0x2080 | ADD   | regD, regS | U    | ZNCV  | `regD ← regD + regS`                                        |
| 0x2180 | SUB   | regD, regS | U    | ZNCV  | `regD ← regD − regS`                                        |
| 0x2280 | MUL   | regD, regS | U    | ZNCV  | `regD ← regD × regS`                                        |
| 0x2380 | DIV   | regD, regS | U    | ZNCV  | `regD ← regD / regS` (kokonaislukujako, Int 0 jos regS = 0) |
| 0x2480 | CMP   | regA, regB | U    | ZNCV  | Laskee `regA − regB`, asettaa liput, tulosta ei tallenneta  |
| 0x2580 | ADC   | regD, regS | U    | ZNCV  | `regD ← regD + regS + C`                                    |

**ADD** laskee kahden rekisterin summan ja tallentaa tuloksen kohderekisteriin. Päivittää kaikki aritmetiikkaliput: Z (tulos nolla), N (ylin bitti 1), C (etumerkitön ylivuoto) ja V (etumerkillinen ylivuoto). Käytetään yleiseen kokonaislukuaritmetiikkaan ja osoitelaskentaan.

**ADC** (Add with Carry) laskee kahden rekisterin summan lisättynä nykyisellä carry-lipulla. Mahdollistaa 32-bittisen (tai suuremman) yhteenlaskun ketjuttamalla useita ADC-käskyjä: ensin ADD alemmat sanat, sitten ADC ylemmät sanat. Päivittää kaikki aritmetiikkaliput.

**SUB** vähentää lähderekisterin arvon kohderekisteristä. Carry-lippu asettuu, jos vähennettävä on suurempi kuin vähennettävä (etumerkittömässä mielessä, eli borrow tapahtui). V-lippu ilmaisee etumerkillisen ylivuodon.

**MUL** kertoo kohderekisterin lähderekisterillä ja tallentaa tuloksen alimmat 16 bittiä kohderekisteriin. Ylivuoto (tulos > 0xFFFF) asettaa C-lipun. Käsittelee operandeja etumerkittöminä kokonaislukuina.

**DIV** suorittaa kokonaislukujaon (tasajaon). Jos jakaja (regS) on nolla, käsky laukaisee keskeytyksen Int 0 (Division by Zero) eikä rekistereitä muokata. Jakojäännös ei tallennu — käytä erillistä laskentaa modulo-operaatioon.

**CMP** laskee regA − regB ja asettaa liput aivan kuten SUB, mutta erotusta ei tallenneta kumpaankaan rekisteriin. Käytetään aina ennen ehdollisia hyppykäskyjä (JZ, JLT, JGT jne.) kahden arvon vertailuun.

## 7.6 Logiikka- ja bittikäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                                        |
| ------ | ----- | ---------- | ---- | ----- | --------------------------------------------- |
| 0x3080 | AND   | regD, regS | U    | ZN——  | `regD ← regD AND regS`                        |
| 0x3180 | OR    | regD, regS | U    | ZN——  | `regD ← regD OR regS`                         |
| 0x3280 | XOR   | regD, regS | U    | ZN——  | `regD ← regD XOR regS`                        |
| 0x3340 | NOT   | reg        | U    | ZN——  | `reg ← NOT reg` (bittitason komplementti)     |
| 0x3480 | SHL   | regD, regS | U    | ZNC—  | `regD ← regD << regS` (looginen vasen siirto) |
| 0x3580 | SHR   | regD, regS | U    | ZNC—  | `regD ← regD >> regS` (looginen oikea siirto) |

**AND** suorittaa bittitason JA-operaation kohde- ja lähderekisterin välillä. Tulos tallennetaan kohderekisteriin. Käytetään tyypillisesti bittimaskien soveltamiseen — esimerkiksi yksittäisen bitin tarkistamiseen tai nollaamiseen. Päivittää Z- ja N-liput; C ja V nollataan.

**OR** suorittaa bittitason TAI-operaation. Käytetään bittien asettamiseen päälle: esimerkiksi lippujen tai attribuuttien yhdistämiseen yhdeksi sanaksi. Päivittää Z- ja N-liput; C ja V nollataan.

**XOR** suorittaa bittitason poissulkeva-TAI-operaation. XOR samalla arvolla nollaa rekisterin (`XOR R0, R0` → R0 = 0). Käytetään myös bittien kääntämiseen ja yksinkertaiseen salaukseen. Päivittää Z- ja N-liput; C ja V nollataan.

**NOT** kääntää rekisterin kaikki bitit (yhden komplementti): jokainen 0 muuttuu 1:ksi ja päinvastoin. Operoi vain yhteen rekisteriin. Käytetään bittimaskien inversointiin ja kahden komplementin laskemiseen (NOT + ADD #1). Päivittää Z- ja N-liput; C ja V nollataan.

**SHL** (Shift Left) siirtää kohderekisterin bittejä vasemmalle lähderekisterin ilmoittaman määrän verran. Oikealta täytetään nollilla. Viimeinen ulos siirtynyt bitti tallennetaan C-lippuun. Vasen siirto yhdellä vastaa kertomista kahdella. Päivittää Z-, N- ja C-liput; V nollataan.

**SHR** (Shift Right) siirtää bittejä oikealle loogisesti (vasemmalta täytetään nollilla). Viimeinen ulos siirtynyt bitti tallennetaan C-lippuun. Oikea siirto yhdellä vastaa etumerkitöntä jakoa kahdella. Päivittää Z-, N- ja C-liput; V nollataan.

## 7.7 Pinokäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                    |
| ------ | ----- | ---------- | ---- | ----- | ------------------------- |
| 0x4040 | PUSH  | reg        | U    | —     | `[SP] ← reg; SP ← SP − 1` |
| 0x4140 | POP   | reg        | U    | —     | `SP ← SP + 1; reg ← [SP]` |
| 0x4280 | SWSP  | regD, regS | U    | —     | `regD ← SP; SP ← regS`    |

**PUSH** tallettaa rekisterin arvon pinoon. Ensin kirjoitetaan arvo nykyiseen pinopaikkaan [SP], sitten SP:tä vähennetään yhdellä (pino kasvaa alaspäin kohti pienempiä osoitteita). User-tilassa, jos SP laskee alle MPR-rajan, laukeaa Int 2 (Stack Overflow). Käytetään arvojen väliaikaiseen tallentamiseen, aliohjelmakutsujen parametrien välittämiseen ja rekisterien pelastamiseen.

**POP** palauttaa arvon pinosta rekisteriin. Ensin SP:tä kasvatetaan yhdellä, sitten luetaan arvo osoitteesta [SP]. PUSH- ja POP-parit ovat käänteisiä operaatioita. Käytetään arvojen palauttamiseen ja aliohjelmista paluuseen (RET käyttää sisäisesti POP PC:tä).

**SWSP** (Swap Stack Pointer) vaihtaa pinorekisterin atomisesti: tallentaa nykyisen SP:n kohderekisteriin ja lataa uuden SP:n lähderekisteristä. Tämä on yksi atominen operaatio, joten keskeytysten ei tarvitse olla estettyinä. Käytetään ensisijaisesti käyttöjärjestelmän kontekstinvaihtorutiinissa prosessien pinojen vaihtamiseen.

## 7.8 Ohjauskäskyt

| Opcode | Käsky | Operandit | Tila | Liput | Kuvaus                         |
| ------ | ----- | --------- | ---- | ----- | ------------------------------ |
| 0x5040 | JUMP  | addr      | U    | —     | `PC ← addr`                    |
| 0x5140 | CALL  | addr      | U    | —     | `PUSH paluuosoite; PC ← addr`  |
| 0x5200 | RET   | —         | U    | —     | `POP PC` (paluu aliohjelmasta) |

**JUMP** siirtää suorituksen ehdottomasti annettuun osoitteeseen. PC ladataan suoraan operandina annetulla osoitteella. Käytetään silmukoiden, ehdottomien haarojen ja goto-tyypisten siirtymien toteuttamiseen.

**CALL** kutsuu aliohjelmaa: tallentaa nykyisen paluuosoitteen (seuraavan käskyn osoite) pinoon PUSH-operaatiolla ja siirtää suorituksen annettuun osoitteeseen. Paluuosoite on käskyn jälkeinen osoite, jotta RET osaa palata oikeaan kohtaan. Käytetään funktioiden ja aliohjelmien kutsumiseen.

**RET** palaa aliohjelmasta: palauttaa pinosta paluuosoitteen PC:hen (POP PC). Jokaista CALL-käskyä vastaa RET aliohjelman lopussa. Ohjelmoijan vastuulla on varmistaa, että pino on oikeassa kunnossa ennen RET:iä.

### Ehdolliset hypyt

Käytetään CMP-käskyn jälkeen. Etumerkillinen vertailu perustuu N- ja V-lippuihin.

| Opcode | Käsky | Ehto          | Kuvaus                        | Alias |
| ------ | ----- | ------------- | ----------------------------- | ----- |
| 0x5340 | JZ    | Z = 1         | Jump if Equal                 | JE    |
| 0x5440 | JNZ   | Z = 0         | Jump if Not Equal             | JNE   |
| 0x5540 | JLT   | N ≠ V         | Jump if Less Than (signed)    | —     |
| 0x5640 | JGT   | Z = 0 ∧ N = V | Jump if Greater Than (signed) | —     |
| 0x5740 | JLE   | Z = 1 ∨ N ≠ V | Jump if Less or Equal         | —     |
| 0x5840 | JGE   | N = V         | Jump if Greater or Equal      | —     |

**JZ** (Jump if Zero / Jump if Equal) hyppää annettuun osoitteeseen, jos Z-lippu on asetettu. CMP-käskyn jälkeen tämä tarkoittaa, että verrattavat arvot ovat yhtä suuret. Assemblerissa voi käyttää myös aliasta JE. Jos ehto ei täyty, suoritus jatkuu normaalisti seuraavasta käskystä.

**JNZ** (Jump if Not Zero / Jump if Not Equal) hyppää, jos Z-lippu ei ole asetettu. CMP:n jälkeen tämä tarkoittaa, että arvot eivät ole yhtä suuret. Alias: JNE. Käytetään tyypillisesti silmukoissa tarkistamaan, onko laskuri nollassa.

**JLT** (Jump if Less Than) hyppää, jos etumerkillinen vertailu osoittaa ensimmäisen operandin olevan pienempi kuin toinen. Ehto N ≠ V havaitsee tämän oikein myös ylivuototilanteissa.

**JGT** (Jump if Greater Than) hyppää, jos ensimmäinen operandi on etumerkillisesti suurempi kuin toinen. Ehto Z = 0 ∧ N = V varmistaa, että arvot eivät ole yhtä suuret ja suuruussuhde on oikein.

**JLE** (Jump if Less or Equal) hyppää, jos ensimmäinen operandi on pienempi tai yhtä suuri kuin toinen. Ehto Z = 1 ∨ N ≠ V kattaa sekä yhtäsuuruuden että pienemmuuden.

**JGE** (Jump if Greater or Equal) hyppää, jos ensimmäinen operandi on suurempi tai yhtä suuri kuin toinen. Ehto N = V on yksinkertainen: normaalitilanteessa positiivinen erotus (N=0, V=0) ja ylivuototilanteessa molemmat ovat 1.

## 7.9 Keskeytyskäskyt

| Opcode | Käsky | Operandit | Tila | Liput | Kuvaus                                        |
| ------ | ----- | --------- | ---- | ----- | --------------------------------------------- |
| 0x6040 | INT   | imm       | U    | —     | Ohjelmallinen keskeytys (syscall). imm = 0–8. |
| 0xE100 | IRET  | —         | K    | —     | Paluu keskeytyksestä: `POP SR; POP PC`        |
| 0xE200 | STI   | —         | K    | —     | Salli keskeytykset: `I ← 1`                   |
| 0xE300 | CLI   | —         | K    | —     | Estä keskeytykset: `I ← 0`                    |
| 0xF000 | HALT  | —         | K    | —     | Pysäytä prosessori                            |
| 0x7500 | EXIT  | —         | U    | —     | Prosessin hallittu lopetus, laukaisee Int 8   |

**INT** laukaisee ohjelmallisen keskeytyksen annetulla vektorinumerolla (0–8). CPU suorittaa normaalin keskeytysprotokollan: tallentaa PC:n ja SR:n pinoon, siirtyy Kernel-tilaan ja estää keskeytykset. Käytetään järjestelmäkutsujen (syscall) toteuttamiseen — User-tilan ohjelma pyytää palvelua kerneliltä INT-käskyllä.

**IRET** (Interrupt Return) palaa keskeytyskäsittelijästä. Palauttaa ensin SR:n ja sitten PC:n pinosta. Koska SR sisältää P-bitin (privilege) ja I-bitin (interrupt enable), IRET palauttaa automaattisesti edellisen suojaustilan ja keskeytysasetuksen. Vaatii Kernel-tilan.

**STI** (Set Interrupt) asettaa SR:n I-bitin arvoon 1, mikä sallii laitteistokeskeytykset (näppäimistö, ajastin). Käytetään tyypillisesti käyttöjärjestelmän alustuksen lopussa, kun keskeytyskäsittelijät ovat paikoillaan. Vaatii Kernel-tilan.

**CLI** (Clear Interrupt) nollaa SR:n I-bitin, mikä estää kaikki laitteistokeskeytykset. Käytetään kriittisten osioiden suojaamiseen — esimerkiksi kun muokataan jaettuja tietorakenteita, joita keskeytykset voisivat häiritä. Vaatii Kernel-tilan.

**HALT** pysäyttää prosessorin. Suoritus päättyy ja CPU ei jatka käskyjen noutamista. Käytetään käyttöjärjestelmän sammutuksessa tai kriittisen virheen yhteydessä. Vaatii Kernel-tilan.

**EXIT** lopettaa nykyisen käyttäjäprosessin hallitusti laukaisemalla keskeytyksen Int 8. Tämä siirtää ohjauksen käyttöjärjestelmän prosessinhallinnan käsittelijään, joka voi siivota prosessin resurssit ja siirtyä seuraavaan prosessiin. Toisin kuin HALT, EXIT on sallittu User-tilassa.

## 7.10 Järjestelmä- ja I/O-käskyt

| Opcode | Käsky  | Operandit  | Tila | Liput | Kuvaus                                                |
| ------ | ------ | ---------- | ---- | ----- | ----------------------------------------------------- |
| 0xF180 | DREAD  | regD, regS | K    | —     | `regD ← storage[regS]`                                |
| 0xF280 | DWRITE | regS, regD | K    | —     | `storage[regD] ← regS`                                |
| 0xF340 | SMPR   | reg        | K    | —     | `MPR ← reg`                                           |
| 0xF440 | STMR   | reg        | K    | —     | `TMR ← reg`                                           |
| 0xF540 | SCTMR  | reg        | K    | —     | `CTMR ← reg` (kellokeskeytyksen väli millisekunteina) |
| 0x7780 | TSL    | reg, addr  | U    | ZN——  | `reg ← [addr]; [addr] ← 1` (atominen)                 |
| 0x7F00 | NOP    | —          | U    | —     | Ei tee mitään                                         |

> **Näppäimistön lukeminen:** Ei erillinen käsky. Luetaan MMIO-osoitteesta `READ reg, [KBD_DATA]` (0x0020). Ks. kohta 4.1c.

**DREAD** (Device Read) lukee yhden sanan tallennuslaitteelta (block device). Lähderekisteri sisältää lukuosoitteen tallennuslaitteen muistiavaruudessa (0x0000–0xFFFF), ja luettu arvo tallennetaan kohderekisteriin. Käytetään käyttöjärjestelmän bootloaderissa ja levyoperaatioissa. Vaatii Kernel-tilan.

**DWRITE** (Device Write) kirjoittaa lähderekisterin arvon tallennuslaitteelle kohderekisterin ilmoittamaan osoitteeseen. Käytetään datan pysyvään tallentamiseen — esimerkiksi tiedostojärjestelmän toteutuksessa. Vaatii Kernel-tilan.

**SMPR** (Set MPR) asettaa muistisuojarekisterin (Memory Protection Register) arvon. MPR määrittää User-tilan muistialueen alarajan: User-tilassa kaikki muistiosoitteet < MPR ovat kiellettyjä (paitsi Video RAM). Käytetään käyttöjärjestelmässä prosessin käynnistyksen yhteydessä eristämään käyttäjäprosessi kernel-muistista. Vaatii Kernel-tilan.

**STMR** (Set TMR) asettaa ajastinrekisterin (Timer Register) arvon. TMR määrittää, kuinka monen käskyn välein ajastinkeskeytys (Int 7) laukeaa. Arvo 0 kytkee ajastimen pois päältä. Käytetään preemptiivisen moniajon toteuttamiseen: käyttöjärjestelmä asettaa aikavälin, ja ajastinkeskeytys pakottaa prosessinvaihdon tasaisin välein. Vaatii Kernel-tilan.

**SCTMR** (Set Clock Timer Register) asettaa kellokeskeytysrekisterin arvon millisekunteina. Kun CTMR ms on kulunut, laukeaa Int 9 (jos I = 1). Arvo 0 kytkee kellokeskeytyksen pois päältä. Asetetaan vain Kernel-tilassa. Vastaava MMIO-osoite on `CLOCK_INT_INTERVAL` ($001B).

**TSL** (Test and Set Lock) suorittaa atomisen luku-ja-kirjoitusoperaation: lukee muistiosoitteen arvon rekisteriin ja kirjoittaa samaan osoitteeseen arvon 1. Operaatio on jakamaton — keskeytys ei voi tapahtua lukemisen ja kirjoittamisen välissä. Päivittää Z- ja N-liput luetun arvon perusteella. Käytetään keskinäisen poissulkemisen (mutex) toteuttamiseen moniajossa: jos luettu arvo oli 0, lukko saatiin haltuun; jos 1, lukko oli jo varattu.

---

# 8. Oheislaitteet

## 8.1 Näppäimistö

- Jonopohjainen FIFO-puskuri
- Kun käyttäjä painaa tai vapauttaa näppäimen, tapahtuma lisätään jonoon ja CPU laukaisee **Int 6** (jos I = 1)
- Keskeytysrutiini lukee näppäimen: `READ reg, [KBD_DATA]` (osoite $0020)
  - Bits 6–0: näppäinkoodi; bitti 7: 0 = painallus, 1 = vapautus
- Puskurin koko luetaan `READ reg, [KBD_STATUS]` ($0021)
- Jos puskuri on tyhjä, KBD_DATA palauttaa 0

## 8.2 Tallennuslaite (Block Device)

- Koko: 256 blokkia × 256 sanaa = 65 536 sanaa (0x0000–0xFFFF), kukin 16-bittinen
- Pääsy vain Kernel-tilassa `DREAD`- ja `DWRITE`-käskyillä
- Käytetään käyttöjärjestelmän ja ohjelmien pysyvään tallennukseen

## 8.3 Satunnaislukugeneraattori (RAND MMIO)

- Osoite $0022 (`RAND_MMIO`): lukeminen palauttaa seuraavan 16-bittisen pseudosatunnaisluvun
- Toteutus: 16-bittinen Galois LFSR (polynomi 0xB400, jakso 65 535), jonka ulostulo sekoitetaan xorshift-permutaatiolla ennen palautusta
- Kirjoittaminen asettaa siemenen (0 korvautuu arvolla 1 automaattisesti)
- Sallittu sekä Kernel- että User-tilassa (READ reg, [RAND_MMIO])

---

# 9. Käynnistysprosessi (Boot)

Kylmäkäynnistyksen (cold boot) vaiheet:

| Vaihe | Toiminta                                                               |
| ----- | ---------------------------------------------------------------------- |
| 1     | CPU käynnistyy Kernel-tilassa (P=1, I=0)                               |
| 2     | Kaikki rekisterit nollataan, SP ← 0xFFFF, PC ← 0x0100                  |
| 3     | Laitteisto lukee tallennuslaitteen osoitteet 0x0000–0x00FF (256 sanaa) |
| 4     | Data kopioidaan RAM-osoitteisiin $0100–$01FF (bootloader-alue)         |
| 5     | Suoritus alkaa osoitteesta $0100                                       |

Tallennuslaitteen aluejako:

| Osoiteväli      | Kuvaus                                                     |
| --------------- | ---------------------------------------------------------- |
| 0x0000 – 0x00FF | Bootloader / Master Boot Record (ladataan automaattisesti) |
| 0x0100 – 0xFFFF | Vapaa tallennustila (OS, ohjelmat, data)                   |

---

# 10. Assembly-kieli

Assembly-kielen syntaksi, direktiivit, arkkitehtuurivakiot ja käyttöesimerkit on dokumentoitu erillisessä tiedostossa:

→ **[assembler.md](assembler.md)**

---

# 11. Opcode-kartta (yhteenveto)

## 11.1 Kaikki käskyt aakkosellisesti järjestettynä

| Opcode  | Käsky      | Sanat | Kuvaus                                              |
| ------- | ---------- | ----- | --------------------------------------------------- |
| 0x2580  | ADC        | 3     | Yhteenlasku carry:lla: regD = regD + regS + C       |
| 0x2080  | ADD        | 3     | Yhteenlasku: regD = regD + regS                     |
| 0x3080  | AND        | 3     | Bittitason JA-operaatio                             |
| 0x5A00+ | CALLI      | var.  | Indeksoitu taulukkokutsu (PUSH PC; PC = addr[reg])  |
| 0x5140  | CALL       | 2     | Kutsu aliohjelmaa (PUSH PC; PC = addr)              |
| 0xE300  | CLI        | 1     | Estä keskeytykset (I = 0, Kernel-tila)              |
| 0x2480  | CMP        | 3     | Vertailu: aseta liput regA - regB:n perusteella     |
| 0x1180  | CPY        | 3     | Kopioi rekisterien arvot keskenään                  |
| 0x1CC0  | COPY       | 4     | Kopioi muistialue [rS..rE] osoitteeseen rD          |
| 0xF180  | DREAD      | 3     | Lue tallennuslaitteelta (Kernel-tila)               |
| 0xF280  | DWRITE     | 3     | Kirjoita tallennuslaitteelle (Kernel-tila)          |
| 0x2380  | DIV        | 3     | Kokonaislukujako: regD = regD ÷ regS                |
| 0x7500  | EXIT       | 1     | Prosessin hallittu lopetus (Int 8)                  |
| 0xF000  | HALT       | 1     | Pysäytä prosessori (Kernel-tila)                    |
| 0x6040  | INT        | 2     | Laukaise ohjelmallinen keskeytys (0–9)              |
| 0xE100  | IRET       | 1     | Paluu keskeytyksestä (POP SR; POP PC)               |
| 0x5840  | JGE        | 2     | Hyppy jos suurempi tai yhtä suuri (N = V)           |
| 0x5640  | JGT        | 2     | Hyppy jos suurempi (etumerkillinen, Z=0 ∧ N=V)      |
| 0x5740  | JLE        | 2     | Hyppy jos pienempi tai yhtä suuri (Z=1 ∨ N≠V)       |
| 0x5540  | JLT        | 2     | Hyppy jos pienempi (etumerkillinen, N ≠ V)          |
| 0x5900+ | JMPI       | var.  | Indeksoitu taulukkohyppy: PC = addr[reg]            |
| 0x5440  | JNZ        | 2     | Hyppy jos eri suuruinen (Z = 0), alias: JNE         |
| 0x5340  | JZ         | 2     | Hyppy jos yhtä suuri (Z = 1), alias: JE             |
| 0x5040  | JUMP       | 2     | Ehdoton hyppy (PC = addr)                           |
| 0x1080  | LOAD       | 3     | Lataa välitön arvo rekisteriin                      |
| 0x2280  | MUL        | 3     | Kertolasku: regD = regD × regS                      |
| 0x7F00  | NOP        | 1     | Ei tee mitään                                       |
| 0x3340  | NOT        | 2     | Bittitason komplementti (käännä kaikki bitit)       |
| 0x3180  | OR         | 3     | Bittitason TAI-operaatio                            |
| 0x4140  | POP        | 2     | Hae arvo pinosta rekisteriin                        |
| 0x4040  | PUSH       | 2     | Talleta rekisteri pinoon                            |
| 0x1280  | READ       | 3     | Lue muistista absoluuttisesti                       |
| 0x1480  | READ_IND   | 3     | Lue muistista epäsuorasti (osoitinta käyttäen)      |
| 0x1680  | READ_REL   | 3     | Lue muistista FP-suhteellisesti                     |
| 0x5200  | RET        | 1     | Palaa aliohjelmasta (POP PC)                        |
| 0xF540  | SCTMR      | 2     | Aseta kellokeskeytysrekisteri ms-välillä (Kernel)   |
| 0x3480  | SHL        | 3     | Looginen vasen siirto                               |
| 0x3580  | SHR        | 3     | Looginen oikea siirto                               |
| 0xF340  | SMPR       | 2     | Aseta muistisuojarekisteri (Kernel-tila)            |
| 0x1380  | STORE      | 3     | Kirjoita muistiin absoluuttisesti                   |
| 0x1580  | STORE_IND  | 3     | Kirjoita muistiin epäsuorasti (osoitinta käyttäen)  |
| 0x1780  | STORE_REL  | 3     | Kirjoita muistiin FP-suhteellisesti                 |
| 0x1880  | STOREI     | 3     | Kirjoita välitön arvo absoluuttiseen osoitteeseen   |
| 0x1980  | STOREI_IND | 3     | Kirjoita välitön arvo epäsuoraan osoitteeseen       |
| 0x1A80  | STOREI_REL | 3     | Kirjoita välitön arvo FP-suhteelliseen osoitteeseen |
| 0x1BC0  | FILL       | 4     | Täytä muistialue [rS..rE] arvolla rV                |
| 0xE200  | STI        | 1     | Salli keskeytykset (I = 1, Kernel-tila)             |
| 0xF440  | STMR       | 2     | Aseta ajastinrekisteri (Kernel-tila)                |
| 0x2180  | SUB        | 3     | Vähennyslasku: regD = regD - regS                   |
| 0x4280  | SWSP       | 3     | Vaihda pinorekisteri atomisesti                     |
| 0x7780  | TSL        | 3     | Atominen testi ja asetus (Test and Set Lock)        |
| 0x3280  | XOR        | 3     | Bittitason poissulkeva TAI                          |

## 11.2 Käskyt kategorioittain

### Tiedonsiirto

| Käsky      | Opcode | Kuvaus                                                             |
| ---------- | ------ | ------------------------------------------------------------------ |
| LOAD       | 0x1080 | Lataa välitön 16-bittinen arvo rekisteriin                         |
| CPY        | 0x1180 | Kopioi yhden rekisterin sisältö toiseen rekisteriin                |
| READ       | 0x1280 | Lue yhden sanan muistista absoluuttisella osoitteella              |
| STORE      | 0x1380 | Kirjoita yhden sanan muistiin absoluuttisella osoitteella          |
| READ_IND   | 0x1480 | Lue muistista käyttäen rekisterissa olevaa osoitetta (epäsuorasti) |
| STORE_IND  | 0x1580 | Kirjoita muistiin käyttäen rekisterissa olevaa osoitetta           |
| READ_REL   | 0x1680 | Lue muistista frame pointerin suhteen (paikallismuuttujat)         |
| STORE_REL  | 0x1780 | Kirjoita muistiin frame pointerin suhteen                          |
| STOREI     | 0x1880 | Kirjoita välitön arvo absoluuttiseen osoitteeseen                  |
| STOREI_IND | 0x1980 | Kirjoita välitön arvo epäsuoraan osoitteeseen (rekisterin kautta)  |
| STOREI_REL | 0x1A80 | Kirjoita välitön arvo FP-suhteelliseen osoitteeseen                |
| FILL       | 0x1BC0 | Täytä muistialue [rS..rE] inklusiivisesti arvolla rV               |
| COPY       | 0x1CC0 | Kopioi muistialue [rS..rE] inklusiivisesti kohteeseen rD           |

### Aritmetiikka

| Käsky | Opcode | Kuvaus                                                                |
| ----- | ------ | --------------------------------------------------------------------- |
| ADD   | 0x2080 | Yhteenlasku kahdelle rekisterille, aseta liput (Z, N, C, V)           |
| SUB   | 0x2180 | Vähennyslasku, aseta liput                                            |
| MUL   | 0x2280 | Kertolasku, tallennetaan alin 16 bittiä, C-lippu ylivuodolle          |
| DIV   | 0x2380 | Kokonaislukujako, nollalla jako laukaisee Int 0                       |
| CMP   | 0x2480 | Vertailu: laskee erotus ja asettaa liput ilman tuloksen tallentamista |
| ADC   | 0x2580 | Yhteenlasku carry-lipun kanssa, 32+ -bittiselle aritmetiikalle        |

### Logiikka ja bittioperaatiot

| Käsky | Opcode | Kuvaus                                                                        |
| ----- | ------ | ----------------------------------------------------------------------------- |
| AND   | 0x3080 | Bittitason JA, käytetään maskeille (nollaa C ja V)                            |
| OR    | 0x3180 | Bittitason TAI, bittien asettamiseen päälle                                   |
| XOR   | 0x3280 | Bittitason JOKO-TAI, käytetään bittien kääntöön ja yksinkertaiseen salaukseen |
| NOT   | 0x3340 | Bittitason komplementti, kääntää kaikki bitit                                 |
| SHL   | 0x3480 | Looginen vasen siirto N-verran, oikea täytetään nollilla                      |
| SHR   | 0x3580 | Looginen oikea siirto N-verran, vasen täytetään nollilla                      |

### Pino

| Käsky | Opcode | Kuvaus                                                       |
| ----- | ------ | ------------------------------------------------------------ |
| PUSH  | 0x4040 | Talleta rekisterin arvo pinoon, vähennä SP:tä yhdellä        |
| POP   | 0x4140 | Lisää SP:tä yhdellä, hae arvo pinosta rekisteriin            |
| SWSP  | 0x4280 | Atominen pinorekisterin vaihto (ctx switch), ei keskeytyksiä |

### Ohjaus

| Käsky | Opcode  | Kuvaus                                                         |
| ----- | ------- | -------------------------------------------------------------- |
| JUMP  | 0x5040  | Ehdoton hyppy absoluuttiselle osoitteelle                      |
| CALL  | 0x5140  | Kutsu aliohjelmaa: talleta paluuosoite ja hyppy                |
| RET   | 0x5200  | Palaa aliohjelmasta palauttamalla PC pinosta                   |
| JZ    | 0x5340  | Ehdollinen hyppy, jos Z-lippu = 1 (yhtä suuret), alias: JE     |
| JNZ   | 0x5440  | Ehdollinen hyppy, jos Z-lippu = 0 (eri suuruiset), alias: JNE  |
| JLT   | 0x5540  | Ehdollinen hyppy, jos etumerkillisesti pienempi (signed)       |
| JGT   | 0x5640  | Ehdollinen hyppy, jos etumerkillisesti suurempi                |
| JLE   | 0x5740  | Ehdollinen hyppy, jos etumerkillisesti pienempi tai yhtä suuri |
| JGE   | 0x5840  | Ehdollinen hyppy, jos etumerkillisesti suurempi tai yhtä suuri |
| JMPI  | 0x5900+ | Indeksoitu taulukkohyppy: PC ← addr[reg] (muuttuvan pituinen)  |
| CALLI | 0x5A00+ | Indeksoitu taulukkokutsu: PUSH PC; PC ← addr[reg]              |

### Keskeytykset

| Käsky | Opcode | Kuvaus                                                               |
| ----- | ------ | -------------------------------------------------------------------- |
| INT   | 0x6040 | Laukaise ohjelmallinen keskeytys vektorilla 0–8 (syscall)            |
| IRET  | 0xE100 | Palaa keskeytyskäsittelijästä, palauta SR ja PC, vaatii Kernel-tilan |
| STI   | 0xE200 | Salli laitteistokeskeytykset (I = 1), vaatii Kernel-tilan            |
| CLI   | 0xE300 | Estä laitteistokeskeytykset (I = 0), vaatii Kernel-tilan             |

### Järjestelmä ja I/O

| Käsky  | Opcode | Kuvaus                                                             |
| ------ | ------ | ------------------------------------------------------------------ |
| HALT   | 0xF000 | Pysäytä prosessori kokonaan, vaatii Kernel-tilan                   |
| DREAD  | 0xF180 | Lue tallennuslaitteelta (block device), vaatii Kernel-tilan        |
| DWRITE | 0xF280 | Kirjoita tallennuslaitteelle, vaatii Kernel-tilan                  |
| SMPR   | 0xF340 | Aseta Memory Protection Register, vaatii Kernel-tilan              |
| STMR   | 0xF440 | Aseta Timer Register (ajastinväli), vaatii Kernel-tilan            |
| SCTMR  | 0xF540 | Aseta Clock Timer Register (ms-väli), vaatii Kernel-tilan          |
| EXIT   | 0x7500 | Prosessin hallittu lopetus, laukaisee Int 8                        |
| SCTMR  | 0xF540 | Aseta kellokeskeytysrekisteri ms-välillä, vaatii Kernel-tilan      |
| TSL    | 0x7780 | Atominen testi ja asetus: lue [addr] ja kirjoita 1, mutex-käyttöön |
| NOP    | 0x7F00 | Ei tee mitään                                                      |

> **Näppäimistön lukeminen:** Ei erillinen käsky. Käytä `READ reg, [KBD_DATA]` (MMIO $0020). Ks. kohta 4.1c.

---

# 12. Suoritusajat (Execution Timing)

kCPU16 käyttää simuloitua kelloa, jossa jokainen käsky kuluttaa tietyn määrän **suoritussyklejä**. Yksi sykli vastaa yhtä mikrosekuntia (µs) simuloidulla 1 MHz kellolla.

## 12.1 Simuloitu aika

Simuloitu aika kertyy akkumulaattoriin `_simulated_time_us` jokaisen onnistuneesti suoritetun käskyn jälkeen. Epäonnistuneet käskyt (poikkeukset, keskeytykset) eivät kasvata laskuria.

Simuloitua aikaa käytetään kaikkeen aikapohjaiseen toimintaan:
- **Uptime-laskuri** ($0019–$001A): simulated_time_us ÷ 1 000 000 (sekunteja)
- **TMR-keskeytys** (Int 7): laukeaa `next_tmr_us` saavutettaessa (TMR µs välein)
- **CTMR-keskeytys** (Int 9): laukeaa `next_ctmr_us` saavutettaessa (CTMR × 1000 µs välein)

## 12.2 Käskyjen suoritussyklit

| Käsky          | Syklit | Huomio                                          |
| -------------- | ------ | ----------------------------------------------- |
| LOAD           | 1      | Välittömän arvon lataus                         |
| CPY            | 1      | Rekisterikopiointi                              |
| READ           | 1      | Muistiluku (absoluuttinen)                      |
| STORE          | 1      | Muistikirjoitus                                 |
| READ_IND       | 1      | Epäsuora muistiluku                             |
| STORE_IND      | 1      | Epäsuora muistikirjoitus                        |
| READ_REL       | 1      | FP-suhteellinen muistiluku                      |
| STORE_REL      | 1      | FP-suhteellinen muistikirjoitus                 |
| STOREI         | 1      | Välitön arvo muistiin                           |
| STOREI_IND     | 1      | Välitön arvo epäsuoraan osoitteeseen            |
| STOREI_REL     | 1      | Välitön arvo FP-suhteelliseen osoitteeseen      |
| FILL           | 1 + N  | 1 perussykli + täytettävien sanojen lukumäärä N |
| ADD / SUB      | 1      |                                                 |
| MUL            | 4      | Kertolasku                                      |
| DIV            | 8      | Jakolasku                                       |
| CMP / ADC      | 1      |                                                 |
| AND/OR/XOR/NOT | 1      | Bittioperaatiot                                 |
| SHL / SHR      | 1      | Bittisiirrot                                    |
| PUSH / POP     | 1      | Pinooperaatiot                                  |
| SWSP           | 1      |                                                 |
| JUMP           | 1      |                                                 |
| CALL / RET     | 2      | Sisältää pinoon tallennuksen tai luvun          |
| JZ/JNZ/JLT ... | 1      | Kaikki ehdolliset hypyt                         |
| JMPI / CALLI   | 2      | Indeksoitu hyppy / kutsu (perussykli)           |
| INT / IRET     | 4      | Kontekstin tallennus ja palautus                |
| EXIT           | 4      | Prosessin lopetus                               |
| STI / CLI      | 1      |                                                 |
| HALT / NOP     | 1      |                                                 |
| STMR / SCTMR   | 1      |                                                 |
| SMPR           | 1      |                                                 |
| DREAD / DWRITE | 10     | I/O-operaatiot (tallennuslaite)                 |
| TSL            | 2      | Atominen lue-muokkaa-kirjoita                   |

## 12.3 Ajastinkeskeytykset simuloidun ajan perusteella

**TMR-keskeytys (Int 7):**

- `STMR R` asettaa TMR = R (yksikkö: µs)
- Keskeytys laukeaa kun simuloitu aika ≥ `next_tmr_us`
- Seuraava laukaisuhetki: `next_tmr_us += TMR`
- Tämä takaa, että keskeytys laukeaa tasasin väliajoin riippumatta siitä, milloin tarkistus tapahtuu

**CTMR-keskeytys (Int 9):**

- `SCTMR R` asettaa CTMR = R (yksikkö: ms = 1000 µs)
- Keskeytys laukeaa kun simuloitu aika ≥ `next_ctmr_us`
- Seuraava laukaisuhetki: `next_ctmr_us += CTMR × 1000`

## 12.4 Uptime MMIO

Uptime lasketaan `simulated_time_us ÷ 1 000 000`. Arvo kasvaa yhdellä sekunnilla jokaista
1 000 000 simuloitua mikrosekuntia kohti riippumatta ohjelman suoritusnopeudesta (FAST, MAX, SLOW jne.)

| Rekisteri | Osoite | Kuvaus                      |
| --------- | ------ | --------------------------- |
| UPTIME_W1 | $0019  | Sekuntilaskurin bitit 16–31 |
| UPTIME_W0 | $001A  | Sekuntilaskurin bitit 0–15  |

---

# 13. Tallennuslaitekirjasto (lib-disk.asm)

`code/lib-disk.asm` toteuttaa yksinkertaisen tiedostojärjestelmän kCPU16:n blokkipohjaiselle
tallennuslaitteelle. Kirjasto tarjoaa julkisen rajapinnan hakemistojen ja tiedostojen luomiseen,
kirjoittamiseen, lukemiseen, poistamiseen, listaamiseen, eheyden tarkistamiseen ja tietojen hakemiseen.

## 13.1 Tiedostojärjestelmän rakenne

Tallennuslaite jaetaan 256-sanaisten blokkien sarjaan (256 blokkia × 256 sanaa = 65 536 sanaa):

| Blokki | Osoite        | Kuvaus                                        |
| ------ | ------------- | --------------------------------------------- |
| 0      | 0x0000–0x00FF | Boot-sektori (kCPU16 lukee käynnistyksessä)   |
| 1      | 0x0100–0x01FF | FAT-taulukko (256 merkintää, yksi per blokki) |
| 2      | 0x0200–0x02FF | Hakemisto (8 tiedostomerkintää × 32 sanaa)    |
| 3–255  | 0x0300–0xFFFF | Datablokkit (tiedostojen sisältö)             |

### FAT-taulukko (blokki 1)

Kukin sana FAT:ssa kuvaa yhden blokin tilan:

| Arvo   | Merkitys                              |
| ------ | ------------------------------------- |
| 0x0000 | Blokki vapaa                          |
| 0xFFFF | Blokki on ketjun viimeinen (DISK_EOF) |
| muut   | Seuraavan blokin indeksi ketjussa     |

### Hakemistomerkintä (blokki 2, 32 sanaa/merkintä)

| Offset | Kuvaus                                             |
| ------ | -------------------------------------------------- |
| 0      | Status: 0 = vapaa, 1 = tiedosto, 2 = hakemisto     |
| 1–16   | Tiedostonimi (null-terminoitu, max 16 sanaa)       |
| 17     | Tiedoston koko sanoina                             |
| 18     | Luontivuosi                                        |
| 19     | Luontikuukausi (8 MSB) + luontipäivä (8 LSB)       |
| 20     | Muokkausvuosi                                      |
| 21     | Muokkauskuukausi (8 MSB) + muokkauspäivä (8 LSB)   |
| 22     | Ensimmäisen databloki indeksi (0 = tyhjä tiedosto) |
| 23–31  | Varaus                                             |

## 13.2 Julkinen rajapinta

### Vakiot

```asm
DISK_OK              = 0      ; Onnistuminen
DISK_ERR_NOT_FOUND   = 1      ; Tiedostoa ei löydy
DISK_ERR_NO_SPACE    = 2      ; Ei tilaa hakemistossa
DISK_ERR_DISK_FULL   = 3      ; Levy täynnä
DISK_ERR_RANGE       = 4      ; Luku-/kirjoitusvirhe (väärä koko)
DISK_EOF             = 0xFFFF ; FAT-ketjun loppu
```

### disk_format — Alusta tiedostojärjestelmä

```
Sisään: (ei parametreja)
Ulos:   R0 = DISK_OK
```

Nollaa FAT:n ja hakemiston, merkitsee blokit 0–2 varatuiksi.

### disk_create — Luo uusi tiedosto

```
Sisään: R0 = osoitin tiedostonimeen (null-terminoitu merkkijono)
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_NO_SPACE    hakemisto täynnä
        R0 = merkintäindeksi      nimi jo olemassa
```

### disk_mkdir — Luo uusi hakemisto

```
Sisään: R0 = osoitin hakemistonimeen/polkuun (null-terminoitu merkkijono)
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_EXISTS      nimi jo olemassa
        R0 = DISK_ERR_DIR_FULL    hakemisto täynnä
```

### disk_write — Kirjoita data tiedostoon

```
Sisään: R0 = osoitin tiedostonimeen
        R1 = osoitin dataan RAM:ssa
        R2 = sanojen lukumäärä
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_NOT_FOUND   tiedostoa ei löydy
        R0 = DISK_ERR_DISK_FULL   levy täynnä
```

Korvaa mahdollisen vanhan datan. Kirjoittaa blokki kerrallaan.

### disk_read — Lue data tiedostosta

```
Sisään: R0 = osoitin tiedostonimeen
        R1 = osoitin kohde-puskuriin RAM:ssa
        R2 = luettavien sanojen enimmäismäärä
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_NOT_FOUND   tiedostoa ei löydy
        R0 = DISK_ERR_RANGE       annettu enimmäismäärä ylitetty
```

Lukee `min(max_words, tiedoston_koko)` sanaa puskuriin.

### disk_delete — Poista tiedosto

```
Sisään: R0 = osoitin tiedostonimeen
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_NOT_FOUND   tiedostoa ei löydy
```

Vapauttaa datablokkit FAT:sta ja nollaa hakemistomerkinnän.

### disk_stat — Hae tiedoston metatiedot

```
Sisään: R0 = osoitin tiedostonimeen
        R1 = osoitin 8-sanaiseen puskuriin metatietojen tallennusta varten
Ulos:   R0 = DISK_OK              onnistuminen
        R0 = DISK_ERR_NOT_FOUND   tiedostoa ei löydy
```

Täyttää puskurin metatiedoilla:

| Offset | Sisältö                    |
| ------ | -------------------------- |
| 0      | Tiedoston koko sanoina     |
| 1      | Luontivuosi                |
| 2      | Luontikuukausi + -päivä    |
| 3      | Muokkausvuosi              |
| 4      | Muokkauskuukausi + -päivä  |
| 5      | Ensimmäinen blokki-indeksi |
| 6–7    | Varaus (0)                 |

### disk_list — Listaa tiedostot ja hakemistot

```
Sisään: R0 = osoitin puskuriin (17 sanaa per tiedosto: 16 nimi + 1 koko)
        R1 = puskurin maksimikoko sanoina
Ulos:   R0 = löydettyjen tiedostojen lukumäärä
```

### disk_check — Tarkista tiedostojärjestelmän eheys

```
Sisään: (ei parametreja)
Ulos:   R0 = DISK_OK              eheä tiedostojärjestelmä
        R0 = DISK_ERR_RANGE       havaittu epäjohdonmukaisuus
```

### disk_sync — Synkronoi levykirjoitukset

```
Sisään: (ei parametreja)
Ulos:   R0 = DISK_OK              levy valmis turvalliseen sammutukseen/resettiin
        R0 = DISK_ERR_RANGE       eheystarkistus epäonnistui
```

Nykyisessä emulaattorissa kirjoitukset ovat synkronisia, joten `disk_sync`
toimii eksplisiittisenä synkronointipisteenä ja suorittaa samalla
`disk_check`-eheystarkistuksen.

### disk_find — Etsi tiedosto nimellä

```
Sisään: R0 = osoitin tiedostonimeen
Ulos:   R0 = merkintäindeksi (0–7) jos löytyi
        R0 = DISK_ERR_NOT_FOUND (1) jos ei löydy
        disk_io_buf sisältää hakemistodatan
```

## 13.3 Käyttöesimerkki

```asm
.include "lib-disk.asm"

main:
    ; Alusta levy
    CALL  disk_format

    ; Luo tiedosto
    READ  R0, tiedostonimi
    CALL  disk_create

    ; Kirjoita dataa
    READ  R0, tiedostonimi
    READ  R1, data_puskuri
    READ  R2, 2              ; 2 sanaa
    CALL  disk_write

    ; Lue data takaisin
    READ  R0, tiedostonimi
    READ  R1, luku_puskuri
    READ  R2, 2
    CALL  disk_read

    ; Poista tiedosto
    READ  R0, tiedostonimi
    CALL  disk_delete
    HALT

tiedostonimi: .dstr "TESTIFILE"
data_puskuri: .dw 0x1234, 0x5678
luku_puskuri: .dw 0, 0
```

## 13.4 Sisäiset apurakenteet

- `disk_io_buf` (256 sanaa): Väliaikaispuskuri blokki-operaatioille
- `_disk_read_block` / `_disk_write_block`: Siirtää 256 sanaa blokin ja `disk_io_buf`:n välillä
- `_fat_alloc` / `_fat_free_chain`: FAT-taulukon hallinta
- `_disk_str_cmp`: Null-terminoitujen merkkijonojen vertailu
