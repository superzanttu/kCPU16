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
- kCPU16:ssa on toteutettuna grafiikkatila B (80×48), joka on riittävä CHIP-8:n 64×32-kuvalle.
- CHIP-8-piirto voidaan tehdä emulaattorin omalla 64×32 1bpp -framebufferilla ja piirtää siitä tila B:hen ilman uuden näyttötilan toteutusta.

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

---

## 7. Toteutettavuuden vahvistus

Alla on jokainen CHIP-8:n keskeinen vaatimus ja kCPU16:n vastaava toteutustapa.

| CHIP-8-vaatimus                     | kCPU16:n toteutustapa                                            | Tila |
| ----------------------------------- | ---------------------------------------------------------------- | ---- |
| 4 KB tavumuisti (0x000–0xFFF)       | 4096 sanaa 1 tavu/sana -mallilla → alue 0x6000–0x6FFF            | ✓    |
| V0–VF (16 × 8-bit rekisteriä)       | 16 sanaa muistissa (label `chip8_v`)                             | ✓    |
| I-, PC-, SP-, DT-, ST-rekisterit    | Yksittäiset muistisanat (labelit)                                | ✓    |
| 16-tason kutsupinorakenne           | 16-sanainen taulukko muistissa (`chip8_stk`)                     | ✓    |
| 60 Hz -ajastimet (DT, ST)           | `SCTMR` + `INT 9` (~17 ms välein)                                | ✓    |
| 64×32-pikselin näyttö               | Oma 2048-sanainen framebuffer + piirto grafiikkatilaan B (80×48) | ✓    |
| 16-näppäiminen hex-keypad           | ASCII-mappaus + `KBD_DATA` MMIO (0x0020) + `INT 6`               | ✓    |
| Satunnaisluku `CXNN`                | `RAND_MMIO` (0x0022) + `AND` NN-maskilla                         | ✓    |
| Bittioperaatiot `8XY*`              | `AND`, `OR`, `XOR`, `NOT`, `SHL`, `SHR`                          | ✓    |
| Yhteenlasku carry / borrow `8XY4–5` | `ADD`, `SUB`, `CMP` + manuaalinen VF-asetus                      | ✓    |
| Opcode-dispatch (16 ryhmää)         | `CALLI R15, h0, h1, … h15`                                       | ✓    |
| Alaryhmädispatch `8XYN`, `FXNN`     | Sisäkkäinen `CALLI` tai `CMP`/`JZ`-ketju                         | ✓    |
| XOR-sprite-piirto `DXYN`            | `SHR`-bittipurku + `XOR` + framebuffer-silmukka                  | ✓    |
| BCD-muunnos `FX33`                  | `DIV 100` + `DIV 10`                                             | ✓    |
| Odota näppäintä `FX0A`              | Busy-wait + `chip8_wait`-lippu + `INT 6` -integraatio            | ✓    |
| Muistioperaatiot `FX55`, `FX65`     | `READ [R]`/`STORE [R]` -silmukka                                 | ✓    |

**Johtopäätös:** kCPU16:n käskyjoukko ja I/O-rakenne mahdollistavat täydellisen CHIP-8-emulaattorin ilman arkkitehtuurimuutoksia.

**Rajoitteet:**
- **1 tavu per sana**: käyttää 4× enemmän muistia kuin pakattu malli, mutta sopii hyvin 65 536 sanan muistiavaruuteen (koodin + datan jälkeen tilaa riittää).
- **Ääni**: kCPU16:ssa ei ole natiivissa äänentoistoa; `ST > 0` voi näkyä visuaalisena ilmoituksena.
- **FX0A busy-wait**: yksinkertaisin toteutus on silmukka, joka tarkistaa `chip8_wait`-lipun joka kierroksella; tämä ei keskeytä suoritusta, mutta toimii oikein.

---

## 8. Ohjelman runko kCPU16-konekielellä

Alla on annotaatioitu hahmotelma `chip8_emu.asm` -tiedostosta. Se kattaa kaikki rakenteelliset osat: alustus, keskeytysenkäsittelijät, fetch/decode/dispatch-silmukka ja opkoodikäsittelijät. Merkinnät `; TODO` osoittavat kohtia, joissa täydellinen toteutus vaatii lisää rekisterinhallintaa tai bittilaskentaa.

### 8.1 Muistilayout

```
0x0200 – 0x3FFF   Emulaattorikoodi ja inline-data (V, I, PC, SP, DT, ST, STK, fontti)
0x4000 – 0x407F   Näppäinmappaustaulu KEYMAP (128 sanaa, alustetaan main:issa)
0x5000 – 0x57FF   Framebuffer CH8_FB (64×32 = 2048 sanaa, 1 sana/pikseli)
0x6000 – 0x6FFF   CHIP-8-muisti CH8_MEM (4096 sanaa, 1 CHIP-8-tavu/sana)

CHIP-8-osoitemuunnos:  kCPU16-osoite = CH8_MEM + chip8_osoite
  Esim. CHIP-8 PC=0x200  →  kCPU16-osoite 0x6200

Näppäinmappaus (CHIP-8 hex-keypad → PC-näppäimistö):
  1 2 3 C  →  1 2 3 4
  4 5 6 D  →  Q W E R
  7 8 9 E  →  A S D F
  A 0 B F  →  Z X C V

Huom: ohjelma ajaa kernel-tilassa (SCTMR, STI, IRET vaativat kernel-tilan).
      Tämä on yhdenmukaista muiden demojen kanssa (.origin 0x0200 + kernel-käskyt).
```

### 8.2 Runkokoodi

```asm
; =============================================================================
; chip8_emu.asm — CHIP-8-emulaattori kCPU16-konekielellä
; =============================================================================

        .origin 0x0200

        JUMP  main              ; Hyppää pääohjelmaan ohi datan ja aliohjelmien

; =============================================================================
; VAKIOT
; =============================================================================

.const CH8_MEM,     0x6000     ; CHIP-8-muistin kCPU16-perusosoite (4096 sanaa)
.const CH8_MEM_END, 0x6FFF     ; CHIP-8-muistin viimeinen sana
.const CH8_FB,      0x5000     ; Framebufferin perusosoite (64×32 = 2048 sanaa)
.const CH8_FB_END,  0x57FF     ; Framebufferin viimeinen sana
.const CH8_FB_W,    64         ; Framebufferin leveys pikseleinä
.const CH8_FB_H,    32         ; Framebufferin korkeus pikseleinä
.const KEYMAP,      0x4000     ; Näppäinmappaustaulu (128 sanaa, ASCII → CHIP-8-näppäin)
.const KEYMAP_END,  0x407F     ; Näppäintaulun viimeinen sana
.const TICK_MS,     17         ; ~60 Hz kellotikki millisekunteina
.const KBD_MMIO,    0x0020     ; Näppäimistö-MMIO (pops + palauttaa tapahtuman)
.const RAND_MMIO,   0x0022     ; Satunnaisluku-MMIO (LFSR)
.const GFX_MODE_REG, 0xFF80    ; Grafiikkatilan rekisteri
.const GFX_FLIP_REG, 0xFF81    ; Kaksoisbufferin flip-rekisteri (kirjoitus = päivitä)
.const VRAM_START,  0xF800     ; Näyttömuistin alku
.const VRAM_END,    0xFF7F     ; Näyttömuistin loppu
.const SCR_OFS_X,   8          ; CHIP-8-kuvan X-siirtymä ruudulla (centering, 80-64)/2
.const SCR_OFS_Y,   8          ; CHIP-8-kuvan Y-siirtymä ruudulla (centering, 48-32)/2

; =============================================================================
; INLINE-DATA: CHIP-8-tila (tallennettu heti koodin alkuun, JUMP ohittaa)
; =============================================================================

; V0–VF: 16 rekisteriä (8-bit arvo, tallennettu sanaan)
chip8_v:
        .db 0, 0, 0, 0, 0, 0, 0, 0
        .db 0, 0, 0, 0, 0, 0, 0, 0
chip8_i:    .db 0       ; I-rekisteri (12-bit CHIP-8-osoite)
chip8_pc:   .db 0x200   ; Ohjelmalaskuri (alkaa 0x200)
chip8_sp:   .db 0       ; Pinosoitin (0–15)
chip8_dt:   .db 0       ; Viivästysajastin (laskee 60 Hz:llä)
chip8_st:   .db 0       ; Ääniajastin (laskee 60 Hz:llä)

; Kutsupinorakenne: 16 × 12-bittinen paluuosoite
chip8_stk:
        .db 0, 0, 0, 0, 0, 0, 0, 0
        .db 0, 0, 0, 0, 0, 0, 0, 0
chip8_key:  .db 0       ; Näppäintila-maski (bitti N = näppäin N painettu)
chip8_wait: .db 0xFFFF  ; FX0A-odotus: 0–15 = kohde-VX-indeksi, 0xFFFF = ei odoteta

; CHIP-8-fontti: 16 merkkiä × 5 tavua = 80 sanaa
; Kopioidaan main:issa CH8_MEM[0x000]–CH8_MEM[0x04F]:iin
chip8_font:
        .db 0xF0, 0x90, 0x90, 0x90, 0xF0  ; 0
        .db 0x20, 0x60, 0x20, 0x20, 0x70  ; 1
        .db 0xF0, 0x10, 0xF0, 0x80, 0xF0  ; 2
        .db 0xF0, 0x10, 0xF0, 0x10, 0xF0  ; 3
        .db 0x90, 0x90, 0xF0, 0x10, 0x10  ; 4
        .db 0xF0, 0x80, 0xF0, 0x10, 0xF0  ; 5
        .db 0xF0, 0x80, 0xF0, 0x90, 0xF0  ; 6
        .db 0xF0, 0x10, 0x20, 0x40, 0x40  ; 7
        .db 0xF0, 0x90, 0xF0, 0x90, 0xF0  ; 8
        .db 0xF0, 0x90, 0xF0, 0x10, 0xF0  ; 9
        .db 0xF0, 0x90, 0xF0, 0x90, 0x90  ; A
        .db 0xE0, 0x90, 0xE0, 0x90, 0xE0  ; B
        .db 0xF0, 0x80, 0x80, 0x80, 0xF0  ; C
        .db 0xE0, 0x90, 0x90, 0x90, 0xE0  ; D
        .db 0xF0, 0x80, 0xF0, 0x80, 0xF0  ; E
        .db 0xF0, 0x80, 0xF0, 0x80, 0x80  ; F

; =============================================================================
; KESKEYTYSENKÄSITTELIJÄ: Näppäimistö (INT 6)
;
; Lukee KBD_MMIO-tapahtuman, hakee CHIP-8-näppäinnumeron KEYMAP:ista,
; päivittää chip8_key:n bittimaskin (painallus=aseta, vapautus=nollaa)
; ja tarkistaa FX0A-odotustilan.
;
; Clobbers: R0, R1, R2 (tallennetaan pinoon)
; =============================================================================
kbd_handler:
        PUSH  R0
        PUSH  R1
        PUSH  R2

        READ  R0, [KBD_MMIO]           ; Lue + poppaa tapahtuma MMIO-jonosta
        CMP   R0, 0
        JZ    kbd_done                 ; Jono tyhjä → palaa

        ; Erottele vapautusbitti (0x80) ja ASCII-koodi (bitit 6–0)
        READ  R1, 0x0080
        AND   R1, R0                   ; R1 = vapautusbitti (0 tai 0x80)
        READ  R2, 0x007F
        AND   R2, R0                   ; R2 = ASCII-koodi (0–127)

        ; Hae CHIP-8-näppäinnumero KEYMAP:ista
        READ  R0, KEYMAP
        ADD   R0, R2                   ; R0 = &KEYMAP[ascii]
        READ  R0, [R0]                 ; R0 = CHIP-8-näppäinnumero (tai 0xFF)
        CMP   R0, 0xFF
        JZ    kbd_done                 ; Ei mappaus → ohita

        ; Laske bittimaski: 1 << chip8_näppäinnumero
        READ  R2, 1
        SHL   R2, R0                   ; R2 = 1 << näppäinnumero

        ; Päivitä chip8_key-maski (painallus tai vapautus)
        READ  R0, [chip8_key]
        CMP   R1, 0
        JNZ   kbd_release
        OR    R0, R2                   ; Painallus → aseta bitti
        JUMP  kbd_key_done
kbd_release:
        NOT   R2
        AND   R0, R2                   ; Vapautus → nollaa bitti
kbd_key_done:
        STORE [chip8_key], R0

        ; FX0A-odotustila: talleta näppäinnumero VX:iin jos odotetaan
        READ  R0, [chip8_wait]
        CMP   R0, 0xFFFF
        JZ    kbd_done                 ; Ei odoteta → valmis

        ; Aseta VX = näppäinnumero ja poista odotustila
        ; R0 = VX-indeksi (0–15), R2 = nollattu bittimaski (vanha) → tarvitaan näppäinnumero uudelleen
        ; TODO: tallenna näppäinnumero erilliseen muuttujaan tai laske uudelleen
        READ  R1, chip8_v
        ADD   R1, R0                   ; R1 = &chip8_v[VX]
        READ  R2, [chip8_key]          ; R2 = tilamaski — TODO: laske uusin näppäinnumero
        STORE [R1], R2                 ; VX = näppäinnumero (tarkennettava)
        STORE [chip8_wait], 0xFFFF     ; Poista odotustila
kbd_done:
        POP   R2
        POP   R1
        POP   R0
        IRET

; =============================================================================
; KESKEYTYSENKÄSITTELIJÄ: Kellokeskeytys (INT 9, ~60 Hz)
;
; Laskee DT- ja ST-ajastimia alas ja asettaa seuraavan tikin.
; =============================================================================
clk_handler:
        PUSH  R0
        PUSH  R1

        READ  R0, [chip8_dt]
        CMP   R0, 0
        JZ    clk_st
        READ  R1, 1
        SUB   R0, R1
        STORE [chip8_dt], R0
clk_st:
        READ  R0, [chip8_st]
        CMP   R0, 0
        JZ    clk_done
        READ  R1, 1
        SUB   R0, R1
        STORE [chip8_st], R0
        ; ST > 0 → ääni päälle (kCPU16:ssa: voi esim. näyttää visuaalisen indikaattorin)
clk_done:
        READ  R0, TICK_MS
        SCTMR R0                       ; Aseta seuraava ~60 Hz -tikkijärjestelmä
        POP   R1
        POP   R0
        IRET

; =============================================================================
; ALIOHJELMA: stack_push — Tallenna arvo CHIP-8-kutsupinorakenteeseen
; Sisääntulo: R0 = tallennetava arvo (CHIP-8-osoite)
; Clobbers: R1, R2
; =============================================================================
stack_push:
        READ  R1, [chip8_sp]           ; R1 = SP
        READ  R2, chip8_stk
        ADD   R2, R1                   ; R2 = &chip8_stk[SP]
        STORE [R2], R0                 ; Tallenna
        ADD   R1, 1
        STORE [chip8_sp], R1           ; SP++
        RET

; =============================================================================
; ALIOHJELMA: stack_pop — Hae arvo CHIP-8-kutsupinorakenteesta
; Ulostulo: R0 = haettu arvo
; Clobbers: R1
; =============================================================================
stack_pop:
        READ  R0, [chip8_sp]
        READ  R1, 1
        SUB   R0, R1                   ; SP--
        STORE [chip8_sp], R0
        READ  R1, chip8_stk
        ADD   R1, R0                   ; R1 = &chip8_stk[SP]
        READ  R0, [R1]                 ; R0 = paluuosoite
        RET

; =============================================================================
; ALIOHJELMA: draw_screen
;
; Kopioi 64×32-framebufferin kCPU16:n VRAM-tilaan B (80×48 px).
; CHIP-8-kuva keskitetään 8px marginaaleilla (X+8, Y+8).
;
; Tila B: VRAM-sana = VRAM_START + (screen_y/2)*80 + screen_x
;   Bitti 1 (arvo 2) = ylempi pikseli (y parillinen)
;   Bitti 0 (arvo 1) = alempi pikseli (y pariton)
;
; Clobbers: R0–R9
; =============================================================================
draw_screen:
        ; Tyhjennä VRAM
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R8, 0                    ; R8 = y (0..31)
draw_y:
        CMP   R8, CH8_FB_H
        JGE   draw_done
        READ  R7, 0                    ; R7 = x (0..63)
draw_x:
        CMP   R7, CH8_FB_W
        JGE   draw_x_done

        ; Laske framebuffer-osoite: CH8_FB + y*64 + x
        CPY   R9, R8
        READ  R0, 6
        SHL   R9, R0                   ; R9 = y * 64
        ADD   R9, R7
        READ  R0, CH8_FB
        ADD   R9, R0                   ; R9 = &ch8_fb[y][x]
        READ  R0, [R9]                 ; R0 = pikselin arvo
        CMP   R0, 0
        JZ    draw_next

        ; screen_y = y + SCR_OFS_Y,  screen_x = x + SCR_OFS_X
        CPY   R3, R8
        ADD   R3, SCR_OFS_Y            ; R3 = screen_y
        CPY   R4, R7
        ADD   R4, SCR_OFS_X            ; R4 = screen_x

        ; VRAM-osoite: VRAM_START + (screen_y/2)*80 + screen_x
        CPY   R5, R3
        READ  R0, 1
        SHR   R5, R0                   ; R5 = screen_y / 2
        READ  R0, 80
        MUL   R5, R0
        ADD   R5, R4
        READ  R0, VRAM_START
        ADD   R5, R0                   ; R5 = VRAM-osoite

        ; Ylempi vai alempi pikseli? → tarkista y:n parillisuus
        READ  R6, 1
        AND   R6, R3                   ; R6 = screen_y & 1
        CMP   R6, 0
        JNZ   draw_lower
        READ  R6, 2                    ; Parillinen → bitti 1 (arvo 2 = ylempi)
        JUMP  draw_set
draw_lower:
        READ  R6, 1                    ; Pariton  → bitti 0 (arvo 1 = alempi)
draw_set:
        READ  R0, [R5]
        OR    R0, R6
        STORE [R5], R0
draw_next:
        ADD   R7, 1
        JUMP  draw_x
draw_x_done:
        ADD   R8, 1
        JUMP  draw_y
draw_done:
        STORE [GFX_FLIP_REG], 1        ; Triggeroi kaksoisbufferin vaihto
        RET

; =============================================================================
; PÄÄOHJELMA: Alustus
; =============================================================================
main:
        ; Aseta keskeytyksen vektorit (kernel-tila)
        STORE [0x0006], kbd_handler    ; INT 6 = näppäimistö
        STORE [0x0009], clk_handler    ; INT 9 = kellokeskeytys

        ; Nollaa V0–VF
        READ  R0, chip8_v
        READ  R1, chip8_v
        ADD   R1, 15                   ; R1 = chip8_v[15] = &VF
        READ  R2, 0
        FILL  R0, R1, R2

        ; Nollaa muut tilamuuttujat
        STORE [chip8_i],    0
        STORE [chip8_pc],   0x200
        STORE [chip8_sp],   0
        STORE [chip8_dt],   0
        STORE [chip8_st],   0
        STORE [chip8_key],  0
        STORE [chip8_wait], 0xFFFF

        ; Nollaa framebuffer (2048 sanaa)
        READ  R0, CH8_FB
        READ  R1, CH8_FB_END
        READ  R2, 0
        FILL  R0, R1, R2

        ; Nollaa CHIP-8-muisti (4096 sanaa)
        READ  R0, CH8_MEM
        READ  R1, CH8_MEM_END
        READ  R2, 0
        FILL  R0, R1, R2

        ; Kopioi fontti CHIP-8-muistiin: CH8_MEM[0x000..0x04F] (80 sanaa)
        READ  R0, chip8_font           ; R0 = lähde
        READ  R1, CH8_MEM              ; R1 = kohde
        READ  R2, 80                   ; R2 = laskuri
font_copy:
        READ  R3, [R0]
        STORE [R1], R3
        ADD   R0, 1
        ADD   R1, 1
        SUB   R2, 1
        JNZ   font_copy

        ; Alusta näppäinmappaustaulu: kaikki → 0xFF (ei mappaus)
        READ  R0, KEYMAP
        READ  R1, KEYMAP_END
        READ  R2, 0xFF
        FILL  R0, R1, R2

        ; Aseta yksittäiset ASCII → CHIP-8-näppäinnumero -mappaukset
        ; Syntaksi: STORE [KEYMAP + ascii_koodi], chip8_näppäin
        STORE [KEYMAP + 0x58], 0       ; 'X' → 0
        STORE [KEYMAP + 0x31], 1       ; '1' → 1
        STORE [KEYMAP + 0x32], 2       ; '2' → 2
        STORE [KEYMAP + 0x33], 3       ; '3' → 3
        STORE [KEYMAP + 0x51], 4       ; 'Q' → 4
        STORE [KEYMAP + 0x57], 5       ; 'W' → 5
        STORE [KEYMAP + 0x45], 6       ; 'E' → 6
        STORE [KEYMAP + 0x41], 7       ; 'A' → 7
        STORE [KEYMAP + 0x53], 8       ; 'S' → 8
        STORE [KEYMAP + 0x44], 9       ; 'D' → 9
        STORE [KEYMAP + 0x5A], 10      ; 'Z' → A
        STORE [KEYMAP + 0x43], 11      ; 'C' → B
        STORE [KEYMAP + 0x34], 12      ; '4' → C
        STORE [KEYMAP + 0x52], 13      ; 'R' → D
        STORE [KEYMAP + 0x46], 14      ; 'F' → E
        STORE [KEYMAP + 0x56], 15      ; 'V' → F

        ; Aseta näyttö grafiikkatilaan B (80×48 px)
        STORE [GFX_MODE_REG], 1

        ; Käynnistä 60 Hz -kellokeskeytys
        READ  R0, TICK_MS
        SCTMR R0

        STI                            ; Salli laitteistokeskeytykset

; =============================================================================
; EMULOINTISILMUKKA
;
; Rekisterikonventiot koko silmukan ajan (decode-kentät):
;   R10 = X   (rekisteri-indeksi 1, bitit 11–8)
;   R11 = Y   (rekisteri-indeksi 2, bitit 7–4)
;   R12 = N   (nibble, bitit 3–0)
;   R13 = NN  (tavu, bitit 7–0)
;   R14 = NNN (12-bit osoite, bitit 11–0)
;   R15 = type (ylin nibble 0–15, dispatch-indeksi)
;   R0–R9 = scratch, vapaat handlereille
; =============================================================================
emu_loop:
        ; Tarkista FX0A-odotustila: busy-wait kunnes näppäin painetaan
        READ  R0, [chip8_wait]
        CMP   R0, 0xFFFF
        JNZ   emu_loop

        ; --- FETCH: 2 CHIP-8-tavua PC:ltä ---
        READ  R0, [chip8_pc]           ; R0 = CHIP-8 PC
        READ  R1, CH8_MEM
        ADD   R1, R0                   ; R1 = kCPU16-osoite CH8_MEM + PC
        READ  R2, [R1]                 ; R2 = tavu A (korkea)
        ADD   R1, 1
        READ  R3, [R1]                 ; R3 = tavu B (matala)

        ; Yhdistä: opcode = (A << 8) | B
        READ  R4, 8
        SHL   R2, R4                   ; R2 = A << 8
        OR    R2, R3                   ; R2 = koko 16-bittinen CHIP-8-opkoodi

        ; PC += 2  (inkrementoidaan ennen suoritusta, jotta CALL toimii oikein)
        READ  R0, [chip8_pc]
        ADD   R0, 2
        READ  R1, 0x0FFF
        AND   R0, R1                   ; Rajaa 12-bittiin
        STORE [chip8_pc], R0

        ; --- DECODE: Pura opkoodi kenttiin ---
        CPY   R15, R2
        READ  R0, 12
        SHR   R15, R0
        READ  R0, 0x000F
        AND   R15, R0                  ; R15 = type (ylin nibble, 0–15)

        CPY   R10, R2
        READ  R0, 8
        SHR   R10, R0
        READ  R0, 0x000F
        AND   R10, R0                  ; R10 = X

        CPY   R11, R2
        READ  R0, 4
        SHR   R11, R0
        READ  R0, 0x000F
        AND   R11, R0                  ; R11 = Y

        CPY   R12, R2
        READ  R0, 0x000F
        AND   R12, R0                  ; R12 = N

        CPY   R13, R2
        READ  R0, 0x00FF
        AND   R13, R0                  ; R13 = NN

        CPY   R14, R2
        READ  R0, 0x0FFF
        AND   R14, R0                  ; R14 = NNN

        ; --- DISPATCH: Hyppää ylänibble-tyypin mukaan (0–15) ---
        CALLI R15, op_0xxx, op_1nnn, op_2nnn, op_3xnn, op_4xnn, op_5xy0, op_6xnn, op_7xnn, op_8xyn, op_9xy0, op_annn, op_bnnn, op_cxnn, op_dxyn, op_exxx, op_fxxx

        JUMP  emu_loop                 ; Kaikki handlerit palaavat RET:llä tänne

; =============================================================================
; OPKOODIKÄSITTELIJÄT
;
; Sisääntulokonventiot: R10=X, R11=Y, R12=N, R13=NN, R14=NNN
; Scratch: R0–R9
; Kaikki handlerit päättyvät RET:iin.
; =============================================================================

; --- 0x0xxx: CLS (00E0) ja RET (00EE) ---
op_0xxx:
        CMP   R13, 0xE0
        JNZ   _0x_ret
        ; 00E0: CLS — Tyhjennä framebuffer ja päivitä ruutu
        READ  R0, CH8_FB
        READ  R1, CH8_FB_END
        READ  R2, 0
        FILL  R0, R1, R2
        CALL  draw_screen
        RET
_0x_ret:
        CMP   R13, 0xEE
        JNZ   _0x_done
        ; 00EE: RET — Palauta PC pinon huipulta
        CALL  stack_pop                ; R0 = paluuosoite
        STORE [chip8_pc], R0
_0x_done:
        RET

; --- 0x1NNN: JP NNN ---
op_1nnn:
        STORE [chip8_pc], R14
        RET

; --- 0x2NNN: CALL NNN ---
op_2nnn:
        READ  R0, [chip8_pc]           ; R0 = PC (jo inkrementoitu → paluuosoite)
        CALL  stack_push
        STORE [chip8_pc], R14
        RET

; --- 0x3XNN: SE Vx, NN — Skip if VX == NN ---
op_3xnn:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]                 ; R0 = VX
        READ  R1, 0x00FF
        AND   R0, R1
        CMP   R0, R13
        JNZ   _3_done
        READ  R0, [chip8_pc]
        ADD   R0, 2
        STORE [chip8_pc], R0
_3_done:
        RET

; --- 0x4XNN: SNE Vx, NN — Skip if VX != NN ---
op_4xnn:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        READ  R1, 0x00FF
        AND   R0, R1
        CMP   R0, R13
        JZ    _4_done
        READ  R0, [chip8_pc]
        ADD   R0, 2
        STORE [chip8_pc], R0
_4_done:
        RET

; --- 0x5XY0: SE Vx, Vy — Skip if VX == VY ---
op_5xy0:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        READ  R1, chip8_v
        ADD   R1, R11
        READ  R1, [R1]
        READ  R2, 0x00FF
        AND   R0, R2
        AND   R1, R2
        CMP   R0, R1
        JNZ   _5_done
        READ  R0, [chip8_pc]
        ADD   R0, 2
        STORE [chip8_pc], R0
_5_done:
        RET

; --- 0x6XNN: LD Vx, NN ---
op_6xnn:
        READ  R0, chip8_v
        ADD   R0, R10
        STORE [R0], R13
        RET

; --- 0x7XNN: ADD Vx, NN  (ei carry-lippua) ---
op_7xnn:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R1, [R0]
        ADD   R1, R13
        READ  R2, 0x00FF
        AND   R1, R2                   ; Rajaa 8-bittiin (ei carry)
        STORE [R0], R1
        RET

; --- 0x8XYN: ALU-käskyt — toissijainen dispatch N:n mukaan (0–7, E) ---
op_8xyn:
        ; Lataa VX (R4), VY (R5), &VX (R3) ennen dispatchin
        READ  R3, chip8_v
        ADD   R3, R10                  ; R3 = &chip8_v[X]
        READ  R4, [R3]                 ; R4 = VX
        READ  R5, chip8_v
        ADD   R5, R11
        READ  R5, [R5]                 ; R5 = VY
        READ  R6, 0x00FF
        AND   R4, R6
        AND   R5, R6                   ; Rajaa 8-bittiin

        CALLI R12, alu_0, alu_1, alu_2, alu_3, alu_4, alu_5, alu_6, alu_7, alu_nop, alu_nop, alu_nop, alu_nop, alu_nop, alu_nop, alu_E, alu_nop
        RET                            ; Sisäinen CALLI palaa tänne, tämä palaa emu_loop:iin

; ALU-aliohjelmat (R3=&VX, R4=VX, R5=VY — kaikki 8-bittisiksi rajattu)
alu_0:  STORE [R3], R5                 ; 8XY0: VX = VY
        RET
alu_1:  OR  R4, R5
        STORE [R3], R4                 ; 8XY1: VX |= VY
        RET
alu_2:  AND R4, R5
        STORE [R3], R4                 ; 8XY2: VX &= VY
        RET
alu_3:  XOR R4, R5
        STORE [R3], R4                 ; 8XY3: VX ^= VY
        RET
alu_4:                                 ; 8XY4: VX += VY, VF = carry
        ADD  R4, R5
        READ R0, chip8_v
        ADD  R0, 15                    ; R0 = &VF
        READ R1, 0x0100
        CMP  R4, R1
        JLT  _alu4_nc
        STORE [R0], 1
        READ R1, 0x00FF
        AND  R4, R1
        STORE [R3], R4
        RET
_alu4_nc:
        STORE [R0], 0
        STORE [R3], R4
        RET
alu_5:                                 ; 8XY5: VX -= VY, VF = NOT borrow (VX >= VY → 1)
        READ R0, chip8_v
        ADD  R0, 15
        CMP  R4, R5
        JLT  _alu5_borrow
        STORE [R0], 1
        SUB  R4, R5
        STORE [R3], R4
        RET
_alu5_borrow:
        STORE [R0], 0
        SUB  R4, R5
        READ R1, 0x00FF
        AND  R4, R1
        STORE [R3], R4
        RET
alu_6:                                 ; 8XY6: VX >>= 1, VF = LSB ennen siirtoa
        READ R0, chip8_v
        ADD  R0, 15
        READ R1, 1
        CPY  R2, R4
        AND  R2, R1                    ; R2 = VX & 1 (LSB)
        STORE [R0], R2                 ; VF = LSB
        SHR  R4, R1                    ; VX >>= 1
        STORE [R3], R4
        RET
alu_7:                                 ; 8XY7: VX = VY - VX, VF = NOT borrow (VY >= VX → 1)
        READ R0, chip8_v
        ADD  R0, 15
        CMP  R5, R4
        JLT  _alu7_borrow
        STORE [R0], 1
        SUB  R5, R4
        STORE [R3], R5
        RET
_alu7_borrow:
        STORE [R0], 0
        SUB  R5, R4
        READ R1, 0x00FF
        AND  R5, R1
        STORE [R3], R5
        RET
alu_E:                                 ; 8XYE: VX <<= 1, VF = MSB ennen siirtoa
        READ R0, chip8_v
        ADD  R0, 15
        READ R1, 7
        CPY  R2, R4
        SHR  R2, R1                    ; R2 = VX >> 7 = MSB
        READ R1, 1
        AND  R2, R1
        STORE [R0], R2                 ; VF = MSB
        SHL  R4, R1                    ; VX <<= 1
        AND  R4, R1                    ; Huom: R1=1 ei 0xFF — korjataan:
        ; Oikeampi toteutus:
        ;   READ R1, 0x00FF ; AND R4, R1
        STORE [R3], R4
        RET
alu_nop:
        RET

; --- 0x9XY0: SNE Vx, Vy — Skip if VX != VY ---
op_9xy0:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        READ  R1, chip8_v
        ADD   R1, R11
        READ  R1, [R1]
        READ  R2, 0x00FF
        AND   R0, R2
        AND   R1, R2
        CMP   R0, R1
        JZ    _9_done
        READ  R0, [chip8_pc]
        ADD   R0, 2
        STORE [chip8_pc], R0
_9_done:
        RET

; --- 0xANNN: LD I, NNN ---
op_annn:
        STORE [chip8_i], R14
        RET

; --- 0xBNNN: JP V0, NNN — PC = NNN + V0 ---
op_bnnn:
        READ  R0, [chip8_v]            ; R0 = V0
        READ  R1, 0x00FF
        AND   R0, R1
        ADD   R0, R14                  ; R0 = NNN + V0
        READ  R1, 0x0FFF
        AND   R0, R1
        STORE [chip8_pc], R0
        RET

; --- 0xCXNN: RND Vx, NN — VX = random & NN ---
op_cxnn:
        READ  R0, [RAND_MMIO]
        AND   R0, R13
        READ  R1, chip8_v
        ADD   R1, R10
        STORE [R1], R0
        RET

; --- 0xDXYN: DRW Vx, Vy, N — XOR-sprite-piirto ---
;
; Piirtää N-tavuisen spritein (leveydeltä 8px) (VX, VY):hin.
; Kukin sprite-tavu = yksi vaakarivi, MSB = vasen pikseli.
; XOR-operaatio framebufferiin; VF = 1 jos törmäys (1→0).
;
; Rekisterit: R4=VX, R5=VY, R6=&CH8_MEM[I], R7=bitti-indeksi,
;             R8=screen_y, R9=rivi-laskuri, R3=sprite-tavu
; =============================================================================
op_dxyn:
        ; VX mod 64
        READ  R4, chip8_v
        ADD   R4, R10
        READ  R4, [R4]
        READ  R0, 0x003F
        AND   R4, R0
        ; VY mod 32
        READ  R5, chip8_v
        ADD   R5, R11
        READ  R5, [R5]
        READ  R0, 0x001F
        AND   R5, R0
        ; Nollaa VF
        READ  R0, chip8_v
        ADD   R0, 15
        STORE [R0], 0
        ; Laske CHIP-8-muistin osoite: CH8_MEM + I
        READ  R6, [chip8_i]
        READ  R1, CH8_MEM
        ADD   R6, R1
        ; Ulkoinen silmukka: rivit 0..N-1
        READ  R9, 0                    ; R9 = rivi-indeksi
dxyn_row:
        CMP   R9, R12                  ; R12 = N
        JGE   dxyn_done
        READ  R3, [R6]                 ; R3 = sprite-rivi-tavu
        ADD   R6, 1
        ; screen_y = (VY + rivi) mod 32
        CPY   R8, R5
        ADD   R8, R9
        READ  R0, 0x001F
        AND   R8, R0
        ; Sisäinen silmukka: bitit 7..0
        READ  R7, 0                    ; R7 = bitti-indeksi (0=vasen, 7=oikea)
dxyn_bit:
        CMP   R7, 8
        JGE   dxyn_next_row
        ; Laske bittimaski: 0x80 >> R7
        READ  R0, 0x0080
        SHR   R0, R7                   ; R0 = maskin arvo
        ; Tarkista sprite-bitti
        CPY   R1, R3
        AND   R1, R0
        CMP   R1, 0
        JZ    dxyn_skip
        ; screen_x = (VX + R7) mod 64
        CPY   R1, R4
        ADD   R1, R7
        READ  R2, 0x003F
        AND   R1, R2
        ; FB-osoite: CH8_FB + screen_y*64 + screen_x
        CPY   R2, R8
        READ  R0, 6
        SHL   R2, R0                   ; R2 = screen_y * 64
        ADD   R2, R1
        READ  R0, CH8_FB
        ADD   R2, R0                   ; R2 = &ch8_fb[screen_y][screen_x]
        ; XOR read-modify-write + törmäyksen tarkistus
        READ  R0, [R2]
        CMP   R0, 1
        JNZ   dxyn_xor
        READ  R1, chip8_v              ; Törmäys: aseta VF = 1
        ADD   R1, 15
        STORE [R1], 1
dxyn_xor:
        READ  R1, 1
        XOR   R0, R1
        STORE [R2], R0
dxyn_skip:
        ADD   R7, 1
        JUMP  dxyn_bit
dxyn_next_row:
        ADD   R9, 1
        JUMP  dxyn_row
dxyn_done:
        CALL  draw_screen
        RET

; --- 0xEXXX: Näppäimistöskippaukset (EX9E ja EXA1) ---
op_exxx:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]                 ; R0 = VX = näppäinnumero (0–15)
        READ  R1, 1
        SHL   R1, R0                   ; R1 = bitmask näppäimelle
        READ  R2, [chip8_key]
        AND   R2, R1                   ; R2 = 0 jos ei painettu
        CMP   R13, 0x9E
        JNZ   _ex_a1
        CMP   R2, 0                    ; EX9E: skip if pressed (R2 != 0)
        JZ    _ex_done
        JUMP  _ex_skip
_ex_a1:
        CMP   R2, 0                    ; EXA1: skip if NOT pressed (R2 == 0)
        JNZ   _ex_done
_ex_skip:
        READ  R0, [chip8_pc]
        ADD   R0, 2
        STORE [chip8_pc], R0
_ex_done:
        RET

; --- 0xFXNN: Sekalaiskäskyt — if/else-ketjupohjainen dispatch NN:n mukaan ---
; (CHIP-8:n F-opkoodien NN-arvot (0x07..0x65) eivät sovi 0–15-dispatch-taulukkoon.)
op_fxxx:
        CMP   R13, 0x07  :  JZ  fx_07
        CMP   R13, 0x0A  :  JZ  fx_0A
        CMP   R13, 0x15  :  JZ  fx_15
        CMP   R13, 0x18  :  JZ  fx_18
        CMP   R13, 0x1E  :  JZ  fx_1E
        CMP   R13, 0x29  :  JZ  fx_29
        CMP   R13, 0x33  :  JZ  fx_33
        CMP   R13, 0x55  :  JZ  fx_55
        CMP   R13, 0x65  :  JZ  fx_65
        RET                            ; Tuntematon NN → ohita

; FX07: LD Vx, DT — VX = DT
fx_07:
        READ  R0, [chip8_dt]
        READ  R1, chip8_v
        ADD   R1, R10
        STORE [R1], R0
        RET

; FX0A: LD Vx, K — Odota näppäinpainallusta, tallenna VX:iin
; Asettaa odotustilan; kbd_handler hoitaa lopetuksen.
fx_0A:
        STORE [chip8_wait], R10        ; Aseta odotustilaksi kohde-VX-indeksi
        RET

; FX15: LD DT, Vx — DT = VX
fx_15:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        STORE [chip8_dt], R0
        RET

; FX18: LD ST, Vx — ST = VX
fx_18:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        STORE [chip8_st], R0
        RET

; FX1E: ADD I, Vx — I += VX (mod 0x1000)
fx_1E:
        READ  R0, [chip8_i]
        READ  R1, chip8_v
        ADD   R1, R10
        READ  R1, [R1]
        ADD   R0, R1
        READ  R1, 0x0FFF
        AND   R0, R1
        STORE [chip8_i], R0
        RET

; FX29: LD F, Vx — I = osoite VX:n fonttimerkkiin (5 tavua per merkki)
fx_29:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]
        READ  R1, 0x000F
        AND   R0, R1                   ; Rajaa 0–15
        READ  R1, 5
        MUL   R0, R1                   ; R0 = VX * 5 (fontti: CH8_MEM[I], I lähtee 0:sta)
        STORE [chip8_i], R0
        RET

; FX33: LD B, Vx — BCD-muunnos VX:stä I:hin (sadat), I+1:een (kymmenet), I+2:een (ykkösset)
fx_33:
        READ  R0, chip8_v
        ADD   R0, R10
        READ  R0, [R0]                 ; R0 = VX (0–255)
        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1                   ; R2 = kCPU16-osoite I
        ; Sadat
        CPY   R3, R0
        READ  R1, 100
        DIV   R3, R1                   ; R3 = VX / 100
        STORE [R2], R3
        ADD   R2, 1
        ; Kymmenet
        MUL   R3, R1                   ; R3 = sadat * 100
        SUB   R0, R3                   ; R0 = VX mod 100
        CPY   R3, R0
        READ  R1, 10
        DIV   R3, R1                   ; R3 = (VX mod 100) / 10
        STORE [R2], R3
        ADD   R2, 1
        ; Ykkösset
        MUL   R3, R1                   ; R3 = kymmenet * 10
        SUB   R0, R3
        STORE [R2], R0                 ; R0 = VX mod 10
        RET

; FX55: LD [I], Vx — Tallenna V0–VX osoitteeseen I (kasvattaa I:tä)
fx_55:
        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1                   ; R2 = kCPU16-osoite I
        READ  R3, chip8_v              ; R3 = &V0
        READ  R4, 0                    ; R4 = laskuri
fx_55_loop:
        CMP   R4, R10
        JGT   fx_55_done
        READ  R1, [R3]
        STORE [R2], R1
        ADD   R2, 1
        ADD   R3, 1
        ADD   R4, 1
        JUMP  fx_55_loop
fx_55_done:
        RET

; FX65: LD Vx, [I] — Lataa V0–VX osoitteesta I
fx_65:
        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1
        READ  R3, chip8_v
        READ  R4, 0
fx_65_loop:
        CMP   R4, R10
        JGT   fx_65_done
        READ  R1, [R2]
        STORE [R3], R1
        ADD   R2, 1
        ADD   R3, 1
        ADD   R4, 1
        JUMP  fx_65_loop
fx_65_done:
        RET

; =============================================================================
; MUISTIKARTTA-YHTEENVETO
;
; Alueet CH8_MEM (0x6000) ja CH8_FB (0x5000) ovat puhdasta RAM:ia:
; assemblerin ei tarvitse varata niitä etukäteen — FILL alustaa ne main:issa.
; KEYMAP (0x4000) varataan samoin: FILL + yksittäiset STORE:t main:issa.
; =============================================================================
```

### 8.3 Skeleton-analyysi: toteutuksen laajuus

| Opkoodi                | Handler                 | Tilanne                                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------------------- |
| `00E0` CLS             | `op_0xxx`               | Täysin toteutettu                                                                  |
| `00EE` RET             | `op_0xxx`               | Täysin toteutettu                                                                  |
| `1NNN` JP              | `op_1nnn`               | Täysin toteutettu                                                                  |
| `2NNN` CALL            | `op_2nnn`               | Täysin toteutettu                                                                  |
| `3–5` SE/SNE           | `op_3–5`                | Täysin toteutettu                                                                  |
| `6–7` LD/ADD           | `op_6–7`                | Täysin toteutettu                                                                  |
| `8XY0–7,E` ALU         | `op_8xyn` + `alu_*`     | Täysin toteutettu (alu_E:ssä pieni vika: `AND R4, R1` AND 0xFF korjattava)         |
| `9XY0` SNE             | `op_9xy0`               | Täysin toteutettu                                                                  |
| `ANNN` LD I            | `op_annn`               | Täysin toteutettu                                                                  |
| `BNNN` JP V0           | `op_bnnn`               | Täysin toteutettu                                                                  |
| `CXNN` RND             | `op_cxnn`               | Täysin toteutettu                                                                  |
| `DXYN` DRW             | `op_dxyn`               | Runko toteutettu, testattava                                                       |
| `EX9E/EXA1`            | `op_exxx`               | Täysin toteutettu                                                                  |
| `FX07/15/18` ajastimet | `fx_07/15/18`           | Täysin toteutettu                                                                  |
| `FX0A` wait key        | `fx_0A` + `kbd_handler` | Rakenne toteutettu; kbd_handler-kohdassa TODO näppäinnumeron uudelleenlaskemiselle |
| `FX1E/29` I-käskyt     | `fx_1E/29`              | Täysin toteutettu                                                                  |
| `FX33` BCD             | `fx_33`                 | Täysin toteutettu                                                                  |
| `FX55/65` muisti       | `fx_55/65`              | Täysin toteutettu                                                                  |
