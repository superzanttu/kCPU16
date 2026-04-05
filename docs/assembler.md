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

| Syntaksi     | Tyyppi                                | Esimerkki             |
| ------------ | ------------------------------------- | --------------------- |
| `R0`–`SP`    | Rekisteri (kirjainkoosta riippumaton) | `ADD R0, R1`          |
| `42`         | Desimaali-literaali                   | `LOAD R0, 42`         |
| `0xFF`       | Heksadesimaali-literaali              | `LOAD R0, 0xFF`       |
| `0b1010`     | Binääri-literaali                     | `LOAD R0, 0b1010`     |
| `0o52`       | Oktaali-literaali                     | `LOAD R0, 0o52`       |
| `label`      | Label-viittaus                        | `JUMP loop`           |
| `VRAM_START` | Arkkitehtuurivakio (ks. kohta 4)      | `LOAD R0, VRAM_START` |

Rekisterit: `R0`, `R1`, `R2`, `R3`, `FP`, `SP`. Kirjainkoosta riippumaton.

---

# 3. Direktiivit

| Direktiivi                   | Kuvaus                                                                |
| ---------------------------- | --------------------------------------------------------------------- |
| `.origin addr` / `.org addr` | Aseta koodin aloitusosoite (oletus: 0x0100)                           |
| `.at addr`                   | Siirry uuteen muistiosoitteeseen (uusi koodisegmentti)                |
| `.db val, val, …`            | Tallenna raakoja 16-bittisiä sanoja suoraan muistiin                  |
| `.dstr "teksti"`             | Tallenna null-terminoitu merkkijono (ASCII-sanat)                     |
| `.diskblock N`               | Assemblauksen jälkeen tallenna konekieli tallennuslaitteen blokkiin N |
| `.macro NIMI`                | Aloita makromäärittely                                                |
| `.endmacro`                  | Lopeta makromäärittely                                                |
| `.expect_reg R, arvo`        | Testidirektiiivi: tarkista rekisterin arvo ajon jälkeen               |
| `.expect_flag F, arvo`       | Testidirektiiivi: tarkista tipalipun arvo ajon jälkeen                |
| `.expect_mem addr, arvo`     | Testidirektiiivi: tarkista muistipaikan arvo ajon jälkeen             |

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

# 5. Esimerkit

## 5.1 Peruslaskelma

```asm
.origin 0x0200

; Laske 10+20 ja tallenna tulos muistiin
start:
    LOAD  R0, 10
    LOAD  R1, 20
    ADD   R0, R1        ; R0 = 30
    STORE R0, 0x3000    ; [0x3000] = 30
    HALT
```

## 5.2 Makrojen käyttö

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
    STORE R0, 0x0200
    JUMP  START
```

## 5.3 Aliohjelma (CALL/RET)

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

## 5.4 VRAM-kirjoitus

```asm
.origin 0x0200

    LOAD R0, VRAM_START     ; Näytön alkuosoite
    LOAD R1, 0x0741         ; 'A' (0x41) valkoisella värillä (0x07 << 8)
    STORE R1, R0            ; Kirjoita ensimmäiselle ruudulle
    HALT
```

## 5.5 Testidirektiivit

```asm
.origin 0x0200

    LOAD R0, 10
    LOAD R1, 32
    ADD  R0, R1
    HALT

.expect_reg R0, 42      ; Tarkista että R0 = 42 ajon jälkeen
.expect_flag Z, 0       ; Tarkista että Z-lippu = 0
```

---

Kaikki esimerkkiohjelmat löytyvät hakemistosta `kcpu16/code/`.
