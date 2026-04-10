# CHIP-8 kCPU16:ssa — tilannekatsaus ja päivitetty suunnitelma

Versio 2.0 — 2026-04-10

---

## 1. Mikä on nykytila?

Tämä dokumentti on päivitetty vastaamaan kCPU16-projektin nykytilaa.

**Tilanne nyt:**
- kCPU16:ssa **ei ole vielä toteutettua CHIP-8-emulaattoria**.
- `docs/chip-8/` sisältää CHIP-8-lähdemateriaalia (referenssidokumentteja).
- `docs/suunnitelmat/chip-8.md` on ollut aiemmin laaja toteutettavuusanalyysi; tämä versio on käytännön tilannekuva ja etenemispolku nykyiselle koodipohjalle.

---

## 2. kCPU16:n nykyiset ominaisuudet, jotka tukevat CHIP-8-toteutusta

Seuraavat ominaisuudet ovat jo olemassa ja hyödyllisiä CHIP-8-emulaattorille:

### 2.1 CPU ja muistimalli
- 16-bittinen sanaosoitteinen muisti (`0x0000–0xFFFF`)
- Yleiskäyttörekisterit `R0–R15` sekä `FP`, `SP`
- Ehdolliset hypyt, pino-operaatiot, bittioperaatiot ja perusaritmetiikka
- Indeksoidut hyppy-/kutsukäskyt (`JMPI`, `CALLI`) dispatch-rakenteiden toteutukseen

### 2.2 Assemblerin valmiudet
- `.include`-direktiivi (modulaarinen lähdekoodirakenne)
- `.db`, `.dw`, `.dstr`, `.const`, `.macro`, `.origin`, `.at`
- Testidirektiivit (`.expect_*`) sekä näppäimistön injektointi (`.inject_key`, `.inject_key_release`)

### 2.3 Laitteet ja MMIO
- Näppäimistö MMIO:ssa:
  - `KBD_DATA` (`0x0020`): lukeminen palauttaa/poppaa seuraavan tapahtuman
  - `KBD_STATUS` (`0x0021`): jonon koko
  - vapautustapahtuma bitillä `0x80`
- Satunnaisluku MMIO:ssa:
  - `RAND_MMIO` (`0x0022`), LFSR-pohjainen
- Ajastimet:
  - `TMR` (käskymääräpohjainen)
  - `CTMR` (ms-pohjainen, `SCTMR`)

### 2.4 Näyttö
- Nykyinen näyttö on teksti/attribuuttipohjainen VRAM (`0xF800–0xFF7F`)
- Tämä ei ole suoraan CHIP-8:n 64×32 1bpp -framebuffer, joten renderöinti vaatii muunnoskerroksen

---

## 3. Mitä puuttuu vielä CHIP-8-emulaattorista?

CHIP-8-toteutus tarvitsee edelleen vähintään:

1. **Emulaattorin tila**
   - CHIP-8-muisti (4 KB), V0–VF, I, PC, SP, stack, DT, ST
2. **Fetch/decode/execute-silmukka**
   - 16-bittisen opcode-sanamuodon purku nibble-kenttiin
3. **Käskyjen toteutus**
   - koko keskeinen CHIP-8-opcodejoukko (ohjaus, ALU, muistikäskyt, näppäimistö, ajastimet, piirto)
4. **Grafiikkapolku**
   - 64×32 framebuffer + XOR-piirto + collision-lippu (VF)
   - muunto kCPU16:n näyttömuotoon
5. **ROM-latauspolku**
   - ROM-bittien siirto CHIP-8-muistiin osoitteesta `0x200`
6. **Yhteensopivuuslinjaukset**
   - esim. shift-opcodejen ja wrapping/clip-käytöksen valittu tulkintamalli

---

## 4. Päivitetyt suunnittelupäätökset nykyiselle kCPU16:lle

### 4.1 Muistimallin valinta emulaattorissa
Suositus pysyy samana: **1 CHIP-8 byte per 1 kCPU16 word**.

Perusteet:
- yksinkertainen osoitelaskenta
- helpompi debuggaus
- vähemmän bittipakkauslogiikkaa
- kCPU16-muistissa tila riittää

### 4.2 Näppäimistömalli
CHIP-8:n 16-näppäinen hex-keypad kannattaa toteuttaa:
- ylläpidettävänä 16-bittisenä key-state-maskina emulaattorin muistissa
- päivittyen `KBD_DATA`-tapahtumista (painallus/vapautus)

### 4.3 Satunnaisluku (CXNN)
`CXNN` kannattaa toteuttaa käyttämällä `RAND_MMIO`-lukua ja maskausta (`AND NN`).

### 4.4 Ajastimet (DT/ST)
- DT/ST pidetään emulaattorin omassa tilassa (8-bit maskaus)
- decrement kannattaa sitoa CTMR-pohjaiseen 60 Hz -tickiin tai emuloituun vastaavaan tikkiin

### 4.5 Dispatch
`JMPI`/`CALLI` mahdollistavat nyt selkeämmän taulukkopohjaisen dispatchin kuin aiemmassa dokumenttiversiossa oletettiin.

---

## 5. Realistinen toteutusjärjestys tästä eteenpäin

1. **Skeleton**: emulaattorin muistialueet, rekisterit, reset/init
2. **Fetch/Decode**: opcode-haku + nibble-kenttien purku
3. **Perusohjaus**: `JP`, `CALL`, `RET`, `SE/SNE`, `LD`, `ADD`
4. **ALU-ryhmä**: `8XY*`-käskyt + VF-semantiiikka
5. **Muisti**: `FX55`, `FX65`, `ANNN`, `FX1E`, `FX29`, `FX33`
6. **Näppäimistö**: `EX9E`, `EXA1`, `FX0A`
7. **Ajastimet**: `FX07`, `FX15`, `FX18`
8. **Piirto**: `DXYN` + collision + ruudun päivitys
9. **Yhteensopivuustestit**: opcode-testit + muutama tunnettu CHIP-8 ROM

---

## 6. Yhteenveto

- kCPU16:n nykyinen alusta on riittävän kypsä CHIP-8-emulaattorin toteuttamiseen.
- Aiemmin kriittiseksi arvioituja esteitä on poistunut (esim. dispatcher-rakenteita helpottavat käskyt, laaja MMIO-valikoima, assemblerin include-tuki).
- Varsinainen CHIP-8-emulaattorikoodi puuttuu edelleen, joten seuraava askel on toteuttaa emulaattorin ydin ja käskyjoukko vaiheittain.
