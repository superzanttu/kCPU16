# CHIP-8 emulaattori kCPU16-assemblerilla

Versio 1.0 — 2026-04-09

---

## 1. Johdanto

Tämä dokumentti analysoi CHIP-8-emulaattorin toteuttamisen mahdollisuuden
kCPU16-assemblerilla. CHIP-8 on 1970-luvun tulkkipohjainen virtuaalikone,
joka suunniteltiin yksinkertaisten pelien ajamiseen. Tavoitteena on toteuttaa
kCPU16-assemblerilla pieni CHIP-8-tulkki, joka kykenee lataamaan ja
suorittamaan alkuperäisiä CHIP-8-ohjelmia (ROM:eja).

---

## 2. CHIP-8-arkkitehtuurin yhteenveto

### 2.1 Muisti

- **4 096 tavua** (12-bittinen osoiteavaruus, 0x000–0xFFF)
- Ohjelmat ladataan osoitteesta **0x200** alkaen
- Osoitteet 0x000–0x1FF varattu tulkille (fonttispriitit, tulkin muuttujat)
- Viimeiset 352 tavua varattu näytön virkistykselle / muuttujille

### 2.2 Rekisterit

| Rekisteri | Koko      | Kuvaus                                    |
| --------- | --------- | ----------------------------------------- |
| V0–VF     | 8 bittiä  | 16 yleiskäyttöistä datarekisteriä         |
| VF        | 8 bittiä  | Lippurekisteri (carry, borrow, collision) |
| I         | 16 bittiä | Osoiterekisteri (käytännössä 12-bittinen) |
| PC        | 16 bittiä | Ohjelmalaskuri (alkuarvo 0x200)           |
| SP        | 8 bittiä  | Pinosoitin                                |
| DT        | 8 bittiä  | Viivästysajastin (laskee alaspäin 60 Hz)  |
| ST        | 8 bittiä  | Ääniajastin (laskee alaspäin 60 Hz, ääni) |

### 2.3 Pino

- 16 tasoa, tallentaa paluuosoitteita (12-bittisiä)

### 2.4 Näyttö

- **64 × 32 pikseliä**, mustavalkoinen (1 bitti/pikseli)
- Piirtäminen XOR-moodissa: spriitin piirtäminen kääntää pikseleitä
- Spriitit aina 8 pikseliä leveitä, 1–15 pikseliä korkeita
- Koordinaatit wrappautuvat (mod 64 / mod 32), mutta spriittejä ei wrapatata — ne klipataan

### 2.5 Näppäimistö

- 16 heksanäppäintä (0–F) alkuperäisessä 4×4-ruudukossa
- Kolme näppäintoimintoa: "onko painettu", "eikö painettu", "odota painallusta"

### 2.6 Ajastimet

- **Viivästysajastin (DT)**: luettavissa ja asetettavissa, laskee 60 Hz:llä nollaan
- **Ääniajastin (ST)**: asetettavissa, laskee 60 Hz:llä — ääni niin kauan kuin > 0

### 2.7 Käskykanta

35 käskyä, kaikki 2 tavua (16 bittiä), big-endian-muodossa. Pääkategoriat:

| Ryhmä                 | Käskyjä | Esimerkkejä                            |
| --------------------- | ------- | -------------------------------------- |
| Näyttö                | 2       | CLS (00E0), DRW (DXYN)                 |
| Kontrollivuo          | 6       | JP, CALL, RET, SE, SNE (vertaa+ohita)  |
| Aritmetiikka/logiikka | 9       | ADD, SUB, AND, OR, XOR, SHR, SHL, SUBN |
| Datansiirto           | 5       | LD Vx, LD I, LD [I], LD B (BCD)        |
| Ajastimet             | 3       | LD DT, LD ST, LD Vx=DT                 |
| Näppäimistö           | 3       | SKP, SKNP, LD Vx=K (blocking)          |
| Satunnaisluku         | 1       | RND Vx, byte                           |
| Erikois               | 3       | FX29 (fonttiosoite), FX33 (BCD), SYS   |

### 2.8 Fonttispriitit

- 16 merkkiä (0–F), kukin 4×5 pikseliä = 5 tavua
- Yhteensä 80 tavua, tallennettu tulkin muistialueelle (< 0x200)

---

## 3. kCPU16-arkkitehtuurin oleelliset ominaisuudet

| Ominaisuus       | kCPU16                                        |
| ---------------- | --------------------------------------------- |
| Sanan leveys     | 16 bittiä                                     |
| Muisti           | 65 536 sanaa (0x0000–0xFFFF)                  |
| Osoiteyksikkö    | sana (ei tavu!)                               |
| Rekisterit       | R0–R15 (16-bittisiä), FP, SP                  |
| Aritmetiikka     | ADD, SUB, MUL, DIV, ADC                       |
| Logiikka         | AND, OR, XOR, NOT, SHL, SHR                   |
| Liput            | Z, N, C, V                                    |
| Ehdolliset hypyt | JZ, JNZ, JLT, JGT, JLE, JGE                   |
| Pino             | PUSH, POP (kasvaa alaspäin)                   |
| VRAM             | 0xF800–0xFF7F (80×24 merkkiä, 1920 sanaa)     |
| Näppäimistö      | MMIO: 0x0020 (data), 0x0021 (tila)            |
| Ajastimet        | TMR (käsky-laskuri), CTMR (millisekuntitason) |
| Keskeytykset     | 10 vektoria (0x0000–0x0009)                   |

---

## 4. Toteutettavuusanalyysi

### 4.1 Muistimapping: CHIP-8 → kCPU16

CHIP-8:n 4 096 tavun muisti täytyy kuvata kCPU16:n sana-osoiteiseen
muistiin. Tämä on emulaattorin **keskeisin suunnittelupäätös**.

#### Vaihtoehto A: Yksi tavu per sana (yksinkertainen)

```
CHIP-8 osoite 0x000 → kCPU16 osoite C8_MEM_BASE + 0x000
CHIP-8 osoite 0xFFF → kCPU16 osoite C8_MEM_BASE + 0xFFF
```

- **Tarvitaan**: 4 096 sanaa (kCPU16 sanoja)
- **Etu**: Yksinkertainen osoitelaskenta — CHIP-8-osoite + vakio-offset
- **Haitta**: Tuhlataan 8 bittiä per sana (vain bittien 0–7 käytössä)
- **Sijoitus**: esim. `0x0400–0x13FF` (vapaalla RAM-alueella)

#### Vaihtoehto B: Kaksi tavua per sana (pakattu)

```
CHIP-8 osoite 0x000 → kCPU16 sanan ylempi tavu (bitit 15–8)
CHIP-8 osoite 0x001 → kCPU16 sanan alempi tavu (bitit 7–0)
Sana = C8_MEM_BASE + (chip8_addr >> 1)
```

- **Tarvitaan**: 2 048 sanaa
- **Etu**: Puolet vähemmän muistia
- **Haitta**: Jokainen tavuoperaatio vaatii shift+mask — merkittävä
  suorituskykykustannus, koska CHIP-8:n _jokainen_ muistiluku/-kirjoitus
  on tavutason operaatio

#### Suositus: Vaihtoehto A

Emulaattori-kontekstissa nopeus on kriittisempi kuin muistitehokkuus.
4 096 sanaa on vain 6,25 % kCPU16:n osoiteavaruudesta — täysin kohtuullista.
Vaihtoehto B:n shift/mask-overhead kertautuu tuhansia kertoja sekunnissa
ja tekee emulaattorista liian hitaan.

### 4.2 Rekisterimapping: CHIP-8-rekisterit → kCPU16

kCPU16:ssa on 16 yleiskäyttöistä rekisteriä (R0–R15) ja CHIP-8:ssa
samoin 16 (V0–VF) sekä lisäksi I, PC, SP, DT, ST.

#### kCPU16-rekisterien käyttö emulaattorissa

| kCPU16-rekisteri | Käyttö emulaattorissa        |
| ---------------- | ---------------------------- |
| R0               | CHIP-8 PC (ohjelmalaskuri)   |
| R1               | CHIP-8 I (osoiterekisteri)   |
| R2               | CHIP-8 SP (pinosoitin, 0–15) |
| R3               | Nykyinen opcode (16 bittiä)  |
| R4               | Väliaikaisrekisteri 1        |
| R5               | Väliaikaisrekisteri 2        |
| R6               | Väliaikaisrekisteri 3        |
| R7               | C8_MEM_BASE-osoite (vakio)   |
| R8–R15           | Väliaikaisrekisterit         |

CHIP-8-rekisterit V0–VF ja DT/ST tallennetaan **muistiin** (ei kCPU16:n
rekistereihin), koska niitä on 18 kappaletta ja niihin kohdistuvat
operaatiot vaativat dynaamista indeksointia (opcode sisältää
rekisterinumeron datana).

```
C8_V0–C8_VF:  16 sanaa muistissa (yksi tavu per sana, bitit 0–7)
C8_DT:         1 sana
C8_ST:         1 sana
C8_STACK:     16 sanaa (16-tason pino, 12-bittisiä paluuosoitteita)
```

Yhteensä: 34 sanaa emulaattorin tilatietoja.

#### Dynaaminen rekisteröinti

CHIP-8-käskyt viittaavat rekistereihin 4-bittisellä indeksillä, joka on
osa opcodea. Emulaattorin täytyy laskea muistiosoite dynaamisesti:

```asm
; Lue CHIP-8 Vx:n arvo, missä x on R4:ssä (0–F)
LOAD R5, C8_V_BASE    ; CHIP-8 V-rekisteritaulukon kantaosoite
ADD  R5, R4           ; R5 = C8_V_BASE + x
LOAD R6, [R5]         ; R6 = Vx:n arvo
```

Tämä toimii suoraviivaisesti kCPU16:n osoitemuodoilla.

### 4.3 Käskydekoodaus

CHIP-8-käskyt ovat 2 tavua (16 bittiä) — **sama kuin yksi kCPU16-sana**,
mikä on erinomainen yhteensopivuustekijä pakattua muistia käytettäessä.
Pakatulla muistilla (vaihtoehto B) saisimme yhden CHIP-8-käskyn
suoraan yhdestä kCPU16-sanan luvusta. Mutta valitulla tavuper-sana
(vaihtoehto A) menetelmällä tarvitaan kaksi lukua:

```asm
; Hae CHIP-8:n seuraava käsky osoitteesta PC (R0)
LOAD R3, R7           ; R3 = C8_MEM_BASE
ADD  R3, R0           ; R3 = C8_MEM_BASE + PC (ylempi tavu)
LOAD R4, [R3]         ; R4 = ylempi tavu
LOAD R5, R0
LOAD R6, 1
ADD  R5, R6
ADD  R5, R7           ; R5 = C8_MEM_BASE + PC + 1
LOAD R6, [R5]         ; R6 = alempi tavu

; Yhdistä 16-bittiseksi opcodeksi
LOAD R8, 8
SHL  R4, R8           ; R4 = ylempi << 8
OR   R4, R6           ; R4 = täysi opcode
CPY  R3, R4           ; R3 = opcode
```

Dekoodaus tapahtuu bittimaskauksen ja shift-operaatioiden avulla:

```asm
; Poimi kentät opcodesta R3
CPY  R4, R3
LOAD R5, 12
SHR  R4, R5           ; R4 = ylin nibble (0x0–0xF) → käskyryhmä

; Poimi X (bitit 11–8)
CPY  R5, R3
LOAD R6, 8
SHR  R5, R6
LOAD R6, 0x000F
AND  R5, R6           ; R5 = X

; Poimi Y (bitit 7–4)
CPY  R6, R3
LOAD R8, 4
SHR  R6, R8
LOAD R8, 0x000F
AND  R6, R8           ; R6 = Y

; Poimi NN (bitit 7–0), NNN (bitit 11–0), N (bitit 3–0)
CPY  R7, R3
LOAD R8, 0x00FF
AND  R7, R8           ; R7 = NN

CPY  R8, R3
LOAD R9, 0x0FFF
AND  R8, R9           ; R8 = NNN

CPY  R9, R3
LOAD R10, 0x000F
AND  R9, R10          ; R9 = N
```

kCPU16:n AND-, OR-, SHL-, SHR-käskyt soveltuvat tähän erinomaisesti.

### 4.4 Käskytoteutus — kriittisten käskyjen analyysi

#### 4.4.1 Aritmetiikka ja logiikka (8XY0–8XYE) — ✅ Suoraviivaista

Kaikki CHIP-8:n aritmetiikka- ja logiikkakäskyt operoivat 8-bittisillä
arvoilla. kCPU16:n ADD, SUB, AND, OR, XOR, SHL, SHR -käskyt toimivat
16-bittisillä arvoilla, joten jokaisen operaation jälkeen tulos pitää
**maskattava 0xFF:llä** 8-bittiseksi:

```asm
; 8XY4: VX = VX + VY, VF = carry
LOAD R4, [R10]        ; R4 = VX
LOAD R5, [R11]        ; R5 = VY
ADD  R4, R5           ; R4 = VX + VY (16-bittisenä)
; Tarkista carry (> 0xFF)
CPY  R6, R4
LOAD R8, 8
SHR  R6, R8           ; R6 > 0 → carry tapahtui
; Maskataan 8 bittiin
LOAD R8, 0x00FF
AND  R4, R8           ; R4 = tulos & 0xFF
STORE R4, [R10]       ; tallenna VX
; Aseta VF
LOAD R8, 0
CMP  R6, R8
JNZ  .carry_set
LOAD R6, 0
JUMP .carry_done
.carry_set:
LOAD R6, 1
.carry_done:
STORE R6, [C8_VF]     ; VF = 0 tai 1
```

Huomautus: CHIP-8:n VF-lippujen semantiikka (0/1 borrow/no-borrow)
eroaa kCPU16:n C/V-lipuista, joten VF täytyy aina laskea eksplisiittisesti.

#### 4.4.2 DRW DXYN — spriitin piirto — ✅ Toteutettavissa, mutta monimutkainen

Tämä on emulaattorin **vaativin käsky**. Se piirtää N tavua korkeaa spriittiä
koordinaatteihin (VX mod 64, VY mod 32) käyttäen XOR-moodia, ja asettaa
VF:n jos jokin pikseli kytkeytyi pois.

**CHIP-8-framebuffer kCPU16-muistissa:**

CHIP-8:n 64×32 näyttö vaatii 64 × 32 = 2 048 pikseliä = 256 tavua
(1 bitti/pikseli, 8/rivi = 8 tavua/rivi × 32 riviä). Tavuper-sana
menetelmällä tämä on 256 sanaa.

Mutta emulaattorin piirto-operaation yksinkertaistamiseksi on parempi
tallentaa kukin pikseli omana sananaan (0 tai 1):

```
C8_SCREEN_BASE: 64 × 32 = 2 048 sanaa (yksi sana per pikseli)
osoite = C8_SCREEN_BASE + y * 64 + x
arvo = 0 (pois) tai 1 (päällä)
```

Tämä on muistinkulutukseltaan kalliimpi (2 048 vs. 256 sanaa), mutta
XOR-piirtäminen ja törmäystunnistus yksinkertaistuvat dramaattisesti:

```asm
; XOR-piirto: yksittäinen pikseli
LOAD R4, [screen_addr]  ; nykyinen pikseliarvo (0 tai 1)
XOR  R4, R5             ; R5 = sprite-bitti (0 tai 1)
STORE R4, [screen_addr] ; tallenna
; Törmäys: jos pikseli meni pois päältä
; (vanha=1 JA uusi=0 → vanha AND NOT uusi)
```

#### DRW:n toteutuksen pseudokoodi:

```
C8_DRW(Vx, Vy, N):
  VF = 0
  y_start = Vy mod 32
  x_start = Vx mod 64
  FOR row = 0 TO N-1:
    y = y_start + row
    IF y >= 32: BREAK (klippaus)
    sprite_byte = C8_MEM[I + row]
    FOR bit = 0 TO 7:
      x = x_start + bit
      IF x >= 64: BREAK (klippaus)
      IF sprite_byte AND (0x80 >> bit):
        screen_addr = C8_SCREEN + y * 64 + x
        old_pixel = MEM[screen_addr]
        MEM[screen_addr] = old_pixel XOR 1
        IF old_pixel == 1:
          VF = 1
```

Toteutus kCPU16-assemblerilla vaatii noin 40–60 käskyä, sisäkkäisine
silmukkoineen. Tämä on emulaattorin monimutkaisin yksittäinen
aliohjelmakokonaisuus, mutta kCPU16:n käskyvarasto riittää siihen hyvin.

#### 4.4.3 CXNN (satunnaisluku) — ⚠️ Vaatii ratkaisun

CHIP-8:n RND-käsky tuottaa satunnaisluvun väliltä 0–255 ja AND:aa sen
NN:llä. kCPU16:ssa **ei ole laitteistopohjaista satunnaislukugeneraattoria**.

**Ratkaisu: ohjelmistopohjainen LFSR (Linear Feedback Shift Register)**

16-bittinen LFSR on kompakti ja riittävän satunnainen pelikäyttöön:

```asm
; 16-bittinen LFSR (Galois), polynomi x^16 + x^14 + x^13 + x^11 + 1
; Tila tallennetaan muuttujaan C8_RNG_STATE
c8_random:
    LOAD R4, [C8_RNG_STATE]
    LOAD R5, R4
    LOAD R6, 1
    AND  R5, R6             ; LSB
    LOAD R6, 1
    SHR  R4, R6             ; siirrä oikealle
    CMP  R5, R6             ; oliko LSB = 1?
    JNZ  .no_xor
    LOAD R5, 0xB400         ; XOR-maski (taps: 16,14,13,11)
    XOR  R4, R5
.no_xor:
    STORE R4, [C8_RNG_STATE]
    LOAD R5, 0x00FF
    AND  R4, R5             ; palautetaan vain alempi tavu
    RET
```

LFSR voidaan siemennyttää kCPU16:n kellonajan MMIO-lukemalla (sekunnit +
millisekunnit osoitteista 0x0015–0x0016) käynnistyksen yhteydessä.

#### 4.4.4 FX33 (BCD-muunnos) — ✅ Toteutettavissa

BCD-muunnos: muunna VX (0–255) kolmeksi numeroksi (sadat, kymmenet, ykköset)
ja tallenna osoitteisiin I, I+1, I+2.

kCPU16:ssa on DIV-käsky (jakojäännös lasketaan: a − (a/b)×b), joten
BCD on suoraviivaista:

```asm
; FX33: BCD(VX) → MEM[I], MEM[I+1], MEM[I+2]
; R4 = VX (0–255)
LOAD R5, 100
CPY  R6, R4
DIV  R6, R5           ; R6 = sadat
STORE R6, [I_addr]    ; MEM[I] = sadat
MUL  R6, R5           ; R6 = sadat * 100
SUB  R4, R6           ; R4 = jäännös (0–99)
LOAD R5, 10
CPY  R6, R4
DIV  R6, R5           ; R6 = kymmenet
STORE R6, [I_addr+1]  ; MEM[I+1] = kymmenet
MUL  R6, R5
SUB  R4, R6           ; R4 = ykköset
STORE R4, [I_addr+2]  ; MEM[I+2] = ykköset
```

#### 4.4.5 FX0A (odota näppäintä) — ✅ Toteutettavissa

Tämä käsky pysäyttää CHIP-8:n suorituksen kunnes näppäintä painetaan.
Emulaattorissa se toteutetaan pitämällä CHIP-8 PC paikallaan ja
tarkistamalla näppäimistöpuskuria joka kierroksella:

```asm
c8_wait_key:
    LOAD R4, [0x0021]     ; KBD_STATUS
    CMP  R4, R0           ; R0 = 0, onko puskuri tyhjä?
    JZ   c8_wait_key      ; kyllä → odota
    LOAD R4, [0x0020]     ; lue näppäinkoodi
    ; Muunna ASCII → CHIP-8 hex-näppäin (0–F)
    ; Tallenna VX:ään
```

#### 4.4.6 Ajastimet (DT, ST, 60 Hz) — ✅ Toteutettavissa

kCPU16:n CTMR (clock timer) tuottaa reaaliaikaisen keskeytyksen
millisekuntitason tarkkuudella. CHIP-8:n 60 Hz -ajastimet toteutetaan:

**Vaihtoehto 1: CTMR-keskeytys (suositeltava)**

Asetetaan CTMR = ~16 ms (≈ 60 Hz). Keskeytyskäsittelijä (Int 9)
dekrementoi DT:tä ja ST:tä kerran per kutsu:

```asm
; Keskeytyskäsittelijä (Int 9): 60 Hz ajastinpäivitys
c8_timer_isr:
    PUSH R4
    PUSH R5
    ; Dekrementoi DT
    LOAD R4, [C8_DT]
    CMP  R4, R5           ; R5 = 0
    JZ   .dt_done
    LOAD R5, 1
    SUB  R4, R5
    STORE R4, [C8_DT]
.dt_done:
    ; Dekrementoi ST
    LOAD R4, [C8_ST]
    LOAD R5, 0
    CMP  R4, R5
    JZ   .st_done
    LOAD R5, 1
    SUB  R4, R5
    STORE R4, [C8_ST]
.st_done:
    POP  R5
    POP  R4
    IRET
```

**Vaihtoehto 2: Pääsilmukassa kellosyklin tarkistus**

Jos keskeytyksiä halutaan välttää, DT/ST voidaan päivittää
pääsilmukan jokaisella kierroksella lukemalla CLOCK_MILLIS (0x0016)
ja laskemalla kulunut aika edellisestä päivityksestä.

### 4.5 Näppäinkartta: CHIP-8 hex → kCPU16 ASCII

CHIP-8:n 16 hex-näppäintä on kartoitettava kCPU16:n
ASCII-näppäimistöön. Yleinen käytäntö:

```
CHIP-8:     kCPU16 (QWERTY):
1 2 3 C     1 2 3 4
4 5 6 D     Q W E R
7 8 9 E     A S D F
A 0 B F     Z X C V
```

Kartoitus toteutetaan hakutaulukolla (16 sanaa):

```
; Indeksi = CHIP-8 näppäin (0x0–0xF)
; Arvo   = ASCII-koodi
c8_keymap:
  .db 'X'    ; 0 → X
  .db '1'    ; 1 → 1
  .db '2'    ; 2 → 2
  .db '3'    ; 3 → 3
  .db 'Q'    ; 4 → Q
  .db 'W'    ; 5 → W
  .db 'E'    ; 6 → E
  .db 'A'    ; 7 → A
  .db 'S'    ; 8 → S
  .db 'D'    ; 9 → D
  .db 'Z'    ; A → Z
  .db 'C'    ; B → C
  .db '4'    ; C → 4
  .db 'R'    ; D → R
  .db 'F'    ; E → F
  .db 'V'    ; F → V
```

Lisäksi tarvitaan käänteinen hakutaulukko (ASCII → CHIP-8 näppäin),
jota käytetään näppäinpainalluksen käsittelyssä. Koska ASCII-koodit
ovat harvassa, käytännöllisin toteutus on pieni lineaarinen haku
16 entryn taulukosta.

Näppäinten **painettu/vapautettu** -tilat tallennetaan 16 sanan
taulukkoon (c8_keys, indeksi 0–F, arvo 0=ei painettu, 1=painettu).
Näppäimistö-keskeytyskäsittelijä (Int 6) päivittää tätä taulukkoa.

### 4.6 Näytön renderöinti: CHIP-8 framebuffer → kCPU16 VRAM

CHIP-8:n 64×32 mustavalkoinen näyttö on esitettävä kCPU16:n 80×24
merkkinäytöllä.

#### Tekstitilassa (nykyisellä näytöllä)

Jokainen CHIP-8-pikseli esitetään **yhtenä merkkinä** VRAM:ssa:

- Pikseli päällä (1): valkoinen täysi blokki `█` (0x88 tai taustaväri)
- Pikseli pois (0): musta väli (tausta)

64 × 32 pikseliä → 64 saraketta × 32 riviä. Koska kCPU16-näyttö on
80×24, tämä ei mahdu suoraan:

| Dimensio | CHIP-8 | kCPU16 | Ongelma?                                       |
| -------- | ------ | ------ | ---------------------------------------------- |
| Leveys   | 64     | 80     | ✅ Mahtuu (8 saraketta tyhjää reunaa per puoli) |
| Korkeus  | 32     | 24     | ❌ **Ei mahdu** — 8 riviä ylimääräistä          |

**Ratkaisu korkeusongelmaan:**

Käytetään grafiikkatila-suunnitelman puoliblokkitekniikkaa (`▀`-merkit).
Jokainen merkkiruutu esittää 2 pikseliä pystyssä:

```
32 pikseliriviä / 2 = 16 merkkiruuturiviä → mahtuu 24 riviin
```

VRAM-renderöinti:

```asm
; Pikseli (x, y) → VRAM-sana
; Merkkiruuturivi = y / 2
; VRAM-osoite = VRAM_START + (y / 2) * 80 + x_offset + x
; missä x_offset = (80 - 64) / 2 = 8 (keskitys)
;
; Jos y on parillinen: aseta FG-väri (ylemmän pikselin väri)
; Jos y on pariton:   aseta BG-väri (alemman pikselin väri)
```

Tämä vaatii **grafiikkatilan** (docs/suunnitelmat/grafiikkatila.md
vaihtoehto A: puoliblokkipikseli) toteuttamista ensin. Käytännössä
CHIP-8-näytön renderöinti on erinomainen ensimmäinen käyttökohde
grafiikkatilalle.

**Vaihtoehtoinen ratkaisu ilman grafiikkatilaa:** Skaalataan CHIP-8-näyttö
64×24:ksi (jätetään 4 pikseliriviä ylä- ja alareunasta pois). Tämä
menettää 25 % pystyresoluutiosta, mutta ei vaadi muutoksia kCPU16:n
näyttöjärjestelmään. Useimmat CHIP-8-ohjelmat käyttävät näytön
keskiosaa, joten käytettävyys säilyy kohtuullisena.

### 4.7 Suorituskyvyn arvio

CHIP-8:n alkuperäinen tulkki ajoi noin **500–700 käskyä/sekunti**
(COSMAC VIP 1,76 MHz:llä). Nykyiset emulaattorit käyttävät tyypillisesti
~500 Hz suoritusnopeutta.

Jokainen CHIP-8-käsky vaatii kCPU16:ssa arviolta:

| Vaihe                         | kCPU16-käskyjä |
| ----------------------------- | -------------- |
| Opcoden haku (2 tavun luku)   | ~10            |
| Dekoodaus (shift+mask)        | ~15            |
| Suoritus (keskimäärin)        | ~15–40         |
| PC:n päivitys                 | ~3             |
| **Yhteensä per CHIP-8-käsky** | **~40–70**     |

Pahimmassa tapauksessa (DRW, FX55/FX65) yksittäinen CHIP-8-käsky
saattaa vaatia 200+ kCPU16-käskyä.

CHIP-8:n 500 käskyä/s × ~60 kCPU16-käskyä = ~30 000 kCPU16-käskyä/s.
kCPU16-emulaattorin Python-toteutus pystyy tyypillisesti kymmeniä
tuhansia tai jopa satojatuhansia käskyjä sekunnissa, joten
**suorituskyky riittää hyvin**.

### 4.8 Ääni (Sound Timer)

kCPU16:ssa ei ole äänilaitetta. CHIP-8:n ääniajastin pyörii, mutta
ääntä ei tuoteta. Tämä on käytännössä ongelmatonta — alkuperäinenkin
CHIP-8-ääni on pelkkä yksittäinen piippaus.

Ääni-indikaattori voidaan näyttää visuaalisesti (esim. VRAM-reunaan
merkki `♪` kun ST > 0).

---

## 5. Muistikartta emulaattorin aikana

```
kCPU16 osoiteavaruus:

$0000 – $0009   Keskeytysvektorit (kCPU16)
$0010 – $001F   Kello-MMIO
$0020 – $0021   Näppäimistö-MMIO
$0022 – $00FF   OS-varaus
$0100 – $01FF   Bootloader (emulaattorin latauskoodi)

$0200 – $03FF   Emulaattorin koodi ja data (osa 1)
$0400 – $13FF   CHIP-8 muisti (4 096 sanaa, yksi tavu/sana)
$1400 – $1BFF   CHIP-8 framebuffer (2 048 sanaa, 64×32, yksi pikseli/sana)
$1C00 – $1C0F   CHIP-8 V-rekisterit (16 sanaa)
$1C10           CHIP-8 DT (1 sana)
$1C11           CHIP-8 ST (1 sana)
$1C12 – $1C21   CHIP-8 pino (16 sanaa)
$1C22           CHIP-8 RNG-tila (1 sana)
$1C23 – $1C32   CHIP-8 näppäintila (16 sanaa)
$1C33 – $1C42   Käänteinen näppäinkartta (16 sanaa)
$1C43 – $1C52   CHIP-8 fonttispriitit (80 sanaa = 80 tavua)
$1C53 – $1CFF   Vapaata
$1D00 – $F7FF   Emulaattorin koodi (osa 2, pääohjelma + aliohjelmakutsu)

$F800 – $FF7F   VRAM (kCPU16 näyttö)
$FF80 – $FFFF   Kernel-pino
```

Emulaattorin koodille jää ~55 000 sanaa, mikä on yli riittävästi.

---

## 6. Tarvittavat kCPU16-muutokset

### 6.1 Ei vaaduta (toimii nykyisellään)

| Ominaisuus               | Perustelu                                                            |
| ------------------------ | -------------------------------------------------------------------- |
| Käskyvarasto             | AND, OR, XOR, SHL, SHR, ADD, SUB, MUL, DIV, CMP — kaikki tarvittavat |
| Muistikapasiteetti       | 64K sanaa >> 4K + 2K + koodi                                         |
| Rekisterimäärä           | 16 rekisteriä riittää emulaattorin muuttujiin                        |
| Epäsuora osoitus         | READ_IND / STORE_IND dynaamista taulukkokäyttöä varten               |
| MMIO-näppäimistö         | $0020/$0021 toimii CHIP-8-tulkin syötteenä                           |
| Pino (PUSH/POP/CALL/RET) | Emulaattorin aliohjelmakutsuja varten                                |
| Kellosykli-MMIO          | RNG-siemennys ja ajastinlaskenta                                     |

### 6.2 Erittäin suositeltava (mutta ei pakollinen)

| Muutos                              | Syy                                                                                           | Prioriteetti |
| ----------------------------------- | --------------------------------------------------------------------------------------------- | ------------ |
| **Grafiikkatilan puoliblokkimoodi** | CHIP-8:n 32 pikselirivin mahduttaminen 24 merkkiruuturiville vaatii 2 pikseliä per merkkirivi | Korkea       |
| **CTMR-keskeytys (Int 9) testaus**  | 60 Hz -ajastimet vaativat luotettavan reaaliaikaisen keskeytyksen                             | Korkea       |

### 6.3 Valinnainen (parantaisi käyttökokemusta)

| Muutos                     | Syy                                                           |
| -------------------------- | ------------------------------------------------------------- |
| CHIP-8 ROM-latausmekanismi | ROM:n lataaminen levyltä emulaattorin muistiin (DREAD/DWRITE) |
| Emulaattorin nopeudensäätö | Käyttäjä voi säätää CHIP-8-käskyjen/s -nopeutta               |
| Debuggeri/TUI-integraatio  | CHIP-8-rekisterit ja muisti näkyviin debuggerissa             |

---

## 7. Emulaattorin arkkitehtuuri

### 7.1 Pääsilmukka

```
c8_main_loop:
    ; 1. Hae CHIP-8-käsky (2 tavua → 16-bittinen opcode)
    CALL c8_fetch

    ; 2. Dekoodaa opcode
    CALL c8_decode

    ; 3. Suorita käsky (dispatch ylimmän nibblen perusteella)
    CALL c8_execute

    ; 4. Päivitä CHIP-8 PC (+2)
    LOAD R4, 2
    ADD  R0, R4

    ; 5. Renderöi framebuffer → VRAM (vain jos dirty-lippu asetettu)
    CALL c8_render_if_dirty

    ; 6. Toista
    JUMP c8_main_loop
```

### 7.2 Käskynkäsittely (dispatch)

Ylimmän nibblen (0x0–0xF) perusteella hypätään oikeaan handleriiin.
Koska kCPU16:ssa ei ole epäsuoraa hyppyä (JUMP [R4]),
dispatch toteutetaan **vertailuketjuna** tai **hyppytaulukkona**.

**Vaihtoehto A: vertailuketju**

```asm
c8_execute:
    ; R4 = ylin nibble (0–F)
    CMP  R4, R5           ; R5 = 0
    JZ   c8_exec_0xxx
    LOAD R5, 1
    CMP  R4, R5
    JZ   c8_exec_1xxx     ; JP addr
    LOAD R5, 2
    CMP  R4, R5
    JZ   c8_exec_2xxx     ; CALL addr
    ; ... jne. 16 vertailua
```

**Vaihtoehto B: hyppytaulukko** (tehokkaampi)

```asm
; Hyppytaulukon alkuosoite
c8_jump_table:
    .db c8_exec_0xxx      ; nibble 0
    .db c8_exec_1xxx      ; nibble 1
    .db c8_exec_2xxx      ; nibble 2
    ; ... 16 entryä

c8_execute:
    ; R4 = ylin nibble (0–F)
    LOAD R5, c8_jump_table
    ADD  R5, R4            ; R5 = &jump_table[nibble]
    LOAD R6, [R5]          ; R6 = kohdeosoite
    ; Tarvitaan: JUMP [R6] eli epäsuora hyppy!
```

Tämä vaatii **epäsuoran hypyn** (JUMP [Rx]), jota kCPU16:ssa ei
tällä hetkellä ole. Katso kohta 6.2/7.3 vaihtoehto.

### 7.3 Epäsuora hyppy — puuttuva käsky

kCPU16:n JUMP-käsky ottaa suoran osoitteen (16-bittinen literaali).
Epäsuoraa hyppyä rekisterin kautta (`JUMP [Rx]` tai `JMP_IND Rx`) ei ole.

**Tämä on merkittävin arkkitehtuurinen rajoitus emulaattoria ajatellen.**

Ilman epäsuoraa hyppyä jokainen dispatch vaatii pitkän vertailuketjun,
mikä hidastaa suoritusta. CHIP-8:n 35 käskyn dekoodaus vaatii jopa
35 CMP+JZ-paria pahimmillaan, mikä tarkoittaa ~70 lisäkäskyä per
CHIP-8-käsky pelkkään dispatchiin.

**Vaihtoehtoinen ratkaisu ilman ISA-muutosta:**

Itsemuokkaava koodi: kirjoitetaan kohdesoitteoite JUMP-käskyn
operandiksi ajon aikana:

```asm
; R6 = kohdeosoite (laskettu hyppytaulukosta)
LOAD R5, c8_dispatch_jump + 1  ; JUMP-käskyn operandin osoite
STORE R6, [R5]                 ; kirjoita kohde operandiksi
c8_dispatch_jump:
    JUMP 0x0000                ; tämä osoite ylikirjoitetaan yllä
```

Tämä toimii kCPU16:ssa, koska se on von Neumann -arkkitehtuuri (koodi
ja data samassa muistissa). Itsemuokkaava koodi on perinteinen
tekniikka, jota käytettiin laajasti 8-bittisillä koneilla juuri
tällaisiin tilanteisiin.

**Suositus: toteuta JUMP_IND (epäsuora hyppy) kCPU16:n ISA:an.**

Se olisi hyödyllinen myös muissa konteksteissa (funktio-osoittimet,
callback-taulukot, switch-case -toteutukset).

| Uusi käsky | Operandit | Toiminto | Opcode-ehdotus |
| ---------- | --------- | -------- | -------------- |
| `JUMP_IND` | reg       | PC = reg | GRP=5, ID=9    |
| `CALL_IND` | reg       | CALL reg | GRP=5, ID=10   |

---

## 8. ROM-tiedostojen lataaminen

CHIP-8 ROM-tiedostot ovat raakoja binääritiedostoja (ei otsikoita).
Latausstrategia:

### 8.1 Vaihtoehto A: Storage-laitteen kautta

1. ROM kirjoitetaan storage-laitteen levysektoreihin (`*.dsk`-tiedostoon)
2. Bootloader lukee sektorit DREAD-käskyllä ja kopioi ne
   `C8_MEM_BASE + 0x200`:sta alkaen

### 8.2 Vaihtoehto B: Assembler-inlining

ROM-data sisällytetään assembler-lähdekoodiin `.db`-direktiivillä:

```asm
.origin C8_MEM_BASE + 0x200
c8_rom_data:
    .db 0x00, 0xE0    ; CLS
    .db 0x62, 0x0C    ; LD V2, 12
    ; ... ROM-data tavuittain
```

Tämä on yksinkertaisempi kehityksen aikana, mutta rajoittaa ROM:in
vaihdon assemblerin uudelleenkääntämiseen.

### 8.3 Vaihtoehto C: Konvertteri-työkalu (Python)

Python-skripti, joka lukee `.ch8`-tiedoston ja tuottaa joko:
- `.asm`-tiedoston `.db`-riveinä (vaihtoehto B:hen)
- `.dsk`-levykuvan (vaihtoehto A:han)

---

## 9. Toteutusjärjestys

### Vaihe 1: Alustavat valmiudet

1. **Grafiikkatilan puoliblokkimoodi** — CHIP-8:n 64×32 näytön renderöinti
   kCPU16:n 80×24 näytöllä (32 pikseliä → 16 merkkiruuturiviä)
2. **CTMR-keskeytyksen testaus** — 60 Hz -ajastin DT/ST-päivityksille
3. (Valinnainen) **JUMP_IND-käsky** — epäsuora hyppy dispatchiin

### Vaihe 2: Emulaattorin ydin

4. **Muistialueet ja alustus** — C8_MEM, C8_SCREEN, C8_V, C8_STACK, jne.
5. **Fonttispriittien lataus** — 80 tavua osoitteisiin C8_MEM + 0x000–0x04F
6. **Käskyn haku (fetch)** — 2 tavun luku, yhdistäminen 16-bittiseksi
7. **Käskyn dekoodaus (decode)** — nibblejen erottelu
8. **Dispatch-mekanismi** — ylätason nibble → handler

### Vaihe 3: Käskytoteutukset (helpoimmasta vaikeimpaan)

9. **Kontrollivuo**: JP (1NNN), CALL (2NNN), RET (00EE)
10. **Datasiirto**: LD Vx (6XNN), LD I (ANNN), LD Vx=Vy (8XY0)
11. **Ehdolliset ohitukset**: SE (3XNN, 5XY0), SNE (4XNN, 9XY0)
12. **Aritmetiikka/logiikka**: ADD, SUB, AND, OR, XOR, SHR, SHL, SUBN (8XY_)
13. **Ajastimet**: LD DT (FX15), LD ST (FX18), LD Vx=DT (FX07)
14. **Muistioperaatiot**: LD [I] (FX55), LD Vx (FX65), LD B (FX33)
15. **Näppäimistö**: SKP (EX9E), SKNP (EXA1), LD Vx=K (FX0A)
16. **Satunnaisluku**: RND (CXNN) + LFSR-toteutus
17. **Piirto**: CLS (00E0), DRW (DXYN) + framebuffer + VRAM-renderöinti

### Vaihe 4: Integraatio

18. **Pääsilmukan koonnos** — kaikki osat yhteen
19. **ROM-lataus** — testiohjelman lataaminen
20. **Nopeudensäätö** — CHIP-8-käskyjen nopeuden rajoitus (~500 Hz)
21. **Testaus** — tunnettujen ROM:ien ajaminen (IBM Logo, Pong, Tetris)
22. **Debuggaus** — kCPU16-debuggerin hyödyntäminen CHIP-8-tilan tarkastelussa

---

## 10. Koodin koko-arvio

| Komponentti                       | Arvio (kCPU16-sanoja) |
| --------------------------------- | --------------------- |
| Pääsilmukka + dispatch            | ~100                  |
| Käskyn haku + dekoodaus           | ~80                   |
| Kontrollivuo (JP/CALL/RET/SE/SNE) | ~150                  |
| Aritmetiikka/logiikka (8XY_)      | ~300                  |
| DRW (spriitin piirto)             | ~200                  |
| VRAM-renderöinti                  | ~150                  |
| Ajastimet + ISR                   | ~80                   |
| Näppäimistö + ISR                 | ~120                  |
| BCD, RND, LD [I], LD Vx           | ~200                  |
| FX29 (fonttiosoite)               | ~30                   |
| Alustus + fonttispriitit          | ~150                  |
| Muut (kartat, vakiot, data)       | ~200                  |
| **Yhteensä**                      | **~1 760**            |

Arvio: noin **1 500–2 500 sanaa** kCPU16-koodia. Tämä on toteutettavissa,
mutta kyseessä on merkittävä assembly-projekti. Vertailun vuoksi:
yksinkertainen "Hello World" on ~20 sanaa ja kellodemo ~200 sanaa.

---

## 11. Riskit ja rajoitukset

| Riski                                      | Vakavuus  | Lieventäminen                                                                  |
| ------------------------------------------ | --------- | ------------------------------------------------------------------------------ |
| **Suorituskyky** — emulointikehä on raskas | Keskitaso | kCPU16 on riittävän nopea; dirty-flag estää turhaa renderöintiä                |
| **DRW-käskyn monimutkaisuus**              | Korkea    | XOR-piirto pikseli-per-sana muodossa on selkeä; testattava huolella            |
| **Dispatch-overhead ilman JUMP_IND**       | Keskitaso | Itsemuokkaava koodi tai vertailuketju toimivat                                 |
| **Grafiikkatilan puuttuminen**             | Korkea    | Ilman puoliblokkilta CHIP-8-näyttö ei mahdu; väliaikainen klippaus mahdollinen |
| **ROM-yhteensopivuus**                     | Matala    | CHIP-8 on hyvin standardoitu; shift-quirk valittava                            |
| **Äänen puuttuminen**                      | Matala    | Visuaalinen indikaattori riittää                                               |
| **Debuggauksen vaikeus**                   | Keskitaso | kCPU16-debuggeri auttaa; CHIP-8-tilan näyttörutiini kehityksen ajaksi          |

---

## 12. Johtopäätökset

### Onko CHIP-8-emulaattori toteutettavissa kCPU16-assemblerilla?

**Kyllä.** kCPU16:n käskyvarasto, muistikapasiteetti ja
arkkitehtuuriset ominaisuudet riittävät CHIP-8-emulaattorin
toteuttamiseen. Merkittäviä esteitä ei ole.

### Keskeiset vahvuudet

1. **16-bittinen arkkitehtuuri** — CHIP-8:n 16-bittiset opcodet mahtuvat
   suoraan yhteen kCPU16-sanaan
2. **Riittävä käskyvarasto** — AND, OR, XOR, SHL, SHR, DIV, MUL
   kattavat kaikki tarvittavat operaatiot
3. **Suuri muisti** — 64K sanaa vs. 4K tarvetta → tilaa on runsaasti
4. **Epäsuora osoitus** — READ_IND ja STORE_IND mahdollistavat
   dynaamisen rekisteri- ja muistitaulukkokäytön
5. **MMIO-näppäimistö** — suoraan käytettävissä ilman muutoksia
6. **CTMR-ajastin** — 60 Hz -keskeytys ajastimille

### Tarvittavat muutokset (prioriteettijärjestyksessä)

1. **Grafiikkatilan puoliblokkimoodi** (korkea) — tarvitaan näytön
   renderöintiin ilman klippausta
2. **JUMP_IND-käsky** (keskitaso) — merkittävä suorituskykuparannus
   dispatch-mekanismiin; ilman tätäkin emulaattori toimii
   itsemuokkaavaa koodia käyttäen
3. **ROM-lataustyökalu** (matala) — Python-skripti `.ch8` → `.asm`/`.dsk`

### Laajuus

Kyseessä on merkittävä (~1 500–2 500 sanaa) assembly-projekti, joka
tarjoaa erinomaisen harjoituskohteen kCPU16-arkkitehtuurin monipuoliseen
hyödyntämiseen. Emulaattori testaa käytännössä kaikkia kCPU16:n
ominaisuuksia: aritmetiikkaa, logiikkaa, epäsuoraa osoitusta,
keskeytyksiä, ajastimia, VRAM-käsittelyä ja näppäimistöä.
