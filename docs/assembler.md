# kCPU16 Assembly-kieli

Tämä dokumentti kuvaa kCPU16:n assembly-kielen syntaksin, direktiivit, arkkitehtuurivakiot ja esimerkit.

Käskykannan kuvaukset, opcode-arvot ja lippuvaikutukset löytyvät [architecture.md](architecture.md#7-käskykanta).

---

# 1. Yleismuoto

```asm
label:                  ; Label (valinnainen, omalla rivillä tai käskyn edessä)
    MNEMONIC op1, op2   ; Käsky operandeineen
                        ; Kommentit puolipisteellä
```

- Mnemonikit ovat kirjainkoosta riippumattomia (`LOAD` = `load`)
- Rekisterinimet ovat kirjainkoosta riippumattomia (`R0` = `r0`)
- Labelit päättyvät kaksoispisteeseen määrittelyssä, mutta viitattaessa kaksoispisteen saa jättää pois
- Tyhjät rivit ja ylimääräiset välilyönnit ovat sallittuja

---

# 2. Operandien merkintätavat

| Syntaksi       | Tyyppi                                                 | Esimerkki              |
| -------------- | ------------------------------------------------------ | ---------------------- |
| `R0`–`SP`      | Rekisteri (kirjainkoosta riippumaton)                  | `ADD R0, R1`           |
| `42`           | Desimaali-literaali                                    | `LOAD R0, 42`          |
| `0xFF`         | Heksadesimaali-literaali                               | `LOAD R0, 0xFF`        |
| `0b1010`       | Binääri-literaali                                      | `LOAD R0, 0b1010`      |
| `0o52`         | Oktaali-literaali                                      | `LOAD R0, 0o52`        |
| `label`        | Label-viittaus                                         | `JUMP loop`            |
| `VRAM_START`   | Arkkitehtuurivakio (ks. kohta 4)                       | `LOAD R0, VRAM_START`  |
| `NIMI`         | Käyttäjän vakio (`.const`, ks. kohta 5)                | `LOAD R0, BUFFER_SIZE` |
| `[addr]`       | Absoluuttinen muistiosoite (ks. kohta 6)               | `LOAD R0, [0x3000]`    |
| `[reg]`        | Epäsuora muistiosoite rekisterin kautta (ks. kohta 6)  | `LOAD R0, [R1]`        |
| `[FP+offset]`  | FP-suhteellinen muistiosoite (ks. kohta 6)             | `LOAD R0, [FP+2]`      |

Rekisterit: `R0`, `R1`, `R2`, `R3`, `FP`, `SP`. Kirjainkoosta riippumaton.

---

# 3. Direktiivit

| Direktiivi                          | Kuvaus                                                                     |
| ----------------------------------- | -------------------------------------------------------------------------- |
| `.origin addr` / `.org addr`        | Aseta koodin aloitusosoite (oletus: 0x0100)                                |
| `.at addr`                          | Siirry uuteen muistiosoitteeseen (uusi koodisegmentti)                     |
| `.db val, val, …`                   | Tallenna raakoja 16-bittisiä sanoja suoraan muistiin                       |
| `.dstr "teksti"` / `.dstr 'teksti'` | Tallenna null-terminoitu merkkijono; escape: `\\` `\"` `\'` `\n` `\t` `\0` |
| `.diskblock N`                      | Assemblauksen jälkeen tallenna konekieli tallennuslaitteen blokkiin N      |
| `.const NIMI, ARVO`                 | Määrittele nimetty vakio (kokonaisluku tai heksa; ks. kohta 5)             |
| `.macro NIMI`                       | Aloita makromäärittely                                                     |
| `.endmacro`                         | Lopeta makromäärittely                                                     |
| `.expect_reg R, arvo`               | Testidirektiiivi: tarkista rekisterin arvo ajon jälkeen                    |
| `.expect_flag F, arvo`              | Testidirektiiivi: tarkista tipalipun arvo ajon jälkeen                     |
| `.expect_mem addr, arvo`            | Testidirektiiivi: tarkista muistipaikan arvo ajon jälkeen                  |

---

# 4. Arkkitehtuurivakiot

Assembler injektoi automaattisesti seuraavat vakiot koodin käyttöön label-niminä.
Ne voidaan käyttää suoraan operandeina ilman erillistä määrittelyä.

| Vakio            | Arvo   | Kuvaus                              |
| ---------------- | ------ | ----------------------------------- |
| `VRAM_START`     | 0xF800 | VRAM:n alkuosoite                   |
| `VRAM_END`       | 0xFF7F | VRAM:n loppuosoite (viimeinen solu) |
| `SCREEN_COLS`    | 80     | Näytön leveys sarakkeina            |
| `SCREEN_ROWS`    | 24     | Näytön korkeus riveinä              |
| `BOOT_RAM_START` | 0x0100 | Bootloaderin latausalue             |
| `INT_DIV_ZERO`   | 0      | Jako nollalla (vektori 0)           |
| `INT_UNKNOWN_OP` | 1      | Tuntematon käsky (vektori 1)        |
| `INT_STACK_OVER` | 2      | Pinon ylivuoto (vektori 2)          |
| `INT_DEBUG`      | 3      | Debug/breakpoint (vektori 3)        |
| `INT_PRIVILEGE`  | 4      | Privilege violation (vektori 4)     |
| `INT_MEM_FAULT`  | 5      | Muistisuojausrikkomus (vektori 5)   |
| `INT_KEYBOARD`   | 6      | Näppäimistökeskeytys (vektori 6)    |
| `INT_TIMER`      | 7      | Ajastinkeskeytys (vektori 7)        |
| `INT_EXIT`       | 8      | Prosessin lopetus (vektori 8)       |
| `COLOR_BLACK`    | 0      | Värikoodi: musta                    |
| `COLOR_RED`      | 1      | Värikoodi: punainen                 |
| `COLOR_GREEN`    | 2      | Värikoodi: vihreä                   |
| `COLOR_YELLOW`   | 3      | Värikoodi: keltainen                |
| `COLOR_BLUE`     | 4      | Värikoodi: sininen                  |
| `COLOR_MAGENTA`  | 5      | Värikoodi: magenta                  |
| `COLOR_CYAN`     | 6      | Värikoodi: syaani                   |
| `COLOR_WHITE`    | 7      | Värikoodi: valkoinen                |
| `SR_FLAG_Z`      | 0      | Tilarekisterin Z-lipun bittinumero  |
| `SR_FLAG_N`      | 1      | Tilarekisterin N-lipun bittinumero  |
| `SR_FLAG_C`      | 2      | Tilarekisterin C-lipun bittinumero  |
| `SR_FLAG_V`      | 3      | Tilarekisterin V-lipun bittinumero  |
| `SR_FLAG_I`      | 4      | Tilarekisterin I-lipun bittinumero  |
| `SR_FLAG_P`      | 5      | Tilarekisterin P-lipun bittinumero  |

---

# 5. Käyttäjän vakiot (.const)

Koodin luettavuuden parantamiseksi voi määritellä nimettyjä vakioita `.const`-direktiivillä.
Vakio näkyy koko tiedostossa ja sitä käytetään kuten arkkitehtuurivakiota.

```asm
.const BUFFER_SIZE, 256
.const DELAY,       0x0064
.const MAX_INT,     0x7FFF
```

| Sääntö    | Kuvaus                                                           |
| --------- | ---------------------------------------------------------------- |
| Syntaksi  | `.const NIMI, ARVO` — välilyönti tai pilkku erottimena           |
| Nimi      | Kirjainkoosta riippumaton; tallennetaan isoin kirjaimin          |
| Arvo      | Desimaali tai `0x`-heksaliteraali; leikataan 16-bittiseen sanaan |
| Järjestys | Voi sijaita missä tahansa kohtaa tiedostoa                       |

## 5.1 Symbolien yksillöllisyys

Kaikki symbolinimet ovat **globaalisti uniikkeja** kolmen nimiavaruuden kesken:

| Nimiavaruus         | Lähde                                    |
| ------------------- | ---------------------------------------- |
| Arkkitehtuurivakiot | Automaattisesti injektoitu (ks. kohta 4) |
| Käyttäjän vakiot    | `.const NIMI, ARVO` -direktiivi          |
| Labelit             | `NIMI:` -määrittely koodissa             |

Lisäksi rekisterinimet `R0`, `R1`, `R2`, `R3`, `FP`, `SP` ovat aina varattuja
eikä niitä voi käyttää minkäänlaisena symbolinimenä.

Kolliisiovirheiden esimerkkejä:

```
.const VRAM_START, 100     ; VIRHE: nimi on jo arkkitehtuurivakio
.const R0, 42              ; VIRHE: nimi on rekisterin nimi
.const MY_VAL, 10
.const MY_VAL, 20          ; VIRHE: .const 'MY_VAL' on jo määritelty

VRAM_START:                ; VIRHE: nimi on jo arkkitehtuurivakio
MY_CONST:                  ; VIRHE: nimi on jo .const-vakio
```

---

# 6. Muistiosoitustavat ja LOAD/STORE-syntaksi

Assembler tunnistaa kolme muistiosoitustapaa `LOAD`- ja `STORE`-käskyissä
hakasulkunotaatiolla `[...]`. Syntaksimuodot yksinkertaistavat ohjelmoijan työtä:
sen sijaan, että käytettäisiin erillisiä käskymnemoniikkoja (`READ`, `READ_IND`,
`STORE_IND` jne.), riittää tuttu `LOAD`/`STORE`-notaatio oikean hakasulkumuodon
kanssa.

## 6.1 Osoitusmoodit

| Syntaksi      | Osoitusmooodi | Selitys                                       |
| ------------- | ------------- | --------------------------------------------- |
| `[addr]`      | Absoluuttinen | Muistiosoite `addr` suoraan                   |
| `[reg]`       | Epäsuora      | Osoite on rekisterin arvo                     |
| `[FP+offset]` | Suhteellinen  | Osoite on `FP + offset` (aliohjelman kehys)   |

## 6.2 LOAD reg, \[...\]

`LOAD`-käsky hakasulkunotaatiolla lukee arvon muistista suoraan rekisteriin.

| Syntaksi              | Kääntyy käskyksi | Toiminta            |
| --------------------- | ---------------- | ------------------- |
| `LOAD reg, [addr]`    | `READ`           | `reg ← [addr]`      |
| `LOAD reg, [regS]`    | `READ_IND`       | `reg ← [regS]`      |
| `LOAD reg, [FP+offs]` | `READ_REL`       | `reg ← [FP + offs]` |

```asm
LOAD R0, [0x3000]       ; Lue osoitteesta 0x3000 (absoluuttinen)
LOAD R0, [R1]           ; Lue osoitteesta, jonka R1 sisältää (epäsuora)
LOAD R0, [FP+2]         ; Lue aliohjelman paikallismuuttuja indeksillä 2 (suhteellinen)
```

## 6.3 STORE \[...\], lähde

`STORE`-käsky hakasulkunotaatiolla kirjoittaa muistiin. Lähteeksi kelpaa rekisteri
tai välitön arvo (immediate). Kun lähde on välitön arvo, assembler tuottaa
automaattisesti `STOREI`-variantin.

| Syntaksi               | Kääntyy käskyksi | Toiminta              |
| ---------------------- | ---------------- | --------------------- |
| `STORE [addr], reg`    | `STORE`          | `[addr] ← reg`        |
| `STORE [addr], imm`    | `STOREI`         | `[addr] ← imm`        |
| `STORE [regD], reg`    | `STORE_IND`      | `[regD] ← reg`        |
| `STORE [regD], imm`    | `STOREI_IND`     | `[regD] ← imm`        |
| `STORE [FP+offs], reg` | `STORE_REL`      | `[FP + offs] ← reg`   |
| `STORE [FP+offs], imm` | `STOREI_REL`     | `[FP + offs] ← imm`   |

```asm
STORE [0x3000], R0      ; Kirjoita R0 osoitteeseen 0x3000 (absoluuttinen)
STORE [0x3000], 42      ; Kirjoita vakioarvo 42 osoitteeseen 0x3000 (absoluuttinen, välitön)
STORE [R1], R0          ; Kirjoita R0 osoitteeseen, jonka R1 sisältää (epäsuora)
STORE [R1], 0xFF        ; Kirjoita vakio 0xFF epäsuoraan osoitteeseen (välitön)
STORE [FP+2], R0        ; Tallenna R0 aliohjelman paikallismuuttujaan (suhteellinen)
STORE [FP+2], 99        ; Kirjoita välitön arvo paikallismuuttujaan (suhteellinen, välitön)
```

## 6.4 Vanhat mnemonikat (poistettu käytöstä)

Hakasulkunotaatio korvaa seuraavat erilliset käskymnemonikat, jotka on **poistettu
käytöstä**. Niiden käyttö suoraan assembly-koodissa tuottaa assemblointivirheen.

| Vanhentunut mnemoniikka   | Korvaava hakasulkunotaatio  |
| ------------------------- | --------------------------- |
| `READ reg, addr`          | `LOAD reg, [addr]`          |
| `READ_IND regD, regS`     | `LOAD regD, [regS]`         |
| `READ_REL reg, imm`       | `LOAD reg, [FP+imm]`        |
| `STORE reg, addr`         | `STORE [addr], reg`         |
| `STORE_IND regD, regS`    | `STORE [regD], regS`        |
| `STORE_REL reg, imm`      | `STORE [FP+imm], reg`       |
| `STOREI imm, addr`        | `STORE [addr], imm`         |
| `STOREI_IND regD, imm`    | `STORE [regD], imm`         |
| `STOREI_REL imm, offs`    | `STORE [FP+offs], imm`      |

---

# 7. Esimerkit

## 7.1 Peruslaskelma

```asm
.origin 0x0200

; Laske 10+20 ja tallenna tulos muistiin
start:
    LOAD  R0, 10
    LOAD  R1, 20
    ADD   R0, R1        ; R0 = 30
    STORE [0x3000], R0  ; [0x3000] = 30
    HALT
```

## 7.2 Käyttäjän vakiot (.const)

```asm
.origin 0x0200

.const BUFFER_SIZE, 256
.const MAX_VAL,     0x00FF

start:
    LOAD  R0, BUFFER_SIZE   ; R0 = 256
    LOAD  R1, MAX_VAL       ; R1 = 255
    ADD   R0, R1
    HALT
```

## 7.3 Makrojen käyttö

```asm
.origin 0x0200

.macro INIT_REGS        ; Makron määrittely
    LOAD R0, 0
    LOAD R1, 0
.endmacro

START:
    INIT_REGS           ; Makron kutsu ekspansoi käskyt tähän
    LOAD  R0, 42
    LOAD  R1, 0xFF
    LOAD  R2, 0b1010
    LOAD  R3, VRAM_START  ; Arkkitehtuurivakio (= 0xF800)
    ADD   R0, R1
    STORE [0x0200], R0
    JUMP  START
```

## 7.4 Aliohjelma (CALL/RET)

```asm
.origin 0x0200

main:
    LOAD R0, 5
    CALL factorial      ; Kutsu aliohjelma, paluuarvo R0:ssa
    HALT

factorial:
    ; R0 = n, laskee n!
    LOAD R1, 1
loop:
    CMP  R0, 0
    JZ   done
    MUL  R1, R0
    SUB  R0, 1
    JUMP loop
done:
    CPY  R0, R1
    RET
```

## 7.5 VRAM-kirjoitus

```asm
.origin 0x0200

    LOAD R0, VRAM_START     ; Näytön alkuosoite
    LOAD R1, 0x0741         ; 'A' (0x41) valkoisella värillä (0x07 << 8)
    STORE [R0], R1          ; Kirjoita ensimmäiselle ruudulle (epäsuora)
    HALT
```

## 7.6 Muistiosoitustavat ([..]-syntaksi)

```asm
.origin 0x0200

.const BUFFER, 0x0300

start:
    ; Absoluuttinen: lue/kirjoita kiinteään osoitteeseen
    STORE [BUFFER], 42      ; Kirjoita välitön arvo vakion osoitteeseen
    LOAD  R0, [BUFFER]      ; Lue sama osoite takaisin R0:aan

    ; Epäsuora: osoite rekisterin arvona
    LOAD  R1, BUFFER        ; R1 = osoite 0x0300
    LOAD  R2, [R1]          ; Lue [R1] eli [0x0300] → R2 = 42
    STORE [R1], R0          ; Kirjoita R0 rekisterin R1 osoittamaan paikkaan

    ; Suhteellinen (FP-kehys): paikallismuuttujat aliohjelmassa
    CALL  mysub
    HALT

mysub:
    STORE [FP+1], R0        ; Tallenna R0 paikallismuuttujaan indeksillä 1
    LOAD  R3, [FP+1]        ; Lue se takaisin R3:een
    RET
```

## 7.7 Testidirektiivit

```asm
.origin 0x0200

    LOAD R0, 10
    LOAD R1, 32
    ADD  R0, R1
    HALT

.expect_reg R0, 42      ; Tarkista että R0 = 42 ajon jälkeen
.expect_flag Z, 0       ; Tarkista että Z-lippu = 0
```

## 7.8 FP-rekisterin käyttö (pinokehys)

### Juurisyy

SP (Stack Pointer) muuttuu jokaisen `PUSH`-, `POP`-, `CALL`- ja `RET`-käskyn
yhteydessä. Jos aliohjelmassa yritettäisiin hakea pinoon tallennettuja
paikallismuuttujia SP:n avulla, jokainen uusi pinooperaatio muuttaisi
tarvittavan siirtymän — erityisesti sisäkkäisissä kutsuissa kirjanpito
muuttuisi nopeasti virhealttiiksi.

**FP (Frame Pointer) ratkaisee tämän:** se asetetaan kerran aliohjelman alussa
(`CPY FP, SP`) kiinteäksi viittaukseksi pinokehyksen pohjalle, eikä sen arvo
muutu koko aliohjelman suorituksen aikana. Näin `[FP+1]`, `[FP+2]` jne.
osoittavat aina samoihin muistipaikkoihin riippumatta siitä, minne SP on
sittemmin siirtynyt.

### Pinokehyksen rakenne

Kun aliohjelma kutsutaan ja se tallentaa argumentit pinoon ennen `CPY FP, SP`
-käskyä, kehyksen rakenne on seuraava:

```
  osoite       sisältö
  ──────────────────────
  [FP+3]   paluuosoite  ← CALL tallentaa tämän
  [FP+2]   argumentti a ← PUSH R0
  [FP+1]   argumentti b ← PUSH R1
  [FP]     SP:n huippu  ← CPY FP, SP (kehyksen pohja)
```

Koska FP on kiinnitetty, `[FP+2]` tarkoittaa aina argumenttia `a` — vaikka SP
myöhemmin liikkuisi sisäkkäisten kutsujen tai muiden `PUSH`/`POP`-operaatioiden
vuoksi.

### Esimerkki

```asm
.origin 0x0200

; Pääohjelma: laske 10 + 32
main:
    LOAD  R0, 10
    LOAD  R1, 32
    CALL  yhteenlasku       ; kutsu aliohjelma; paluuarvo R0:ssa
    HALT                    ; R0 = 42

; Aliohjelma yhteenlasku
;   Sisääntulo : R0 = a, R1 = b
;   Paluuarvo  : R0 = a + b
;
; Pinon tila CPY FP, SP -käskyn jälkeen:
;   [FP+3] = paluuosoite    (CALL tallensi)
;   [FP+2] = a = 10         (PUSH R0)
;   [FP+1] = b = 32         (PUSH R1)
;   [FP]   = kehyksen pohja (CPY FP, SP)
;
; SP voi myöhemmin muuttua (esim. sisäkkäisessä CALL:ssa),
; mutta FP pysyy kiinteänä ja [FP+1]/[FP+2] toimivat aina.
yhteenlasku:
    PUSH  R0            ; tallenna a pinoon → [SP] = 10, SP--
    PUSH  R1            ; tallenna b pinoon → [SP] = 32, SP--
    CPY   FP, SP        ; kiinnitä FP kehyksen pohjalle

    LOAD  R0, [FP+2]    ; R0 = a = 10  (vakio-offset, vaikka SP muuttuisi)
    LOAD  R1, [FP+1]    ; R1 = b = 32
    ADD   R0, R1        ; R0 = 42

    POP   R1            ; palauta R1 (poistaa b:n tallennuksen)
    POP   R3            ; pinosta poistetaan a:n tallenne; ei R0:aan,
                        ; koska R0 sisältää jo tuloksen (42)
    RET                 ; R0 = 42
```

---

Kaikki esimerkkiohjelmat löytyvät hakemistosta `kcpu16/code/`.
