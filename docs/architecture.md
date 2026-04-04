# kCPU16 Arkkitehtuurispesifikaatio

Versio 4.1

Tämä dokumentti on kCPU16-prosessorin virallinen tekninen spesifikaatio. Se sisältää kaikki tarvittavat tiedot emulaattorin rakentamiseksi tai assembly-ohjelmien kirjoittamiseksi.

---

# 1. Yleiskatsaus

kCPU16 on 16-bittinen von Neumann -arkkitehtuuriin perustuva prosessori.

| Ominaisuus            | Arvo                                            |
| --------------------- | ----------------------------------------------- |
| Sanan leveys          | 16 bittiä                                       |
| Muistiavaruus         | 65 536 sanaa (0x0000–0xFFFF)                    |
| Osoitustyyppi         | Sana-osoitettu (word-addressed)                 |
| Arkkitehtuurimalli    | Von Neumann (koodi ja data samassa muistissa)   |
| Tavujärjestys         | Ei oleellinen (sana = pienin osoitettava yksikkö) |
| Suojaustilat          | Kernel Mode ja User Mode                        |
| Käskyn koko           | 1–3 sanaa (opcode + 0–2 operandia)              |

---

# 2. Rekisterit

## 2.1 Yleiskäyttöiset rekisterit (GPR)

Neljä 16-bittistä yleiskäyttöistä rekisteriä. Käskyissä koodataan 3-bittisellä indeksillä.

| Rekisteri | Indeksi | Kuvaus                                    |
| --------- | ------- | ----------------------------------------- |
| R0        | 0       | Yleiskäyttöinen datarekisteri             |
| R1        | 1       | Yleiskäyttöinen datarekisteri             |
| R2        | 2       | Yleiskäyttöinen datarekisteri             |
| R3        | 3       | Yleiskäyttöinen / paluuarvorekisteri      |

## 2.2 Erikoisrekisterit

| Rekisteri | Indeksi | Kuvaus                                                         |
| --------- | ------- | -------------------------------------------------------------- |
| FP        | 4       | Frame Pointer — aliohjelman pinokehyksen pohja                 |
| SP        | 5       | Stack Pointer — pinon huippu, pino kasvaa alaspäin             |
| PC        | —       | Program Counter — seuraavan käskyn osoite (ei suoraan käytettävissä käskyissä) |
| SR        | —       | Status Register — tilaliput (ks. 2.4)                          |

## 2.3 Järjestelmärekisterit

Vain Kernel-tilassa kirjoitettavissa (SMPR, STMR -käskyillä).

| Rekisteri | Kuvaus                                                                |
| --------- | --------------------------------------------------------------------- |
| MPR       | Memory Protection Register — User-muistin alaraja                     |
| TMR       | Timer Register — ajastinkeskeytyksen väli käskyjen lukumääränä (0 = pois) |

## 2.4 Tilarekisteri (SR)

SR on 16-bittinen, josta bitit 0–5 ovat käytössä.

| Bitti | Nimi | Kuvaus                                                                               |
| ----- | ---- | ------------------------------------------------------------------------------------ |
| 0     | Z    | **Zero** — 1 jos operaation tulos on nolla                                           |
| 1     | N    | **Negative** — 1 jos tuloksen ylin bitti (bitti 15) on 1                             |
| 2     | C    | **Carry** — 1 jos tapahtui etumerkitön ylivuoto (unsigned overflow)                  |
| 3     | V    | **Overflow** — 1 jos tapahtui etumerkillinen ylivuoto (signed overflow)              |
| 4     | I    | **Interrupt Enable** — 1 = laitteistokeskeytykset sallittu, 0 = estetty             |
| 5     | P    | **Privilege** — 1 = Kernel Mode, 0 = User Mode                                      |
| 6–15  | —    | Varattu (tulee olla 0)                                                               |

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

| Osoitealue        | Koko        | Kuvaus                                  |
| ----------------- | ----------- | --------------------------------------- |
| $0000 – $0008     | 9 sanaa     | Keskeytysvektoritaulukko                |
| $0009 – $00FF     | 247 sanaa   | Käyttöjärjestelmän varattu alue         |
| $0100 – $01FF     | 256 sanaa   | Bootloaderin latausalue                 |
| $0200 – $F7FF     | 62 464 sanaa | Vapaa RAM (ohjelmat ja data)           |
| $F800 – $FF7F     | 1920 sanaa  | Video RAM (80 × 24, MMIO)              |
| $FF80 – $FFFF     | 128 sanaa   | Kernel Stack                            |

## 4.1 Keskeytysvektoritaulukko ($0000–$0008)

Jokainen vektoripaikka sisältää keskeytyskäsittelijän muistiosoitteen.

| Vektori | Osoite | Keskeytys                     |
| ------- | ------ | ----------------------------- |
| 0       | $0000  | Jako nollalla                 |
| 1       | $0001  | Tuntematon käsky              |
| 2       | $0002  | Pinon ylivuoto                |
| 3       | $0003  | Debug / Breakpoint            |
| 4       | $0004  | Privilege Violation           |
| 5       | $0005  | Memory Access Fault           |
| 6       | $0006  | Näppäimistökeskeytys          |
| 7       | $0007  | Ajastinkeskeytys              |
| 8       | $0008  | Prosessin lopetus (EXIT)      |

## 4.2 Video RAM ($F800–$FF7F)

Näyttö on 80 saraketta × 24 riviä = 1920 sanaa. Ensimmäinen osoite ($F800) vastaa ruudun vasenta ylänurkkaa. Osoitteet kasvavat vasemmalta oikealle, rivi kerrallaan.

Yhden sanan bittirakenne:

| Bitit   | Kuvaus                           |
| ------- | -------------------------------- |
| 0 – 7   | ASCII-merkkikoodi                |
| 8       | Lihavointi (1 = päällä)          |
| 9       | Kursiivi (1 = päällä)            |
| 10      | Vilkku / blink (1 = päällä)      |
| 11      | Alleviivaus (1 = päällä)         |
| 12      | Yliviivaus (1 = päällä)          |
| 13 – 15 | Etustaväri (FG), 3 bittiä        |

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

| Tyyppi           | Numerot | Laukeaistapa                                    |
| ---------------- | ------- | ------------------------------------------------ |
| Virhepoikkeukset | 0–2     | Automaattinen: DIV/0, tuntematon opcode, stack overflow |
| Ohjelmistokesk.  | 3, 8    | `INT`-käskyllä tai `EXIT`-käskyllä               |
| Suojausvirheet   | 4–5     | Automaattinen: käsky- tai muistisuojausrikkomus  |
| Laitekesk.       | 6–7     | Laitteiston laukaisema (näppäimistö, ajastin)    |

## 5.4 Ajastinkeskeytys (TMR)

- TMR-rekisteri määrittää aikavälin suoritettujen käskyjen lukumääränä
- TMR = 0 → ajastin pois päältä
- Int 7 laukeaa kun `instruction_counter % TMR == 0` **ja** `I = 1`
- Ajastinta ei tarkisteta jos keskeytykset on estetty (I = 0)

---

# 6. Suoritussykli

Jokainen `step()` suorittaa yhden käskyn seuraavassa järjestyksessä:

| Vaihe | Nimi      | Kuvaus                                                                |
| ----- | --------- | --------------------------------------------------------------------- |
| 1     | FETCH     | Lue opcode-sana osoitteesta [PC] ja 0–2 operandisanaa                 |
| 2     | PRIVILEGE | Tarkista käskyoikeus (Kernel-käsky User-tilassa → Int 4)              |
| 3     | MEMORY    | Tarkista muistiviittausten laillisuus (User: addr < MPR → Int 5)      |
| 4     | EXECUTE   | Suorita käsky, päivitä rekisterit ja liput                            |
| 5     | PC UPDATE | PC ← PC + käskyn sanamäärä                                           |
| 6     | TIMER     | Tarkista ja laukaise ajastinkeskeytys tarvittaessa                    |

Jos vaiheissa 2–3 tapahtuu virhe, suoritetaan vastaava keskeytys eikä vaiheita 4–6 tehdä.

---

# 7. Käskykanta

## 7.1 Operandityypit

| Merkintä   | Kuvaus                                                          |
| ---------- | --------------------------------------------------------------- |
| `reg`      | Rekisteri: R0, R1, R2, R3, FP, SP (koodattu 3-bittisellä indeksillä) |
| `regD`     | Kohderekisteri (destination)                                    |
| `regS`     | Lähderekisteri (source)                                         |
| `imm`      | 16-bittinen välitön arvo (immediate)                            |
| `addr`     | 16-bittinen absoluuttinen muistiosoite                          |

Käskyissä kohde (destination) on aina **ensimmäisenä** ja lähde (source) **toisena**.

## 7.2 Lippujen merkintätapa

| Merkintä | Selitys                                               |
| -------- | ----------------------------------------------------- |
| `—`      | Käsky ei muuta lippuja                                |
| `ZNCV`   | Päivittää nimetyt liput tuloksen perusteella          |
| `ZN——`   | Päivittää vain Z ja N; C ja V nollataan               |
| `ZNC—`   | Päivittää Z, N ja C; V nollataan                      |

## 7.3 Tiedonsiirtokäskyt

| Opcode | Käsky     | Operandit  | Tila | Liput | Kuvaus                                  |
| ------ | --------- | ---------- | ---- | ----- | --------------------------------------- |
| 0x0001 | LOAD      | reg, imm   | U    | —     | `reg ← imm`                            |
| 0x0002 | CPY       | regD, regS | U    | —     | `regD ← regS`                          |
| 0x0003 | READ      | reg, addr  | U    | —     | `reg ← [addr]`                         |
| 0x0004 | STORE     | reg, addr  | U    | —     | `[addr] ← reg`                         |
| 0x0005 | READ_IND  | regD, regS | U    | —     | `regD ← [regS]`                        |
| 0x0006 | STORE_IND | regD, regS | U    | —     | `[regD] ← regS`                        |
| 0x0007 | READ_REL  | reg, imm   | U    | —     | `reg ← [FP + imm]`                     |
| 0x0008 | STORE_REL | reg, imm   | U    | —     | `[FP + imm] ← reg`                     |

**LOAD** lataa 16-bittisen välittömän arvon (immediate) suoraan rekisteriin. Tämä on ainoa tapa saada vakioarvo rekisteriin. Käsky on 3 sanaa pitkä: opcode, rekisteri-indeksi ja 16-bittinen arvo.

**CPY** kopioi lähderekisterin arvon kohderekisteriin. Lähderekisterin sisältö säilyy muuttumattomana. Käytetään rekisterien väliseen tiedonsiirtoon, esimerkiksi pinon osoittimen kopiointiin yleisrekisteriin.

**READ** lukee muistiosoitteesta yhden sanan ja tallentaa sen rekisteriin. Osoite annetaan absoluuttisena 16-bittisenä arvona käskyn operandina. User-tilassa osoitteen on oltava ≥ MPR tai Video RAM -alueella.

**STORE** kirjoittaa rekisterin arvon annettuun absoluuttiseen muistiosoitteeseen. Samat muistisuojasäännöt pätevät kuin READ-käskyssä.

**READ_IND** lukee muistista epäsuorasti: lähderekisterin arvo tulkitaan muistiosoitteeksi, ja kyseisestä osoitteesta luettu sana tallennetaan kohderekisteriin. Käytetään osoitintietorakenteiden (taulukot, listat) käsittelyyn.

**STORE_IND** kirjoittaa lähderekisterin arvon muistiin osoitteeseen, jonka kohderekisteri ilmoittaa. Tämä on epäsuoran lukemisen vastapari ja mahdollistaa osoittimen kautta kirjoittamisen.

**READ_REL** lukee muistista kehysosoittimen (FP) suhteen: osoite lasketaan summana FP + imm. Käytetään aliohjelmien paikallisten muuttujien ja parametrien käsittelyyn pinokehyksessä.

**STORE_REL** kirjoittaa rekisterin arvon FP-suhteelliseen muistiosoitteeseen (FP + imm). Käytetään paikallisten muuttujien tallentamiseen aliohjelman pinokehykseen.

## 7.4 Aritmetiikkakäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                                             |
| ------ | ----- | ---------- | ---- | ----- | -------------------------------------------------- |
| 0x0010 | ADD   | regD, regS | U    | ZNCV  | `regD ← regD + regS`                              |
| 0x001B | ADC   | regD, regS | U    | ZNCV  | `regD ← regD + regS + C`                          |
| 0x0011 | SUB   | regD, regS | U    | ZNCV  | `regD ← regD − regS`                              |
| 0x0012 | MUL   | regD, regS | U    | ZNCV  | `regD ← regD × regS`                              |
| 0x0013 | DIV   | regD, regS | U    | ZNCV  | `regD ← regD / regS` (kokonaislukujako, Int 0 jos regS = 0) |
| 0x0014 | CMP   | regA, regB | U    | ZNCV  | Laskee `regA − regB`, asettaa liput, tulosta ei tallenneta |

**ADD** laskee kahden rekisterin summan ja tallentaa tuloksen kohderekisteriin. Päivittää kaikki aritmetiikkaliput: Z (tulos nolla), N (ylin bitti 1), C (etumerkitön ylivuoto) ja V (etumerkillinen ylivuoto). Käytetään yleiseen kokonaislukuaritmetiikkaan ja osoitelaskentaan.

**ADC** (Add with Carry) laskee kahden rekisterin summan lisättynä nykyisellä carry-lipulla. Mahdollistaa 32-bittisen (tai suuremman) yhteenlaskun ketjuttamalla useita ADC-käskyjä: ensin ADD alemmat sanat, sitten ADC ylemmät sanat. Päivittää kaikki aritmetiikkaliput.

**SUB** vähentää lähderekisterin arvon kohderekisteristä. Carry-lippu asettuu, jos vähennettävä on suurempi kuin vähennettävä (etumerkittömässä mielessä, eli borrow tapahtui). V-lippu ilmaisee etumerkillisen ylivuodon.

**MUL** kertoo kohderekisterin lähderekisterillä ja tallentaa tuloksen alimmat 16 bittiä kohderekisteriin. Ylivuoto (tulos > 0xFFFF) asettaa C-lipun. Käsittelee operandeja etumerkittöminä kokonaislukuina.

**DIV** suorittaa kokonaislukujaon (tasajaon). Jos jakaja (regS) on nolla, käsky laukaisee keskeytyksen Int 0 (Division by Zero) eikä rekistereitä muokata. Jakojäännös ei tallennu — käytä erillistä laskentaa modulo-operaatioon.

**CMP** laskee regA − regB ja asettaa liput aivan kuten SUB, mutta erotusta ei tallenneta kumpaankaan rekisteriin. Käytetään aina ennen ehdollisia hyppykäskyjä (JZ, JLT, JGT jne.) kahden arvon vertailuun.

## 7.5 Logiikka- ja bittikäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                                           |
| ------ | ----- | ---------- | ---- | ----- | ------------------------------------------------ |
| 0x0015 | AND   | regD, regS | U    | ZN——  | `regD ← regD AND regS`                          |
| 0x0016 | OR    | regD, regS | U    | ZN——  | `regD ← regD OR regS`                           |
| 0x0017 | XOR   | regD, regS | U    | ZN——  | `regD ← regD XOR regS`                          |
| 0x0018 | NOT   | reg        | U    | ZN——  | `reg ← NOT reg` (bittitason komplementti)        |
| 0x0019 | SHL   | regD, regS | U    | ZNC—  | `regD ← regD << regS` (looginen vasen siirto)   |
| 0x001A | SHR   | regD, regS | U    | ZNC—  | `regD ← regD >> regS` (looginen oikea siirto)   |

**AND** suorittaa bittitason JA-operaation kohde- ja lähderekisterin välillä. Tulos tallennetaan kohderekisteriin. Käytetään tyypillisesti bittimaskien soveltamiseen — esimerkiksi yksittäisen bitin tarkistamiseen tai nollaamiseen. Päivittää Z- ja N-liput; C ja V nollataan.

**OR** suorittaa bittitason TAI-operaation. Käytetään bittien asettamiseen päälle: esimerkiksi lippujen tai attribuuttien yhdistämiseen yhdeksi sanaksi. Päivittää Z- ja N-liput; C ja V nollataan.

**XOR** suorittaa bittitason poissulkeva-TAI-operaation. XOR samalla arvolla nollaa rekisterin (`XOR R0, R0` → R0 = 0). Käytetään myös bittien kääntämiseen ja yksinkertaiseen salaukseen. Päivittää Z- ja N-liput; C ja V nollataan.

**NOT** kääntää rekisterin kaikki bitit (yhden komplementti): jokainen 0 muuttuu 1:ksi ja päinvastoin. Operoi vain yhteen rekisteriin. Käytetään bittimaskien inversointiin ja kahden komplementin laskemiseen (NOT + ADD #1). Päivittää Z- ja N-liput; C ja V nollataan.

**SHL** (Shift Left) siirtää kohderekisterin bittejä vasemmalle lähderekisterin ilmoittaman määrän verran. Oikealta täytetään nollilla. Viimeinen ulos siirtynyt bitti tallennetaan C-lippuun. Vasen siirto yhdellä vastaa kertomista kahdella. Päivittää Z-, N- ja C-liput; V nollataan.

**SHR** (Shift Right) siirtää bittejä oikealle loogisesti (vasemmalta täytetään nollilla). Viimeinen ulos siirtynyt bitti tallennetaan C-lippuun. Oikea siirto yhdellä vastaa etumerkitöntä jakoa kahdella. Päivittää Z-, N- ja C-liput; V nollataan.

## 7.6 Pinokäskyt

| Opcode | Käsky | Operandit  | Tila | Liput | Kuvaus                                           |
| ------ | ----- | ---------- | ---- | ----- | ------------------------------------------------ |
| 0x0020 | PUSH  | reg        | U    | —     | `[SP] ← reg; SP ← SP − 1`                      |
| 0x0021 | POP   | reg        | U    | —     | `SP ← SP + 1; reg ← [SP]`                      |
| 0x0022 | SWSP  | regD, regS | U    | —     | `regD ← SP; SP ← regS`                          |

**PUSH** tallettaa rekisterin arvon pinoon. Ensin kirjoitetaan arvo nykyiseen pinopaikkaan [SP], sitten SP:tä vähennetään yhdellä (pino kasvaa alaspäin kohti pienempiä osoitteita). User-tilassa, jos SP laskee alle MPR-rajan, laukeaa Int 2 (Stack Overflow). Käytetään arvojen väliaikaiseen tallentamiseen, aliohjelmakutsujen parametrien välittämiseen ja rekisterien pelastamiseen.

**POP** palauttaa arvon pinosta rekisteriin. Ensin SP:tä kasvatetaan yhdellä, sitten luetaan arvo osoitteesta [SP]. PUSH- ja POP-parit ovat käänteisiä operaatioita. Käytetään arvojen palauttamiseen ja aliohjelmista paluuseen (RET käyttää sisäisesti POP PC:tä).

**SWSP** (Swap Stack Pointer) vaihtaa pinorekisterin atomisesti: tallentaa nykyisen SP:n kohderekisteriin ja lataa uuden SP:n lähderekisteristä. Tämä on yksi atominen operaatio, joten keskeytysten ei tarvitse olla estettyinä. Käytetään ensisijaisesti käyttöjärjestelmän kontekstinvaihtorutiinissa prosessien pinojen vaihtamiseen.

## 7.7 Ohjauskäskyt

| Opcode | Käsky | Operandit | Tila | Liput | Kuvaus                                           |
| ------ | ----- | --------- | ---- | ----- | ------------------------------------------------ |
| 0x0030 | JUMP  | addr      | U    | —     | `PC ← addr`                                     |
| 0x0031 | CALL  | addr      | U    | —     | `PUSH paluuosoite; PC ← addr`                   |
| 0x0032 | RET   | —         | U    | —     | `POP PC` (paluu aliohjelmasta)                   |

**JUMP** siirtää suorituksen ehdottomasti annettuun osoitteeseen. PC ladataan suoraan operandina annetulla osoitteella. Käytetään silmukoiden, ehdottomien haarojen ja goto-tyypisten siirtymien toteuttamiseen.

**CALL** kutsuu aliohjelmaa: tallentaa nykyisen paluuosoitteen (seuraavan käskyn osoite) pinoon PUSH-operaatiolla ja siirtää suorituksen annettuun osoitteeseen. Paluuosoite on käskyn jälkeinen osoite, jotta RET osaa palata oikeaan kohtaan. Käytetään funktioiden ja aliohjelmien kutsumiseen.

**RET** palaa aliohjelmasta: palauttaa pinosta paluuosoitteen PC:hen (POP PC). Jokaista CALL-käskyä vastaa RET aliohjelman lopussa. Ohjelmoijan vastuulla on varmistaa, että pino on oikeassa kunnossa ennen RET:iä.

### Ehdolliset hypyt

Käytetään CMP-käskyn jälkeen. Etumerkillinen vertailu perustuu N- ja V-lippuihin.

| Opcode | Käsky | Ehto             | Kuvaus                        | Alias    |
| ------ | ----- | ---------------- | ----------------------------- | -------- |
| 0x0033 | JZ    | Z = 1            | Jump if Equal                 | JE       |
| 0x0034 | JNZ   | Z = 0            | Jump if Not Equal             | JNE      |
| 0x0035 | JLT   | N ≠ V            | Jump if Less Than (signed)    | —        |
| 0x0036 | JGT   | Z = 0 ∧ N = V   | Jump if Greater Than (signed) | —        |
| 0x0037 | JLE   | Z = 1 ∨ N ≠ V   | Jump if Less or Equal         | —        |
| 0x0038 | JGE   | N = V            | Jump if Greater or Equal      | —        |

**JZ** (Jump if Zero / Jump if Equal) hyppää annettuun osoitteeseen, jos Z-lippu on asetettu. CMP-käskyn jälkeen tämä tarkoittaa, että verrattavat arvot ovat yhtä suuret. Assemblerissa voi käyttää myös aliasta JE. Jos ehto ei täyty, suoritus jatkuu normaalisti seuraavasta käskystä.

**JNZ** (Jump if Not Zero / Jump if Not Equal) hyppää, jos Z-lippu ei ole asetettu. CMP:n jälkeen tämä tarkoittaa, että arvot eivät ole yhtä suuret. Alias: JNE. Käytetään tyypillisesti silmukoissa tarkistamaan, onko laskuri nollassa.

**JLT** (Jump if Less Than) hyppää, jos etumerkillinen vertailu osoittaa ensimmäisen operandin olevan pienempi kuin toinen. Ehto N ≠ V havaitsee tämän oikein myös ylivuototilanteissa.

**JGT** (Jump if Greater Than) hyppää, jos ensimmäinen operandi on etumerkillisesti suurempi kuin toinen. Ehto Z = 0 ∧ N = V varmistaa, että arvot eivät ole yhtä suuret ja suuruussuhde on oikein.

**JLE** (Jump if Less or Equal) hyppää, jos ensimmäinen operandi on pienempi tai yhtä suuri kuin toinen. Ehto Z = 1 ∨ N ≠ V kattaa sekä yhtäsuuruuden että pienemmuuden.

**JGE** (Jump if Greater or Equal) hyppää, jos ensimmäinen operandi on suurempi tai yhtä suuri kuin toinen. Ehto N = V on yksinkertainen: normaalitilanteessa positiivinen erotus (N=0, V=0) ja ylivuototilanteessa molemmat ovat 1.

## 7.8 Keskeytyskäskyt

| Opcode | Käsky | Operandit | Tila | Liput | Kuvaus                                           |
| ------ | ----- | --------- | ---- | ----- | ------------------------------------------------ |
| 0x0040 | INT   | imm       | U    | —     | Ohjelmallinen keskeytys (syscall). imm = 0–8.    |
| 0x0041 | IRET  | —         | K    | —     | Paluu keskeytyksestä: `POP SR; POP PC`           |
| 0x0042 | STI   | —         | K    | —     | Salli keskeytykset: `I ← 1`                     |
| 0x0043 | CLI   | —         | K    | —     | Estä keskeytykset: `I ← 0`                      |
| 0x0044 | HALT  | —         | K    | —     | Pysäytä prosessori                               |
| 0x0049 | EXIT  | —         | U    | —     | Prosessin hallittu lopetus, laukaisee Int 8       |

**INT** laukaisee ohjelmallisen keskeytyksen annetulla vektorinumerolla (0–8). CPU suorittaa normaalin keskeytysprotokollan: tallentaa PC:n ja SR:n pinoon, siirtyy Kernel-tilaan ja estää keskeytykset. Käytetään järjestelmäkutsujen (syscall) toteuttamiseen — User-tilan ohjelma pyytää palvelua kerneliltä INT-käskyllä.

**IRET** (Interrupt Return) palaa keskeytyskäsittelijästä. Palauttaa ensin SR:n ja sitten PC:n pinosta. Koska SR sisältää P-bitin (privilege) ja I-bitin (interrupt enable), IRET palauttaa automaattisesti edellisen suojaustilan ja keskeytysasetuksen. Vaatii Kernel-tilan.

**STI** (Set Interrupt) asettaa SR:n I-bitin arvoon 1, mikä sallii laitteistokeskeytykset (näppäimistö, ajastin). Käytetään tyypillisesti käyttöjärjestelmän alustuksen lopussa, kun keskeytyskäsittelijät ovat paikoillaan. Vaatii Kernel-tilan.

**CLI** (Clear Interrupt) nollaa SR:n I-bitin, mikä estää kaikki laitteistokeskeytykset. Käytetään kriittisten osioiden suojaamiseen — esimerkiksi kun muokataan jaettuja tietorakenteita, joita keskeytykset voisivat häiritä. Vaatii Kernel-tilan.

**HALT** pysäyttää prosessorin. Suoritus päättyy ja CPU ei jatka käskyjen noutamista. Käytetään käyttöjärjestelmän sammutuksessa tai kriittisen virheen yhteydessä. Vaatii Kernel-tilan.

**EXIT** lopettaa nykyisen käyttäjäprosessin hallitusti laukaisemalla keskeytyksen Int 8. Tämä siirtää ohjauksen käyttöjärjestelmän prosessinhallinnan käsittelijään, joka voi siivota prosessin resurssit ja siirtyä seuraavaan prosessiin. Toisin kuin HALT, EXIT on sallittu User-tilassa.

## 7.9 Järjestelmä- ja I/O-käskyt

| Opcode | Käsky  | Operandit  | Tila | Liput | Kuvaus                                          |
| ------ | ------ | ---------- | ---- | ----- | ----------------------------------------------- |
| 0x0045 | DREAD  | regD, regS | K    | —     | `regD ← storage[regS]`                         |
| 0x0046 | DWRITE | regS, regD | K    | —     | `storage[regD] ← regS`                         |
| 0x0047 | SMPR   | reg        | K    | —     | `MPR ← reg`                                    |
| 0x0048 | STMR   | reg        | K    | —     | `TMR ← reg`                                    |
| 0x004A | KGET   | reg        | U    | —     | `reg ← keyboard_buffer` (0 jos tyhjä)          |
| 0x004B | TSL    | reg, addr  | U    | ZN——  | `reg ← [addr]; [addr] ← 1` (atominen)         |

**DREAD** (Device Read) lukee yhden sanan tallennuslaitteelta (block device). Lähderekisteri sisältää lukuosoitteen tallennuslaitteen muistiavaruudessa (0x0000–0xFFFF), ja luettu arvo tallennetaan kohderekisteriin. Käytetään käyttöjärjestelmän bootloaderissa ja levyoperaatioissa. Vaatii Kernel-tilan.

**DWRITE** (Device Write) kirjoittaa lähderekisterin arvon tallennuslaitteelle kohderekisterin ilmoittamaan osoitteeseen. Käytetään datan pysyvään tallentamiseen — esimerkiksi tiedostojärjestelmän toteutuksessa. Vaatii Kernel-tilan.

**SMPR** (Set MPR) asettaa muistisuojarekisterin (Memory Protection Register) arvon. MPR määrittää User-tilan muistialueen alarajan: User-tilassa kaikki muistiosoitteet < MPR ovat kiellettyjä (paitsi Video RAM). Käytetään käyttöjärjestelmässä prosessin käynnistyksen yhteydessä eristämään käyttäjäprosessi kernel-muistista. Vaatii Kernel-tilan.

**STMR** (Set TMR) asettaa ajastinrekisterin (Timer Register) arvon. TMR määrittää, kuinka monen käskyn välein ajastinkeskeytys (Int 7) laukeaa. Arvo 0 kytkee ajastimen pois päältä. Käytetään preemptiivisen moniajon toteuttamiseen: käyttöjärjestelmä asettaa aikavälin, ja ajastinkeskeytys pakottaa prosessinvaihdon tasaisin välein. Vaatii Kernel-tilan.

**KGET** (Keyboard Get) lukee yhden merkin näppäimistön FIFO-puskurista rekisteriin. Jos puskuri on tyhjä, rekisteriin asetetaan 0. Käytetään tyypillisesti näppäimistökeskeytyksen (Int 6) käsittelijässä lukemaan painettu näppäin. Sallittu User-tilassa.

**TSL** (Test and Set Lock) suorittaa atomisen luku-ja-kirjoitusoperaation: lukee muistiosoitteen arvon rekisteriin ja kirjoittaa samaan osoitteeseen arvon 1. Operaatio on jakamaton — keskeytys ei voi tapahtua lukemisen ja kirjoittamisen välissä. Päivittää Z- ja N-liput luetun arvon perusteella. Käytetään keskinäisen poissulkemisen (mutex) toteuttamiseen moniajossa: jos luettu arvo oli 0, lukko saatiin haltuun; jos 1, lukko oli jo varattu.

---

# 8. Oheislaitteet

## 8.1 Näppäimistö

- Jonopohjainen FIFO-puskuri
- Kun käyttäjä painaa näppäintä, ASCII-arvo lisätään jonoon ja CPU laukaisee **Int 6**
- Keskeytysrutiini lukee näppäimen `KGET`-käskyllä
- Jos jono on tyhjä, KGET palauttaa 0

## 8.2 Tallennuslaite (Block Device)

- Koko: 65 536 sanaa (0x0000–0xFFFF), kukin 16-bittinen
- Pääsy vain Kernel-tilassa `DREAD`- ja `DWRITE`-käskyillä
- Käytetään käyttöjärjestelmän ja ohjelmien pysyvään tallennukseen

---

# 9. Käynnistysprosessi (Boot)

Kylmäkäynnistyksen (cold boot) vaiheet:

| Vaihe | Toiminta                                                                  |
| ----- | ------------------------------------------------------------------------- |
| 1     | CPU käynnistyy Kernel-tilassa (P=1, I=0)                                  |
| 2     | Kaikki rekisterit nollataan, SP ← 0xFFFF, PC ← 0x0100                    |
| 3     | Laitteisto lukee tallennuslaitteen osoitteet 0x0000–0x00FF (256 sanaa)     |
| 4     | Data kopioidaan RAM-osoitteisiin $0100–$01FF (bootloader-alue)             |
| 5     | Suoritus alkaa osoitteesta $0100                                          |

Tallennuslaitteen aluejako:

| Osoiteväli      | Kuvaus                                                |
| --------------- | ----------------------------------------------------- |
| 0x0000 – 0x00FF | Bootloader / Master Boot Record (ladataan automaattisesti) |
| 0x0100 – 0xFFFF | Vapaa tallennustila (OS, ohjelmat, data)              |

---

# 10. Assembler-syntaksi

## 10.1 Yleismuoto

```asm
label:                  ; Label (valinnainen, omalla rivillä)
    MNEMONIC op1, op2   ; Käsky operandeineen
                        ; Kommentit puolipisteellä
```

## 10.2 Operandien merkintätavat

| Syntaksi      | Tyyppi                  | Esimerkki            |
| ------------- | ----------------------- | -------------------- |
| `R0`–`SP`     | Rekisteri               | `ADD R0, R1`         |
| `#42`         | Välitön arvo (decimal)  | `LOAD R0, #42`       |
| `#0xFF`       | Välitön arvo (hex)      | `LOAD R0, #0xFF`     |
| `$F800`       | Absoluuttinen osoite    | `READ R0, $F800`     |
| `label`       | Label-viittaus          | `JUMP loop`          |

## 10.3 Direktiivit

| Direktiivi              | Kuvaus                                              |
| ----------------------- | --------------------------------------------------- |
| `.origin addr` / `.org` | Aseta koodin aloitusosoite (oletus: 0x0100)         |
| `.macro NIMI`           | Aloita makromäärittely                              |
| `.endmacro`             | Lopeta makromäärittely                              |

## 10.4 Assembly-esimerkki

```asm
.origin 0x0200

; Laske 10+20 ja tallenna tulos muistiin
start:
    LOAD  R0, #10
    LOAD  R1, #20
    ADD   R0, R1        ; R0 = 30
    STORE R0, $3000     ; [0x3000] = 30
    HALT
```

---

# 11. Opcode-kartta (yhteenveto)

## 11.1 Kaikki käskyt aakkosellisesti järjestettynä

| Opcode | Käsky     | Sanat | Kuvaus                                           |
| ------ | --------- | ----- | ------------------------------------------------ |
| 0x0001 | LOAD      | 3     | Lataa välitön arvo rekisteriin                   |
| 0x0002 | CPY       | 3     | Kopioi rekisterien arvot keskenään               |
| 0x0003 | READ      | 3     | Lue muistista absoluuttisesti                    |
| 0x0004 | STORE     | 3     | Kirjoita muistiin absoluuttisesti                |
| 0x0005 | READ_IND  | 3     | Lue muistista epäsuorasti (osoitinta käyttäen)  |
| 0x0006 | STORE_IND | 3     | Kirjoita muistiin epäsuorasti (osoitinta käyttäen) |
| 0x0007 | READ_REL  | 3     | Lue muistista FP-suhteellisesti                  |
| 0x0008 | STORE_REL | 3     | Kirjoita muistiin FP-suhteellisesti              |
| 0x0010 | ADD       | 3     | Yhteenlasku: regD = regD + regS                  |
| 0x0011 | SUB       | 3     | Vähennyslasku: regD = regD - regS                |
| 0x0012 | MUL       | 3     | Kertolasku: regD = regD × regS                   |
| 0x0013 | DIV       | 3     | Kokonaislukujako: regD = regD ÷ regS             |
| 0x0014 | CMP       | 3     | Vertailu: aseta liput regA - regB:n perusteella  |
| 0x0015 | AND       | 3     | Bittitason JA-operaatio                          |
| 0x0016 | OR        | 3     | Bittitason TAI-operaatio                         |
| 0x0017 | XOR       | 3     | Bittitason poissulkeva TAI                       |
| 0x0018 | NOT       | 2     | Bittitason komplementti (käännä kaikki bitit)    |
| 0x0019 | SHL       | 3     | Looginen vasen siirto                            |
| 0x001A | SHR       | 3     | Looginen oikea siirto                            |
| 0x001B | ADC       | 3     | Yhteenlasku carry:lla: regD = regD + regS + C   |
| 0x0020 | PUSH      | 2     | Talleta rekisteri pinoon                         |
| 0x0021 | POP       | 2     | Hae arvo pinosta rekisteriin                     |
| 0x0022 | SWSP      | 3     | Vaihda pinorekisteri atomisesti                  |
| 0x0030 | JUMP      | 2     | Ehdoton hyppy (PC = addr)                        |
| 0x0031 | CALL      | 2     | Kutsu aliohjelmaa (PUSH PC; PC = addr)           |
| 0x0032 | RET       | 1     | Palaa aliohjelmasta (POP PC)                     |
| 0x0033 | JZ        | 2     | Hyppy jos yhtä suuri (Z = 1), alias: JE         |
| 0x0034 | JNZ       | 2     | Hyppy jos eri suuruinen (Z = 0), alias: JNE     |
| 0x0035 | JLT       | 2     | Hyppy jos pienempi (etumerkillinen, N ≠ V)      |
| 0x0036 | JGT       | 2     | Hyppy jos suurempi (etumerkillinen, Z=0 ∧ N=V)  |
| 0x0037 | JLE       | 2     | Hyppy jos pienempi tai yhtä suuri (Z=1 ∨ N≠V)   |
| 0x0038 | JGE       | 2     | Hyppy jos suurempi tai yhtä suuri (N = V)       |
| 0x0040 | INT       | 2     | Laukaise ohjelmallinen keskeytys (0–8)          |
| 0x0041 | IRET      | 1     | Palaa keskeytyksestä (POP SR; POP PC)            |
| 0x0042 | STI       | 1     | Salli keskeytykset (I = 1, Kernel-tila)         |
| 0x0043 | CLI       | 1     | Estä keskeytykset (I = 0, Kernel-tila)          |
| 0x0044 | HALT      | 1     | Pysäytä prosessori (Kernel-tila)                |
| 0x0045 | DREAD     | 3     | Lue tallennuslaitteelta (Kernel-tila)           |
| 0x0046 | DWRITE    | 3     | Kirjoita tallennuslaitteelle (Kernel-tila)      |
| 0x0047 | SMPR      | 2     | Aseta muistisuojarekisteri (Kernel-tila)        |
| 0x0048 | STMR      | 2     | Aseta ajastinrekisteri (Kernel-tila)            |
| 0x0049 | EXIT      | 1     | Prosessin hallittu lopetus (Int 8)               |
| 0x004A | KGET      | 2     | Lue näppäimistön puskurista                      |
| 0x004B | TSL       | 3     | Atominen testi ja asetus (Test and Set Lock)    |

## 11.2 Käskyt kategorioittain

### Tiedonsiirto (0x0001–0x0008)

| Käsky     | Opcode | Kuvaus |
| --------- | ------ | ------ |
| LOAD      | 0x0001 | Lataa välitön 16-bittinen arvo rekisteriin |
| CPY       | 0x0002 | Kopioi yhden rekisterin sisältö toiseen rekisteriin |
| READ      | 0x0003 | Lue yhden sanan muistista absoluuttisella osoitteella |
| STORE     | 0x0004 | Kirjoita yhden sanan muistiin absoluuttisella osoitteella |
| READ_IND  | 0x0005 | Lue muistista käyttäen rekisterissa olevaa osoitetta (epäsuorasti) |
| STORE_IND | 0x0006 | Kirjoita muistiin käyttäen rekisterissa olevaa osoitetta |
| READ_REL  | 0x0007 | Lue muistista frame pointerin suhteen (paikallismuuttujat) |
| STORE_REL | 0x0008 | Kirjoita muistiin frame pointerin suhteen |

### Aritmetiikka (0x0010–0x0015)

| Käsky | Opcode | Kuvaus |
| ----- | ------ | ------ |
| ADD   | 0x0010 | Yhteenlasku kahdelle rekisterille, aseta liput (Z, N, C, V) |
| SUB   | 0x0011 | Vähennyslasku, aseta liput |
| MUL   | 0x0012 | Kertolasku, tallennetaan alin 16 bittiä, C-lippu ylivuodolle |
| DIV   | 0x0013 | Kokonaislukujako, nollalla jako laukaisee Int 0 |
| CMP   | 0x0014 | Vertailu: laskee erotus ja asettaa liput ilman tuloksen tallentamista |
| ADC   | 0x001B | Yhteenlasku carry-lipun kanssa, 32+ -bittiselle aritmetiikalle |

### Logiikat ja bittioperaatiot (0x0015–0x001A)

| Käsky | Opcode | Kuvaus |
| ----- | ------ | ------ |
| AND   | 0x0015 | Bittitason JA, käytetään maskiille (nollaa C ja V) |
| OR    | 0x0016 | Bittitason TAI, bittien asettamiseen päälle |
| XOR   | 0x0017 | Bittitason JOKO-TAI, käytetään bittien kääntöön ja yksinkertaiseen salaukseen |
| NOT   | 0x0018 | Bittitason komplementti, kääntää kaikki bitit |
| SHL   | 0x0019 | Looginen vasen siirto N-verran, oikea täytetään nollilla |
| SHR   | 0x001A | Looginen oikea siirto N-verran, vasen täytetään nollilla |

### Pino (0x0020–0x0022)

| Käsky | Opcode | Kuvaus |
| ----- | ------ | ------ |
| PUSH  | 0x0020 | Talleta rekisterin arvo pinoon, vähennä SP:tä yhdellä |
| POP   | 0x0021 | Lisää SP:tä yhdellä, hae arvo pinosta rekisteriin |
| SWSP  | 0x0022 | Atominen pinorekisterin vaihto (ctx switch), ei keskeytyksiä |

### Ohjaus (0x0030–0x0038)

| Käsky | Opcode | Kuvaus |
| ----- | ------ | ------ |
| JUMP  | 0x0030 | Ehdoton hyppy absoluuttiselle osoitteelle |
| CALL  | 0x0031 | Kutsu aliohjelmaa: talleta paluuosoite ja hyppy |
| RET   | 0x0032 | Palaa aliohjelmasta palauttamalla PC pinosta |
| JZ    | 0x0033 | Ehdollinen hyppy, jos Z-lippu = 1 (yhtä suuret), alias: JE |
| JNZ   | 0x0034 | Ehdollinen hyppy, jos Z-lippu = 0 (eri suuruiset), alias: JNE |
| JLT   | 0x0035 | Ehdollinen hyppy, jos etumerkillisesti pienempi (signed) |
| JGT   | 0x0036 | Ehdollinen hyppy, jos etumerkillisesti suurempi |
| JLE   | 0x0037 | Ehdollinen hyppy, jos etumerkillisesti pienempi tai yhtä suuri |
| JGE   | 0x0038 | Ehdollinen hyppy, jos etumerkillisesti suurempi tai yhtä suuri |

### Keskeytys (0x0040–0x0044)

| Käsky | Opcode | Kuvaus |
| ----- | ------ | ------ |
| INT   | 0x0040 | Laukaise ohjelmallinen keskeytys vektorilla 0–8 (syscall) |
| IRET  | 0x0041 | Palaa keskeytyskäsittelijästä, palauta SR ja PC, vaatii Kernel-tilan |
| STI   | 0x0042 | Salli laitteistokeskeytykset (I = 1), vaatii Kernel-tilan |
| CLI   | 0x0043 | Estä laitteistokeskeytykset (I = 0), vaatii Kernel-tilan |
| HALT  | 0x0044 | Pysäytä prosessori kokonaan, vaatii Kernel-tilan |

### Järjestelmä ja I/O (0x0045–0x004B)

| Käsky     | Opcode | Kuvaus |
| --------- | ------ | ------ |
| DREAD     | 0x0045 | Lue tallennuslaitteelta (block device), vaatii Kernel-tilan |
| DWRITE    | 0x0046 | Kirjoita tallennuslaitteelle, vaatii Kernel-tilan |
| SMPR      | 0x0047 | Aseta Memory Protection Register, vaatii Kernel-tilan |
| STMR      | 0x0048 | Aseta Timer Register (ajastinväli), vaatii Kernel-tilan |
| EXIT      | 0x0049 | Prosessin hallittu lopetus, laukaisee Int 8 |
| KGET      | 0x004A | Lue merkki näppäimistön FIFO-puskurista, palauttaa 0 jos tyhjä |
| TSL       | 0x004B | Atominen testi ja asetus: lue [addr] ja kirjoita 1, mutex-käyttöön |
