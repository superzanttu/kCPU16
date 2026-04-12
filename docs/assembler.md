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

- Mnemonikit ovat kirjainkoosta riippumattomia (`READ` = `read`)
- Rekisterinimet ovat kirjainkoosta riippumattomia (`R0` = `r0`)
- Labelit päättyvät kaksoispisteeseen määrittelyssä, mutta viitattaessa kaksoispisteen saa jättää pois
- Tyhjät rivit ja ylimääräiset välilyönnit ovat sallittuja

---

# 2. Operandien merkintätavat

| Syntaksi      | Tyyppi                                                | Esimerkki              |
| ------------- | ----------------------------------------------------- | ---------------------- |
| `R0`–`SP`     | Rekisteri (kirjainkoosta riippumaton)                 | `ADD R0, R1`           |
| `42`          | Desimaali-literaali                                   | `READ R0, 42`          |
| `0xFF`        | Heksadesimaali-literaali                              | `READ R0, 0xFF`        |
| `0b1010`      | Binääri-literaali                                     | `READ R0, 0b1010`      |
| `0o52`        | Oktaali-literaali                                     | `READ R0, 0o52`        |
| `label`       | Label-viittaus                                        | `JUMP loop`            |
| `VRAM_START`  | Arkkitehtuurivakio (ks. kohta 4)                      | `READ R0, VRAM_START`  |
| `NIMI`        | Käyttäjän vakio (`.const`, ks. kohta 5)               | `READ R0, BUFFER_SIZE` |
| `[addr]`      | Absoluuttinen muistiosoite (ks. kohta 6)              | `READ R0, [0x3000]`    |
| `[reg]`       | Epäsuora muistiosoite rekisterin kautta (ks. kohta 6) | `READ R0, [R1]`        |
| `[FP+offset]` | FP-suhteellinen muistiosoite (ks. kohta 6)            | `READ R0, [FP+2]`      |

Rekisterit: `R0`–`R15` (yleiskäyttöiset), `FP` (frame pointer), `SP` (stack pointer). Kirjainkoosta riippumaton.

---

# 3. Direktiivit

| Direktiivi                                       | Kuvaus                                                                      |
| ------------------------------------------------ | --------------------------------------------------------------------------- |
| `.origin addr` / `.org addr`                     | Aseta koodin aloitusosoite (oletus: 0x0100)                                 |
| `.at addr`                                       | Siirry uuteen muistiosoitteeseen (uusi koodisegmentti)                      |
| `.dw val, val, …`                                | Tallenna 16-bittisiä sanoja muistiin; kukin arvo maskataan arvolla 0xFFFF   |
| `.db val, val, …`                                | Tallenna 8-bittisiä arvoja muistiin; kukin arvo maskataan arvolla 0xFF      |
| `.dstr "teksti"` / `.dstr 'teksti'`              | Tallenna null-terminoitu merkkijono; escape: `\\` `\"` `\'` `\n` `\t` `\0`  |
| `.diskblock N`                                   | Assemblauksen jälkeen tallenna konekieli tallennuslaitteen blokkiin N       |
| `.bootblock "levykuva", overwrite=0/1, boot=0/1` | Aloita bootsektoriin kirjoitettava osuus ja määritä kohdelevykuva           |
| `.endbootblock`                                  | Päätä `.bootblock`-osuus                                                    |
| `.const NIMI, ARVO`                              | Määrittele nimetty vakio (kokonaisluku tai heksa; ks. kohta 5)              |
| `.macro NIMI`                                    | Aloita makromäärittely                                                      |
| `.endmacro`                                      | Lopeta makromäärittely                                                      |
| `.include "tiedosto"` / `.include 'f'`           | Liitä toinen .asm-tiedosto tähän kohtaan (silmukkasuojaus)                  |
| `.expect_reg R, arvo`                            | Testidirektiivi: tarkista rekisterin arvo ajon jälkeen                      |
| `.expect_flag F, arvo`                           | Testidirektiivi: tarkista tilalipun arvo ajon jälkeen                       |
| `.expect_mem addr, arvo`                         | Testidirektiivi: tarkista muistipaikan arvo ajon jälkeen                    |
| `.expect_storage addr, arvo`                     | Testidirektiivi: tarkista tallennuslaitteen arvo ajon jälkeen               |
| `.inject_key koodi`                              | Testidirektiivi: simuloi näppäinpainallus (esim. `.inject_key 0x41`)        |
| `.inject_key_release koodi`                      | Testidirektiivi: simuloi näppäinvapautus (esim. `.inject_key_release 0x41`) |

> **Kommentit:** Puolipiste (`;`) aloittaa riviloppukommentin. Lohkokommentit `/* ... */` eivät ole tuettu.

## 3.1 Bootblock-direktiivit

`.bootblock` ja `.endbootblock` rajaavat tiedostosta osan, joka assembloidaan erikseen levynkuvan bootsektoriksi.
Bootblock-osuus ei kuulu tavalliseen RAM-ohjelmaan, joten samassa tiedostossa oleva varsinainen ohjelmakoodi voi alkaa omasta `.origin`-osoitteestaan ilman että bootloader kopioituu myös sinne.

Syntaksi:

```asm
.bootblock "../storage/boot.dsk", overwrite=1, boot=0
    ; Koodi joka assembloidaan boot-alueelle 0x0100-0x01FF
    READ R0, 1
    JUMP 0x0200
.endbootblock

.origin 0x0200
    JUMP START

    .include "lib-screen.asm"

START:
    READ R1, 2
    HALT
```

Optiot:

| Optio       | Arvot                                               | Oletus | Kuvaus                                                        |
| ----------- | --------------------------------------------------- | ------ | ------------------------------------------------------------- |
| `overwrite` | `0`, `1`, `false`, `true`, `no`, `yes`, `off`, `on` | `0`    | Saako olemassa olevan levykuvan ei-tyhjää bootblokkia korvata |
| `boot`      | `0`, `1`, `false`, `true`, `no`, `yes`, `off`, `on` | `0`    | Bootataanko emulaattori heti kirjoituksen jälkeen levykuvasta |

Säännöt:

- Vain yksi `.bootblock`-osuus per tiedosto.
- `.bootblock`-osuuden on assembloiduttava kokonaan boot-alueelle `BOOT_RAM_START`–`BOOT_RAM_END` eli osoitealueelle `0x0100`–`0x01FF`.
- Bootblockin kokorajoitus koskee vain `.bootblock`-osuuden omaa konekieltä, ei koko tiedoston muuta ohjelmaa.
- Levykuvan polku tulkitaan suhteessa nykyiseen `.asm`-tiedostoon.

## 3.2 Datadirektiiviit: .dw ja .db

Molemmat direktiivit tallentavat sarjan literaaliarvoja peräkkäisiin muistipaikkoihin.
Koska kCPU16 on **sanakohtaisesti osoitettu** (word-addressed), jokainen arvo
— riippumatta sen bittileveydestä — vie yhden 16-bittisen muistipaikan.

| Direktiivi | Maski    | Hyväksytty arvoalue       |
| ---------- | -------- | ------------------------- |
| `.dw`      | `0xFFFF` | 0 – 65535 tai –32768 – –1 |
| `.db`      | `0x00FF` | 0 – 255 tai –128 – –1     |

**Numeroliteraalit:** Desimaali (`42`), heksadesimaali (`0xFF`), binääri (`0b1010`),
oktaali (`0o52`) ovat kaikki sallittuja.

**Etumerkilliset arvot** muunnetaan 2-komplementtiesitysmuotoon maskauksella:
`-1` tallentuu `.dw`:llä arvona `0xFFFF` (65535) ja `.db`:llä arvona `0xFF` (255).

```asm
; .dw esimerkkejä
TAULUKKO:
    .dw 0, 65535, 0x1234    ; etumerkittömiä sanoja
    .dw -1, -32768           ; etumerkilliset, maskattu 0xFFFF:llä

; .db esimerkkejä
MERKIT:
    .db 0x41, 0x42, 0x43    ; 'A', 'B', 'C'
    .db 0, 255               ; pienin ja suurin byte-arvo
    .db -1, -128             ; etumerkilliset, maskattu 0xFF:llä
```

---

# 4. Arkkitehtuurivakiot

Assembler injektoi automaattisesti seuraavat vakiot koodin käyttöön label-niminä.
Ne voidaan käyttää suoraan operandeina ilman erillistä määrittelyä.

| Vakio                 | Arvo   | Kuvaus                                                     |
| --------------------- | ------ | ---------------------------------------------------------- |
| `VRAM_START`          | 0xF800 | VRAM:n alkuosoite                                          |
| `VRAM_END`            | 0xFF7F | VRAM:n loppuosoite (viimeinen solu)                        |
| `VRAM_WORDS`          | 1920   | VRAM:n koko sanoina (80 × 24)                              |
| `VRAM_CHAR_MASK`      | 0x00FF | Merkkikentän bittimaski                                    |
| `VRAM_FG_MASK`        | 0x0700 | Edusta-värikentän bittimaski (bitit 8–10)                  |
| `VRAM_FG_SHIFT`       | 8      | Edusta-värikentän siirto bitteinä                          |
| `VRAM_BG_MASK`        | 0x3800 | Tausta-värikentän bittimaski (bitit 11–13)                 |
| `VRAM_BG_SHIFT`       | 11     | Tausta-värikentän siirto bitteinä                          |
| `VRAM_ATTR_BOLD`      | 0x4000 | Lihavointi-attribuutti (bitti 14)                          |
| `SCREEN_COLS`         | 80     | Näytön leveys sarakkeina                                   |
| `SCREEN_ROWS`         | 24     | Näytön korkeus riveinä                                     |
| `BOOT_RAM_START`      | 0x0100 | Bootloaderin latausalue                                    |
| `BOOT_RAM_END`        | 0x01FF | Bootloaderin latausalueen loppu                            |
| `KERNEL_STACK_START`  | 0xFF80 | Kernel-pinon alkuosoite                                    |
| `KERNEL_STACK_END`    | 0xFFFF | Kernel-pinon loppuosoite                                   |
| `MEMORY_WORDS`        | 65536  | Muistiavaruuden koko sanoina                               |
| `WORD_MASK`           | 0xFFFF | 16-bittinen maski                                          |
| `WORD_SIGN_BIT`       | 0x8000 | Etumerkkilipun bitti                                       |
| `WORD_BITS`           | 16     | Sanan bittimäärä                                           |
| `INT_DIV_ZERO`        | 0      | Jako nollalla (vektori 0)                                  |
| `INT_INVALID_OPCODE`  | 1      | Tuntematon käsky (vektori 1)                               |
| `INT_STACK_OVERFLOW`  | 2      | Pinon ylivuoto (vektori 2)                                 |
| `INT_BREAKPOINT`      | 3      | Debug/breakpoint (vektori 3)                               |
| `INT_PRIVILEGE`       | 4      | Privilege violation (vektori 4)                            |
| `INT_MEM_FAULT`       | 5      | Muistisuojausrikkomus (vektori 5)                          |
| `INT_KEYBOARD`        | 6      | Näppäimistökeskeytys (vektori 6)                           |
| `INT_TIMER`           | 7      | Ajastinkeskeytys (vektori 7)                               |
| `INT_PROCESS_EXIT`    | 8      | Prosessin lopetus (vektori 8)                              |
| `INT_CLOCK`           | 9      | Kellokeskeytys (vektori 9)                                 |
| `INT_VECTOR_BASE`     | 0x0000 | Vektoritaulukon alkuosoite                                 |
| `INT_VECTOR_COUNT`    | 16     | Vektoritaulukon koko                                       |
| `CLOCK_MMIO_START`    | 0x0010 | Kellokello-MMIO-alueen alku                                |
| `CLOCK_MMIO_END`      | 0x001F | Kellokello-MMIO-alueen loppu                               |
| `CLOCK_YEAR`          | 0x0010 | Vuosi MMIO                                                 |
| `CLOCK_MONTH`         | 0x0011 | Kuukausi MMIO                                              |
| `CLOCK_DAY`           | 0x0012 | Päivä MMIO                                                 |
| `CLOCK_HOUR`          | 0x0013 | Tunti MMIO                                                 |
| `CLOCK_MINUTE`        | 0x0014 | Minuutti MMIO                                              |
| `CLOCK_SECOND`        | 0x0015 | Sekunti MMIO                                               |
| `CLOCK_MILLIS`        | 0x0016 | Millisekunti MMIO                                          |
| `UPTIME_W3`           | 0x0017 | Uptime bitit 48–63 MMIO                                    |
| `UPTIME_W2`           | 0x0018 | Uptime bitit 32–47 MMIO                                    |
| `UPTIME_W1`           | 0x0019 | Uptime bitit 16–31 MMIO                                    |
| `UPTIME_W0`           | 0x001A | Uptime bitit 0–15 MMIO                                     |
| `CLOCK_INT_INTERVAL`  | 0x001B | CTMR MMIO (kellokeskeytyksen väli ms)                      |
| `KBD_MMIO_START`      | 0x0020 | Näppäimistö-MMIO-alueen alku                               |
| `KBD_MMIO_END`        | 0x0021 | Näppäimistö-MMIO-alueen loppu                              |
| `KBD_DATA`            | 0x0020 | Näppäintapahtuma MMIO (lue: seuraava tapahtuma puskurista) |
| `KBD_STATUS`          | 0x0021 | Näppäimistöpuskurin koko MMIO                              |
| `KBD_RELEASE_BIT`     | 0x80   | Vapautusbitti KBD_DATA:ssa (1 = vapautus)                  |
| `KBD_KEY_CODE_MASK`   | 0x7F   | Näppäinkoodi bittimaski (bitit 6–0)                        |
| `RAND_MMIO`           | 0x0022 | Satunnaisluku MMIO (lue: satunnaisluku; kirj: siemen)      |
| `RAND_LFSR_SEED`      | 0xACE1 | LFSR-oletussiemen                                          |
| `STORAGE_BLOCK_SIZE`  | 256    | Tallennuslaitteen blokin koko sanoina                      |
| `STORAGE_BLOCK_COUNT` | 256    | Tallennuslaitteen blokkien lukumäärä                       |
| `COLOR_BLACK`         | 0      | Värikoodi: musta                                           |
| `COLOR_RED`           | 1      | Värikoodi: punainen                                        |
| `COLOR_GREEN`         | 2      | Värikoodi: vihreä                                          |
| `COLOR_YELLOW`        | 3      | Värikoodi: keltainen                                       |
| `COLOR_BLUE`          | 4      | Värikoodi: sininen                                         |
| `COLOR_MAGENTA`       | 5      | Värikoodi: magenta                                         |
| `COLOR_CYAN`          | 6      | Värikoodi: syaani                                          |
| `COLOR_WHITE`         | 7      | Värikoodi: valkoinen                                       |
| `SR_FLAG_Z`           | 0      | Tilarekisterin Z-lipun bittinumero                         |
| `SR_FLAG_N`           | 1      | Tilarekisterin N-lipun bittinumero                         |
| `SR_FLAG_C`           | 2      | Tilarekisterin C-lipun bittinumero                         |
| `SR_FLAG_V`           | 3      | Tilarekisterin V-lipun bittinumero                         |
| `SR_FLAG_I`           | 4      | Tilarekisterin I-lipun bittinumero                         |
| `SR_FLAG_P`           | 5      | Tilarekisterin P-lipun bittinumero                         |
| `MODE_KERNEL`         | 1      | Kernel-tila (SR:n P-lippu = 1)                             |
| `MODE_USER`           | 0      | User-tila (SR:n P-lippu = 0)                               |
| `DEFAULT_MPR`         | 0x0100 | MPR:n oletusarvo (= BOOT_RAM_START)                        |

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

Lisäksi rekisterinimet `R0`–`R15`, `FP`, `SP` ovat aina varattuja
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

# 6. Muistiosoitustavat: READ ja STORE

Assembler-koodissa sallitaan ainoastaan kaksi datansiirtomnemoniikkaa:
**`READ`** (lukeminen, immediate-lataus tai muistiluku) ja **`STORE`** (kirjoittaminen muistiin).
Konekielen tasolla käytetyt `LOAD`, `READ_IND`, `READ_REL`, `STOREI`, `STORE_IND` jne.
tuotetaan assemblerin toimesta automaattisesti — ohjelmoija ei käytä niitä
suoraan assembler-koodissa.

`READ`- ja `STORE`-käskyissä voidaan käyttää hakasulkunotaatiota `[...]`
muistiosoituksen tarkentamiseen. Assembler valitsee sopivan konekielikäskyn
automaattisesti hakasulkumuodon perusteella — ohjelmoija kirjoittaa aina vain
`READ` tai `STORE`.

## 6.1 Osoitusmoodit

| Syntaksi      | Osoitusmooodi | Selitys                                     |
| ------------- | ------------- | ------------------------------------------- |
| `[addr]`      | Absoluuttinen | Muistiosoite `addr` suoraan                 |
| `[reg]`       | Epäsuora      | Osoite on rekisterin arvo                   |
| `[FP+offset]` | Suhteellinen  | Osoite on `FP + offset` (aliohjelman kehys) |

## 6.2 READ reg, arvo ja READ reg, \[...\]

`READ` on ainoa sallittu mnemoniikka datan lataamiseen rekisteriin:

| Syntaksi              | Toiminta                 | Tuotettu konekieli |
| --------------------- | ------------------------ | ------------------ |
| `READ reg, arvo`      | `reg ← arvo` (immediate) | `LOAD`             |
| `READ reg, label`     | `reg ← label-osoite`     | `LOAD`             |
| `READ reg, [addr]`    | `reg ← [addr]`           | `READ`             |
| `READ reg, [regS]`    | `reg ← [regS]`           | `READ_IND`         |
| `READ reg, [FP+offs]` | `reg ← [FP + offs]`      | `READ_REL`         |

```asm
READ R0, 42             ; Lataa välitön arvo 42 rekisteriin R0
READ R0, VRAM_START     ; Lataa arkkitehtuurivakion arvo R0:aan
READ R0, [0x3000]       ; Lue osoitteesta 0x3000 (absoluuttinen)
READ R0, [R1]           ; Lue osoitteesta, jonka R1 sisältää (epäsuora)
READ R0, [FP+2]         ; Lue aliohjelman paikallismuuttuja indeksillä 2 (suhteellinen)
```

## 6.3 STORE \[...\], lähde

`STORE`-käsky hakasulkunotaatiolla kirjoittaa muistiin. Lähteeksi kelpaa rekisteri
tai välitön arvo (immediate).

| Syntaksi               | Toiminta            |
| ---------------------- | ------------------- |
| `STORE [addr], reg`    | `[addr] ← reg`      |
| `STORE [addr], imm`    | `[addr] ← imm`      |
| `STORE [regD], reg`    | `[regD] ← reg`      |
| `STORE [regD], imm`    | `[regD] ← imm`      |
| `STORE [FP+offs], reg` | `[FP + offs] ← reg` |
| `STORE [FP+offs], imm` | `[FP + offs] ← imm` |

```asm
STORE [0x3000], R0      ; Kirjoita R0 osoitteeseen 0x3000 (absoluuttinen)
STORE [0x3000], 42      ; Kirjoita vakioarvo 42 osoitteeseen 0x3000 (absoluuttinen, välitön)
STORE [R1], R0          ; Kirjoita R0 osoitteeseen, jonka R1 sisältää (epäsuora)
STORE [R1], 0xFF        ; Kirjoita vakio 0xFF epäsuoraan osoitteeseen (välitön)
STORE [FP+2], R0        ; Tallenna R0 aliohjelman paikallismuuttujaan (suhteellinen)
STORE [FP+2], 99        ; Kirjoita välitön arvo paikallismuuttujaan (suhteellinen, välitön)
```

---

# 7. Esimerkit

## 7.1 Peruslaskelma

```asm
.origin 0x0200

; Laske 10+20 ja tallenna tulos muistiin
start:
    READ  R0, 10
    READ  R1, 20
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
    READ  R0, BUFFER_SIZE   ; R0 = 256
    READ  R1, MAX_VAL       ; R1 = 255
    ADD   R0, R1
    HALT
```

## 7.3 Makrojen käyttö

```asm
.origin 0x0200

.macro INIT_REGS        ; Makron määrittely
    READ R0, 0
    READ R1, 0
.endmacro

START:
    INIT_REGS           ; Makron kutsu ekspansoi käskyt tähän
    READ  R0, 42
    READ  R1, 0xFF
    READ  R2, 0b1010
    READ  R3, VRAM_START  ; Arkkitehtuurivakio (= 0xF800)
    ADD   R0, R1
    STORE [0x0200], R0
    JUMP  START
```

## 7.4 Aliohjelma (CALL/RET)

```asm
.origin 0x0200

main:
    READ R0, 5
    CALL factorial      ; Kutsu aliohjelma, paluuarvo R0:ssa
    HALT

factorial:
    ; R0 = n, laskee n!
    READ R1, 1
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

    READ R0, VRAM_START     ; Näytön alkuosoite
    READ R1, 0x0741         ; 'A' (0x41) valkoisella värillä (0x07 << 8)
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
    READ  R0, [BUFFER]      ; Lue sama osoite takaisin R0:aan

    ; Epäsuora: osoite rekisterin arvona
    READ  R1, BUFFER        ; R1 = osoite 0x0300
    READ  R2, [R1]          ; Lue [R1] eli [0x0300] → R2 = 42
    STORE [R1], R0          ; Kirjoita R0 rekisterin R1 osoittamaan paikkaan

    ; Suhteellinen (FP-kehys): paikallismuuttujat aliohjelmassa
    CALL  mysub
    HALT

mysub:
    STORE [FP+1], R0        ; Tallenna R0 paikallismuuttujaan indeksillä 1
    READ  R3, [FP+1]        ; Lue se takaisin R3:een
    RET
```

## 7.7 Testidirektiivit

```asm
.origin 0x0200

    READ R0, 10
    READ R1, 32
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
    READ  R0, 10
    READ  R1, 32
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

    READ  R0, [FP+2]    ; R0 = a = 10  (vakio-offset, vaikka SP muuttuisi)
    READ  R1, [FP+1]    ; R1 = b = 32
    ADD   R0, R1        ; R0 = 42

    POP   R1            ; palauta R1 (poistaa b:n tallennuksen)
    POP   R3            ; pinosta poistetaan a:n tallenne; ei R0:aan,
                        ; koska R0 sisältää jo tuloksen (42)
    RET                 ; R0 = 42
```

---

Kaikki esimerkkiohjelmat löytyvät hakemistosta `kcpu16/code/`.

---

# 8. Virheilmoitukset

Assembler tuottaa virheilmoitukset, jotka kertovat aiheuttavan rivin numeron, itse lähderivin ja kuvauksen virheestä.

## 8.1 Muoto

Virheilmoituksen muoto on:

```
Rivi <N>: '<lähderivi>'
  <virhekuvaus>
```

**Esimerkki:**

```
Rivi 3: 'ADD R0, UNKNOWN_LABEL'
  Tuntematon operandi: 'UNKNOWN_LABEL' (ei rekisteri, label eikä luku)
```

```
Rivi 7: '.const VRAM_START, 100'
  .const 'VRAM_START': nimi on jo arkkitehtuurivakio — valitse toinen nimi
```

## 8.2 Huomioita rivi­numeroinnista

- Rivinumerot lasketaan **laajennetusta lähdekoodista** eli makrojen ekspansoinnin jälkeen.
- Mikäli ohjelma käyttää makroja (`.macro`/`.endmacro`), ekspandoitujen rivien numerointi voi poiketa alkuperäisen tiedoston riveistä.
- `.include`-direktiivillä liitettyjen tiedostojen virheet näyttävät kyseisen tiedoston rivin, ei liittävän tiedoston riviä.
