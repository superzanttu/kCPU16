# kCPU16 Näppäimistö

Tämä dokumentti kuvaa kCPU16:n näppäimistölaitteen toiminnan, MMIO-osoitteet, keskeytysmallin sekä antaa esimerkkiohjelman näppäimistön käyttöön.

---

## 1. Toimintaperiaate

Näppäimistö on **muistikarttattu laite (MMIO)**, joka toimii keskeytyspohjaisesti. Erillistä näppäimistöä varten tarkoitettua suorituskäskyä ei ole — kaikki kommunikointi tapahtuu muistiosoitteiden ja keskeytyksen kautta.

Tapahtumavirta on seuraava:

1. Käyttäjä painaa tai vapauttaa näppäimen.
2. Näppäintapahtuma (8-bittinen skannikoodi) lisätään sisäiseen FIFO-puskuriin.
3. CPU laukaisee **INT 6** (`INT_KEYBOARD`) heti seuraavan käskyn jälkeen, jos keskeytykset ovat sallittuja (`I = 1`).
4. Keskeytysrutiini lukee tapahtuman MMIO-osoitteesta `KBD_DATA` (`$0020`).
5. Jokainen näppäintapahtuma tuottaa tarkalleen **yhden** INT 6 -keskeytyksen.

---

## 2. MMIO-osoitteet

| Osoite   | Vakionimi    | Lukeminen                                         | Kirjoittaminen           |
| -------- | ------------ | ------------------------------------------------- | ------------------------ |
| `$0020`  | `KBD_DATA`   | Pops seuraava tapahtuma puskurista; `0` jos tyhjä | **Kielletty — INT 10**   |
| `$0021`  | `KBD_STATUS` | Puskurissa olevien tapahtumien määrä; `0` = tyhjä | **Kielletty — INT 10**   |

Molemmat osoitteet ovat **luku vain**. Kirjoitusyritys laukaisee
`INT_WRITE_PROTECTED` (INT 10) riippumatta suoritustilasta (kernel tai user).
Tämä on toteutettu muistimallin (`memory.py`) kirjoitussuojauslistassa
(`WRITE_PROTECTED_REGIONS`), joka kattaa osoitteet `$0020–$0021`.

Vakiot `KBD_DATA`, `KBD_STATUS`, `KBD_RELEASE_BIT` ja `KBD_KEY_CODE_MASK` ovat käytettävissä suoraan assembly-koodissa arkkitehtuurivakioina.

---

## 3. Skannikoodi-rakenne

Jokainen näppäintapahtuma koodataan yhteen 8-bittiseen arvoon:

```
  Bitti 7 (KBD_RELEASE_BIT = 0x80):
      0 = näppäimen painallus
      1 = näppäimen vapautus

  Bitit 6–0 (KBD_KEY_CODE_MASK = 0x7F):
      Näppäimen koodi (ASCII-arvo tai muu koodi, 0–127)
```

| Tapahtuma        | Arvo (hex) | Selitys                           |
| ---------------- | ---------- | --------------------------------- |
| 'A' painetaan    | `0x41`     | ASCII 65, bitti 7 = 0 (painallus) |
| 'A' vapautetaan  | `0xC1`     | ASCII 65 \| 0x80 = 193 (vapautus) |
| 'Esc' painetaan  | `0x1B`     | ASCII 27, bitti 7 = 0             |
| 'Esc' vapautetaan| `0x9B`     | 27 \| 0x80 = 155                  |

---

## 4. Useamman tapahtuman lukeminen yhdessä keskeytyksessä

Kyllä — `KBD_DATA`:sta voidaan lukea useampi tapahtuma saman INT 6 -käsittelijän aikana. Jokainen lukuoperaatio **pops** yhden tapahtuman FIFO-puskurista ja palauttaa sen. Seuraava luku palauttaa puskurin seuraavan arvon, tai `0` jos puskuri on tyhjä.

Puskurin koon voi tarkistaa `KBD_STATUS`-rekisteristä. Tyypillinen patterneista:

```asm
; Käsittele kaikki odottavat tapahtumat yhdessä keskeytyksessä
kbd_handler:
drain_loop:
        LOAD  R0, [KBD_STATUS]      ; kuinka monta tapahtumaa odottaa?
        JZ    kbd_done              ; 0 = puskuri tyhjä, valmis
        LOAD  R1, [KBD_DATA]        ; pops seuraava tapahtuma
        ; ... käsittele R1 ...
        JUMP  drain_loop            ; tarkista uudelleen

kbd_done:
        IRET
```

> **Huom:** Normaalisti INT 6 laukeaa kerran per tapahtuma, joten puskurissa on yleensä täsmälleen yksi tapahtuma saapuessa. Jos haluat varmistaa kaikkien tapahtumien käsittelyn (esim. bursttitilanteissa), käytä `KBD_STATUS`-silmukkaa yllä olevan esimerkin mukaan.

---

## 5. Keskeytyksen käyttöönotto

Jotta näppäimistökeskeytys aktivoituu, ohjelma tarvitsee:

1. **Aseta INT 6 -käsittelijan osoite** vektoritaulukkoon muistiin `[INT_KEYBOARD]` (= osoite 6).
2. **Salli keskeytykset** `STI`-käskyllä (asettaa `I`-lipun).

Kun ohjelmaa ei pitäisi enää vastaanottaa keskeytyksiä, käytä `CLI`-käskyä.

---

## 6. Esimerkkiohjelma

Seuraava ohjelma lukee näppäimistöltä merkkejä ja kirjoittaa ne VRAM-näyttömuistiin vasemmasta yläkulmasta alkaen. Painallukset näkyvät näytöllä; vapautustapahtumia ei piirretä. Ohjelma jatkaa silmukassa kunnes se pysäytetään.

```asm
; =============================================================================
; keyboard_demo.asm — Näppäimistön käyttöesimerkki
; =============================================================================
;
; Ohjelma tulostaa painetut näppäimet VRAM-näytölle vasemmasta yläkulmasta.
; Jokainen painallus siirtää osoitinta eteenpäin. Vapautukset ohitetaan.
;
; REKISTERIEN KÄYTTÖ:
;   R0  = luettu näppäintapahtuma (KBD_DATA)
;   R1  = bitti-7-testi (KBD_RELEASE_BIT)
;   R2  = VRAM-kirjoitusosoitin (alkaa VRAM_START:sta)
;   R3  = näppäinkoodi ilman vapautusbittiä (maskattuna)
;   R4  = INT 6 -käsittelijan osoite
;
; =============================================================================

        .origin 0x0200

; --- Alustus ------------------------------------------------------------------

start:
        ; Aseta INT 6 (näppäimistö) -käsittelija
        LOAD  R4, kbd_handler
        STORE [INT_KEYBOARD], R4    ; vektoriosoite 6 ← käsittelija

        ; Alusta VRAM-kirjoitusosoitin näytön vasempaan yläkulmaan
        LOAD  R2, VRAM_START        ; R2 = 0xF800

        ; Salli keskeytykset
        STI

; --- Pääsilmukka (odota keskeytyksiä) ----------------------------------------

idle:
        JUMP  idle                  ; pyöri paikallaan — keskeytykset hoitavat työn

; --- INT 6: näppäimistökäsittelija -------------------------------------------
;
; Käsittelija kutsutaan aina kun näppäintapahtuma on saatavilla.
; Se lukee tapahtuman, ohittaa vapautukset ja piirtää painallukset näytölle.
;
kbd_handler:
        LOAD  R0, [KBD_DATA]        ; lue ja poista tapahtuma puskurista

        ; Tarkista onko bitti 7 asetettu (= vapautus)
        LOAD  R1, KBD_RELEASE_BIT   ; R1 = 0x80
        AND   R1, R0                ; R1 = R0 & 0x80
        JNZ   kbd_done              ; bitti 7 = 1 → vapautus, ohita

        ; Painallus: maskaa pois bitti 7, jotta saadaan pelkkä näppäinkoodi
        LOAD  R3, KBD_KEY_CODE_MASK ; R3 = 0x7F
        AND   R3, R0                ; R3 = näppäinkoodi (0–127)

        ; Laadi VRAM-sana: ASCII-merkki valkoisella värillä (FG=7)
        ;   Väriattribuutti: FG=7 (valkoinen) → 0x0700
        ;   VRAM-sana = väri | merkki = 0x0700 | R3
        LOAD  R1, 0x0700            ; valkoinen edusta, musta tausta
        OR    R1, R3                ; R1 = VRAM-sana

        ; Kirjoita merkki näytölle ja siirry seuraavaan paikkaan
        STORE [R2], R1
        ADD   R2, 1

        ; Älä mene VRAM:n yli
        LOAD  R1, VRAM_END
        CMP   R2, R1
        JGT   reset_cursor          ; jos osoitin ylitti VRAM:n lopun, nollaa

kbd_done:
        IRET                        ; palaa keskeytyksestä

reset_cursor:
        LOAD  R2, VRAM_START        ; aloita alusta
        JUMP  kbd_done
```

### Ohjelman toiminta

```
 Käyttäjä painaa 'H'
        │
        ▼
 KeyboardDevice.push_key(0x48)  ← puskuri: [0x48]
        │
        ▼
 CPU havaitsee keskeytyksen (I=1) → INT 6
        │
        ▼
 kbd_handler:
   R0 ← LOAD [KBD_DATA]  = 0x48   ('H', painallus)
   bitti 7 = 0 → ei vapautus
   R3 = 0x48 & 0x7F = 0x48
   R1 = 0x0700 | 0x48 = 0x0748
   STORE [R2], 0x0748              → 'H' näkyy näytöllä
   R2 = R2 + 1
   IRET
```

---

## 7. Testidirektiiivit

Näppäimistöä voidaan simuloida testeissä `.inject_key`- ja `.inject_key_release`-direktiiveillä. Ne lisäävät tapahtumat puskuriin **ennen** ohjelman suorituksen alkamista.

| Direktiivi                   | Kuvaus                                          |
| ---------------------------- | ----------------------------------------------- |
| `.inject_key CODE`           | Lisää painallus (koodi `CODE`) puskuriin        |
| `.inject_key_release CODE`   | Lisää vapautus (`CODE \| 0x80`) puskuriin       |

Esimerkki:

```asm
.origin 0x0200

        ; Aseta INT 6 -käsittelija
        LOAD  R0, kbd_handler
        STORE [INT_KEYBOARD], R0
        STI

idle:
        JUMP  idle

kbd_handler:
        LOAD  R1, [KBD_DATA]        ; R1 = tapahtuma
        IRET

; Injektoi 'A' (0x41) painallus ja vapautus ennen ajoa
.inject_key         0x41
.inject_key_release 0x41

; Tarkista: keskeytyksen jälkeen R1 = 0x41 (painallus luettiin)
.expect_reg R1, 0x41
```

---

## 8. Viitteet

- [architecture.md](architecture.md) — Keskeytysmallin ja tilarekisterin kuvaus (STI, CLI, IRET, INT_KEYBOARD)
- [assembler.md](assembler.md) — Arkkitehtuurivakiot ja testidirektiivit
- `kcpu16/devices/keyboard.py` — Laitteen toteutus (Python)
- `kcpu16/constants.py` — `KBD_DATA`, `KBD_STATUS`, `KBD_RELEASE_BIT`, `KBD_KEY_CODE_MASK`, `INT_WRITE_PROTECTED`
- `kcpu16/memory.py` — `WRITE_PROTECTED_REGIONS` (kirjoitussuojatut alueet)
