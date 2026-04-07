# kCPU16 BASIC-tulkki – Suunnitelma

Versio 1.0

Tämä dokumentti kuvaa suunnitelman yksinkertaisen BASIC-tulkin toteuttamiseksi kCPU16-prosessorin assemblerilla. Tulkki toimii vain tekstitilassa (80×24 merkkiä) ilman grafiikkatukea.

---

## 1. Yleiskatsaus

Tulkki on interaktiivinen REPL-ympäristö (Read–Eval–Print Loop), johon käyttäjä kirjoittaa BASIC-ohjelmaa rivi kerrallaan. Rivinumerollinen syöte tallennetaan ohjelmapuskuriin; numero-ton syöte suoritetaan välittömästi. Käyttäjä voi tallentaa yhden ohjelman tallennuslaitteelle ja ladata sen myöhemmin takaisin.

### Tärkeimmät vaatimukset

| Vaatimus | Tila |
|---|---|
| Tekstitilan I/O (80×24) | Toteutettavissa |
| Rivinumeroiden uudelleennumerointi (RENUM) | Toteutettavissa |
| Ohjelman tallennus tallennuslaitteelle | Toteutettavissa (Kernel-tila vaaditaan) |
| Ohjelman lataaminen tallennuslaitteelta | Toteutettavissa (Kernel-tila vaaditaan) |
| Grafiikkatuki | **Ei toteuteta** (tekstitila riittää) |

---

## 2. Tuettu BASIC-syntaksi

Tulkki tukee seuraavaa minimaalista komentojoukkoa:

### 2.1 Lauseet (Statements)

| Lause | Kuvaus | Esimerkki |
|---|---|---|
| `PRINT expr` | Tulostaa lausekkeen arvon tai merkkijonon | `PRINT "HELLO"`, `PRINT X+1` |
| `INPUT var` | Lukee kokonaisluvun muuttujaan | `INPUT X` |
| `LET var = expr` | Sijoittaa arvon muuttujaan | `LET X = 42` |
| `IF expr THEN lnum` | Ehdollinen hyppy | `IF X > 0 THEN 100` |
| `GOTO lnum` | Ehdoton hyppy rivinumeroon | `GOTO 10` |
| `GOSUB lnum` | Aliohjelma-kutsu | `GOSUB 500` |
| `RETURN` | Palaa GOSUB-kutsusta | `RETURN` |
| `FOR var = expr TO expr` | Silmukka | `FOR I = 1 TO 10` |
| `NEXT var` | Silmukan askel | `NEXT I` |
| `END` | Ohjelman lopetus | `END` |
| `REM teksti` | Kommentti | `REM tämä on kommentti` |

### 2.2 Systeemikomennot (ei rivinumeroita)

| Komento | Kuvaus |
|---|---|
| `LIST` | Näyttää ohjelman rivit järjestyksessä |
| `RUN` | Suorittaa ohjelman alusta |
| `NEW` | Tyhjentää ohjelmapuskurin |
| `SAVE` | Tallentaa ohjelman tallennuslaitteelle |
| `LOAD` | Lataa ohjelman tallennuslaitteelta |
| `RENUM [alku [askel]]` | Numeroi rivit uudelleen (oletus: alku=10, askel=10) |

### 2.3 Lausekkeet (Expressions)

- **Kokonaisluvut:** 16-bittinen merkillinen kokonaislukulaskenta (−32 768 … 32 767)
- **Muuttujat:** Yksikirjaimiset nimet A–Z (26 muuttujaa)
- **Operaattorit:** `+`, `-`, `*`, `/` (kokonaislukujako), `=`, `<`, `>`, `<>`, `<=`, `>=`
- **Merkkijonoliteraalit:** Vain `PRINT`-lauseessa (`"teksti"`)

> **Huomio:** Liukulukuja ei tueta. kCPU16:ssa ei ole liukulukukäskyjä, ja ohjelmistototeutus veisi huomattavasti muistia ja suoritusaikaa.

---

## 3. Muistikartta

Tulkki käyttää vapaata RAM-aluetta (0x0200–0xF7FF) seuraavasti:

```
0x0000–0x0008   Keskeytysvektoritaulu (käyttöjärjestelmä)
0x0009–0x00FF   OS-varattu alue
0x0100–0x01FF   Käynnistyslatain (bootloader)
0x0200–0x02FF   Tulkin koodi – pääsilmukka ja apufunktiot (256 sanaa)
0x0300–0x05FF   Tulkin koodi – jatkuu (768 sanaa)
0x0600–0x06FF   Syötepuskuri (input line buffer, 256 sanaa)
0x0700–0x071A   Muuttujat A–Z (26 × 1 sana)
0x0800–0x0FFF   Ohjelmapuskuri (2048 sanaa, ~512 riviä)
0x1000–0x10FF   GOSUB-paluupinot (256 sanaa, enint. 64 tasoa)
0x1100–0x11FF   FOR-silmukkapino (256 sanaa, enint. 32 silmukkaa)
0x1200–0x12FF   Rivinumeroindeksi (128 paria: rivinro + osoitin)
0x1300–0xF7FF   Vapaa alue (tulkin laajennus tai tuleville tarpeille)
0xF800–0xFF7F   Video-RAM (80×24 näyttö)
0xFF80–0xFFFF   Kernel-pino
```

---

## 4. Ohjelmapuskurin rakenne

Ohjelmapuskuri (0x0800–0x0FFF) tallentaa rivit kiinteässä muodossa:

```
Jokainen rivi:
  +0   rivinumero (1 sana, 0 = puskurin loppu)
  +1   tokenien lukumäärä (1 sana)
  +2…  tokenit (enintään 30 sanaa/rivi)
```

- Rivit tallennetaan **järjestyksessä** rivinumeron mukaan.
- Uuden rivin lisäys tai poisto vaatii puskurin osittaisen uudelleenjärjestelyn.
- Puskurin maksimikoko ~512 riviä (2 048 sanaa / ~4 sanaa/rivi keskimäärin).

### 4.1 Tokenisaatio

Jäsennin muuntaa tekstirivin tokeneiksi ennen tallennusta:

| Tokenityyppi | Arvo |
|---|---|
| Avainsana (PRINT jne.) | 0x0100–0x01FF |
| Kokonaisluku | 0x0200–0x02FF (seuraava sana = arvo) |
| Muuttuja A–Z | 0x0300–0x031A |
| Operaattori `+` `-` `*` `/` | 0x0400–0x0403 |
| Vertailu `=` `<` `>` `<>` `<=` `>=` | 0x0410–0x0415 |
| Merkkijono | 0x0500 (seuraavat sanat = ASCII, lopussa 0x0000) |

---

## 5. Rivinumeroiden uudelleennumerointi (RENUM)

`RENUM [alku [askel]]` -komento:

1. Käy ohjelmapuskuri läpi järjestyksessä.
2. Rakentaa muunnostaulukon: `vanha_rivinro → uusi_rivinro`.
3. Päivittää kunkin rivin rivinumerokentän.
4. Käy puskurin uudelleen läpi ja korvaa kaikki `GOTO`-, `GOSUB`- ja `IF…THEN`-lauseiden rivinumerotokenit uusilla arvoilla muunnostaulukon avulla.
5. Päivittää rivinumeroindeksin (0x1200–).

**Esimerkki:**
```
Ennen RENUM:      Jälkeen RENUM 10, 10:
  5 PRINT "A"       10 PRINT "A"
  7 GOTO 5          20 GOTO 10
 20 END             30 END
```

---

## 6. Tallennus ja lataaminen

### 6.1 Tallennuslaite ja käyttöoikeudet

`DREAD` ja `DWRITE` -käskyt ovat vain Kernel-tilassa käytettävissä. Tulkin täytyy toimia Kernel-tilassa tai käyttää keskeytyspalvelua (syscall) tallennusoperaatioihin.

### 6.2 Tallennusasettelu (yksi ohjelma)

Ohjelma tallennetaan laitteen lohkoihin 1–16 (osoitteet 0x0100–0x10FF, yhteensä 4 096 sanaa):

```
Lohko 1 (0x0100–0x01FF):  Ohjelman metatiedot
  +0x0000  tunniste (vakioarvo 0xBA5C = "BASC", mahtuu 16-bittiseen sanaan)
  +0x0001  ohjelmapuskurin sanamäärä
  +0x0002  reserved

Lohkot 2–16 (0x0200–0x10FF):  Ohjelmapuskurin data
  (kopio RAM-ohjelmapuskurista 0x0800–0x0FFF)
```

### 6.3 SAVE-operaation kulku

1. Kirjoita metatiedot lohkoon 1.
2. Kopioi ohjelmapuskuri (0x0800–0x0FFF) DWRITE-käskyllä tallennuslaitteelle lohkoihin 2–16.
3. Näytä "OK" tai virheviesti.

### 6.4 LOAD-operaation kulku

1. Lue lohko 1, tarkista tunniste (0xBA5C).
2. Jos tunniste on väärä: näytä "NO PROGRAM" ja keskeytä.
3. Kopioi tallennuslaite-lohkot 2–16 ohjelmapuskuriin (0x0800–0x0FFF) DREAD-käskyllä.
4. Päivitä rivinumeroindeksi (0x1200–).
5. Näytä "OK".

---

## 7. Tekstinäyttö ja näppäimistö

### 7.1 Näytön ohjaus

- Kirjoitetaan suoraan Video-RAM:iin (0xF800–0xFF7F).
- Kursori pidetään omassa muuttujassa (sarake 0–79, rivi 0–23).
- Rivinvaihto: sarake → 0, rivi++. Jos rivi = 24, rullaa näyttöä ylöspäin (kopioi rivit 1–23 riveille 0–22, tyhjennä rivi 23).
- Merkin tulostus: `charWord = charCode | (foreColor << 8)`, kirjoitetaan osoitteeseen `0xF800 + rivi * 80 + sarake`.

### 7.2 Syötteen lukeminen

- Näppäimistö keskeytys Int 6 aktivoi näppäimistönkäsittelijän, joka lisää merkin syötepuskuriin.
- Tulkin pääsilmukka odottaa rivinvaihtoa (`\n`, 0x0A), jonka jälkeen käsittelee koko rivin.
- Syötemuokkaus: askelpalautin poistaa viimeisen merkin syötepuskurista ja näytöltä.

---

## 8. Moduulirakenne (assembly-tasolla)

| Moduuli | Osoite (arvio) | Kuvaus |
|---|---|---|
| `main` | 0x0200 | Pääsilmukka, alustus |
| `input_handler` | 0x0280 | Näppäimistö + syötepuskuri |
| `tokenizer` | 0x0300 | Tekstirivin muunto tokeneiksi |
| `parser` | 0x0400 | Tokenien jäsennys lauseiksi |
| `executor` | 0x0500 | Lauseiden suoritus |
| `expr_eval` | 0x0600 | Lausekkeiden evaluointi (rekursiivinen lasku) |
| `display` | 0x0680 | Merkki/merkkijono näytölle, rullaus |
| `program_buf` | 0x06C0 | Puskurin lisäys, poisto, haku |
| `renum` | 0x0700 | RENUM-algoritmi |
| `storage` | 0x0740 | SAVE/LOAD (DREAD/DWRITE) |
| `line_index` | 0x0780 | Rivinumeroindeksin ylläpito |

---

## 9. Suorituksen hallinta

### 9.1 RUN-komento

1. Aseta suorituskursori ohjelmapuskurin alkuun.
2. Hae seuraava rivi, suorita sen lause(et).
3. Jos `GOTO`/`GOSUB`: hae rivinumeroindeksistä kohdan osoitin, hyppää sinne.
4. Jos `END` tai puskurin loppu: lopeta suoritus, palaa REPL-tilaan.

### 9.2 FOR–NEXT -silmukka

- `FOR`-lauseen yhteydessä tallennettaan silmukkapinoon: muuttuja, nykyarvo, raja-arvo, askel (oletus 1), paluuosoitin (puskuriindeksi).
- `NEXT`-lauseessa: kasvata muuttujaa, tarkista raja, hyppää silmukan alkuun tai jatka eteenpäin.

### 9.3 GOSUB–RETURN

- `GOSUB` tallentaa nykyisen puskuriindeksin GOSUB-pinoon (0x1000–0x10FF) ja hyppää kohderiviin.
- `RETURN` palauttaa pinosta tallennetun indeksin.
- Pinosyvyys enintään 64 tasoa (256 sanaa / 4 sanaa/kehys).

---

## 10. kCPU16:n rajoitukset

| Rajoitus | Vaikutus BASIC-tulkkiin |
|---|---|
| Vain kokonaislukuaritmetiikka (16-bittinen) | Ei liukulukumuuttujia. Kaikki laskenta on kokonaislukuaritmetiikkaa välillä −32 768 … 32 767. |
| Vain 4 yleiskäyttöistä rekisteriä (R0–R3) | Lausekkeiden evaluointi vaatii paljon väliaikaistallennuksia muistiin; rekursiiviset lausekkeet monimutkaisempia toteuttaa. |
| Pino sijaitsee vain 128 sanan alueella (0xFF80–0xFFFF) | Tulkin oma ajonaikainen pino (GOSUB/FOR) toteutetaan RAM-alueella 0x1000–0x11FF, ei laitteistopinolla. |
| `DREAD`/`DWRITE` vaativat Kernel-tilan | Tulkki täytyy ajaa Kernel-tilassa tai tallennusoperaatiot pitää toteuttaa syscall-mekanismilla. |
| Ei merkkijonoaritmetiikkaa | `PRINT` tukee merkkijonoliteraaleja, mutta merkkijonomuuttujia tai -operaatioita ei toteuteta. |
| Ei modulo-käskyä | Jakojäännös lasketaan: `mod = a - (a / b) * b` (kolme operaatiota). |
| Ei dynaamista muistinhallintaa | Muistin rakenne on kiinteä; ohjelman enimmäiskoko rajoitettu puskurin kokoon (~512 riviä). |

---

## 11. Toteutuksen vaiheistus

1. **Vaihe 1 – Perusrakenne:** Alustus, REPL-pääsilmukka, näppäimistön luku, merkin tulostus näytölle.
2. **Vaihe 2 – Tokenisaattori ja jäsennin:** Tekstirivin muunto tokeneiksi, systeemikomennot (NEW, LIST, RUN).
3. **Vaihe 3 – Lauseiden suoritus:** PRINT, LET, IF/THEN, GOTO, END.
4. **Vaihe 4 – Lausekkeiden evaluointi:** Aritmeettiset lausekkeet (+, -, *, /), vertailut.
5. **Vaihe 5 – Aliohjelmakutsut:** GOSUB/RETURN, FOR/NEXT.
6. **Vaihe 6 – RENUM:** Uudelleennumerointi ja GOTO/GOSUB-viitteiden päivitys.
7. **Vaihe 7 – SAVE/LOAD:** Tallennuslaitteen käyttö ohjelman pysyväistallennukseen.
8. **Vaihe 8 – Testaus ja hienosäätö:** Muistinkäytön optimointi, virheviestit, reunatapaukset.
