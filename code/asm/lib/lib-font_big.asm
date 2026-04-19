; =============================================================================
; font_big.asm — BIG-fonttidata
; =============================================================================
;
; Kuvaa BIG-nimisen pikseleistä koostuvan näyttöfontin.
; Jokainen merkki on 6×8 pikselimatriisi:
;   - oikeanpuoleisin sarake (sarake 5) on aina tyhjä
;   - alin rivi (rivi 7) on aina tyhjä
;   => tehollinen pikseliala 5×7 (sarakkeet 0–4, rivit 0–6)
;
; FORMAATTI — 8 tavua per merkki, yksi tavu per rivi:
;
;   Tavu 0:  rivi 0   (6 bittiä, bitit 7–2 tai 5–0 riippuen käytöstä)
;   Tavu 1:  rivi 1
;   ...
;   Tavu 7:  rivi 7   (aina 0 — alin rivi tyhjä)
;
; RIVITAVU (6 merkitsevää bittiä):
;   bitti 5 = sarake 0 (vasen)      1 = pikseli päällä
;   bitti 4 = sarake 1              0 = pikseli pois
;   bitti 3 = sarake 2
;   bitti 2 = sarake 3
;   bitti 1 = sarake 4
;   bitti 0 = sarake 5 (oikea) — aina 0
;
; PERUSGLYPHIT BIG_FONT-taulussa (indeksit 0–21):
;   0–9  = numerot '0'–'9'
;   10   = ':' (kaksoispiste)
;   11   = '.' (piste)
;   12   = ' ' (välilyönti)
;   13–18 = kirjaimet 'A'–'F'
;   19   = Ä / ä
;   20   = Ö / ö
;   21   = Å / å
;
; Muiden tavuarvojen 0x00–0xFF glyphit muodostetaan ajonaikaisesti apurilla
; font_big_get_glyph:
;   - ASCII-tulostettavat merkit 0x20..0x7E piirretään 3x5 mikrofontista
;     skaalattuna 5x7-alueelle.
;   - Ohjausmerkit ja muut ei-tulostettavat tavut piirretään kaksimerkkisinä
;     symbolisina lyhenteinä, jotka perustuvat ASCII/C1-nimiin.
;   - Latin-1-alueen 0xA0..0xFF tavut mapataan joko mikrofonttiin,
;     symboliseen pariin tai yllä oleviin skandiglypheihin.
;
; KÄYTTÖ PIIRTOKOODISSA:
;   osoite     = BIG_FONT + merkki_indeksi * BIG_WORDS_PER_CHAR
;   for rivi_i in 0..7:
;     rivibitti = MEM[osoite + rivi_i]
;     for sarake in 0..5:
;       bitti = (rivibitti >> (5 - sarake)) & 1
;       jos bitti: piirrä PIXEL_ON sarakeelle sarake
;       muuten:    piirrä PIXEL_OFF
;
; PIKSELIKOMMENTIT:
;   Kuusi merkkiä sarake 0..5: X=pikseli päällä, .=pois
;   Esim. ".XXX.." tarkoittaa sarak. 0=. 1=X 2=X 3=X 4=. 5=. (aina tyhjä)
;
; =============================================================================

.const BIG_CHAR_W,        6  ; pikseleitä per merkki vaakasuunnassa
.const BIG_CHAR_H,        8  ; pikseleitä per merkki pystysuunnassa
.const BIG_WORDS_PER_CHAR, 8  ; muistisanoja (tavua) per merkki

BIG_FONT:

    ; -----------------------------------------------------------------------
    ; Merkki 0: '0'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: X...X.
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......  (aina tyhjä)
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX.. = 0b011100
    .db 0x22   ; r1: X...X. = 0b100010
    .db 0x22   ; r2: X...X.
    .db 0x22   ; r3: X...X.
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 1: '1'       sarake: 012345
    ;                   0: ..X...
    ;                   1: .XX...
    ;                   2: ..X...
    ;                   3: ..X...
    ;                   4: ..X...
    ;                   5: ..X...
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x08   ; r0: ..X... = 0b001000
    .db 0x18   ; r1: .XX... = 0b011000
    .db 0x08   ; r2: ..X...
    .db 0x08   ; r3: ..X...
    .db 0x08   ; r4: ..X...
    .db 0x08   ; r5: ..X...
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 2: '2'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: ....X.
    ;                   3: ...X..
    ;                   4: ..X...
    ;                   5: .X....
    ;                   6: XXXXX.
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX.. = 0b011100
    .db 0x22   ; r1: X...X. = 0b100010
    .db 0x02   ; r2: ....X. = 0b000010
    .db 0x04   ; r3: ...X.. = 0b000100
    .db 0x08   ; r4: ..X... = 0b001000
    .db 0x10   ; r5: .X.... = 0b010000
    .db 0x3E   ; r6: XXXXX. = 0b111110
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 3: '3'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: ....X.
    ;                   3: ..XX..
    ;                   4: ....X.
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x22   ; r1: X...X.
    .db 0x02   ; r2: ....X.
    .db 0x0C   ; r3: ..XX.. = 0b001100
    .db 0x02   ; r4: ....X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 4: '4'       sarake: 012345
    ;                   0: ...X..
    ;                   1: ..XX..
    ;                   2: .X.X..
    ;                   3: X..X..
    ;                   4: XXXXX.
    ;                   5: ...X..
    ;                   6: ...X..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x04   ; r0: ...X.. = 0b000100
    .db 0x0C   ; r1: ..XX.. = 0b001100
    .db 0x14   ; r2: .X.X.. = 0b010100
    .db 0x24   ; r3: X..X.. = 0b100100
    .db 0x3E   ; r4: XXXXX.
    .db 0x04   ; r5: ...X..
    .db 0x04   ; r6: ...X..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 5: '5'       sarake: 012345
    ;                   0: XXXXX.
    ;                   1: X.....
    ;                   2: XXXX..
    ;                   3: ....X.
    ;                   4: ....X.
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3E   ; r0: XXXXX.
    .db 0x20   ; r1: X..... = 0b100000
    .db 0x3C   ; r2: XXXX.. = 0b111100
    .db 0x02   ; r3: ....X.
    .db 0x02   ; r4: ....X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 6: '6'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X.....
    ;                   2: X.....
    ;                   3: XXXX..
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x20   ; r1: X.....
    .db 0x20   ; r2: X.....
    .db 0x3C   ; r3: XXXX..
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 7: '7'       sarake: 012345
    ;                   0: XXXXX.
    ;                   1: ....X.
    ;                   2: ...X..
    ;                   3: ...X..
    ;                   4: ..X...
    ;                   5: ..X...
    ;                   6: ..X...
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3E   ; r0: XXXXX.
    .db 0x02   ; r1: ....X.
    .db 0x04   ; r2: ...X..
    .db 0x04   ; r3: ...X..
    .db 0x08   ; r4: ..X...
    .db 0x08   ; r5: ..X...
    .db 0x08   ; r6: ..X...
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 8: '8'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: .XXX..
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x22   ; r1: X...X.
    .db 0x22   ; r2: X...X.
    .db 0x1C   ; r3: .XXX..
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 9: '9'       sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: .XXXX.
    ;                   4: ....X.
    ;                   5: ....X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x22   ; r1: X...X.
    .db 0x22   ; r2: X...X.
    .db 0x1E   ; r3: .XXXX. = 0b011110
    .db 0x02   ; r4: ....X.
    .db 0x02   ; r5: ....X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 10: ':'      sarake: 012345
    ;                   0: ......
    ;                   1: ..X...
    ;                   2: ..X...
    ;                   3: ......
    ;                   4: ..X...
    ;                   5: ..X...
    ;                   6: ......
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x00   ; r0: ......
    .db 0x08   ; r1: ..X... = 0b001000
    .db 0x08   ; r2: ..X...
    .db 0x00   ; r3: ......
    .db 0x08   ; r4: ..X...
    .db 0x08   ; r5: ..X...
    .db 0x00   ; r6: ......
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 11: '.'      sarake: 012345
    ;                   0: ......
    ;                   1: ......
    ;                   2: ......
    ;                   3: ......
    ;                   4: ......
    ;                   5: ..XX..
    ;                   6: ..XX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x00   ; r0: ......
    .db 0x00   ; r1: ......
    .db 0x00   ; r2: ......
    .db 0x00   ; r3: ......
    .db 0x00   ; r4: ......
    .db 0x0C   ; r5: ..XX.. = 0b001100
    .db 0x0C   ; r6: ..XX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 12: ' '      (välilyönti — kaikki tyhjää)
    ; -----------------------------------------------------------------------
    .db 0x00   ; r0: ......
    .db 0x00   ; r1: ......
    .db 0x00   ; r2: ......
    .db 0x00   ; r3: ......
    .db 0x00   ; r4: ......
    .db 0x00   ; r5: ......
    .db 0x00   ; r6: ......
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 13: 'A'      sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: XXXXX.
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: X...X.
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x22   ; r1: X...X.
    .db 0x22   ; r2: X...X.
    .db 0x3E   ; r3: XXXXX.
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x22   ; r6: X...X.
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 14: 'B'      sarake: 012345
    ;                   0: XXXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: XXXX..
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: XXXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3C   ; r0: XXXX..
    .db 0x22   ; r1: X...X.
    .db 0x22   ; r2: X...X.
    .db 0x3C   ; r3: XXXX..
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x3C   ; r6: XXXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 15: 'C'      sarake: 012345
    ;                   0: .XXX..
    ;                   1: X...X.
    ;                   2: X.....
    ;                   3: X.....
    ;                   4: X.....
    ;                   5: X...X.
    ;                   6: .XXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x1C   ; r0: .XXX..
    .db 0x22   ; r1: X...X.
    .db 0x20   ; r2: X.....
    .db 0x20   ; r3: X.....
    .db 0x20   ; r4: X.....
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 16: 'D'      sarake: 012345
    ;                   0: XXXX..
    ;                   1: X...X.
    ;                   2: X...X.
    ;                   3: X...X.
    ;                   4: X...X.
    ;                   5: X...X.
    ;                   6: XXXX..
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3C   ; r0: XXXX..
    .db 0x22   ; r1: X...X.
    .db 0x22   ; r2: X...X.
    .db 0x22   ; r3: X...X.
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x3C   ; r6: XXXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 17: 'E'      sarake: 012345
    ;                   0: XXXXX.
    ;                   1: X.....
    ;                   2: X.....
    ;                   3: XXXX..
    ;                   4: X.....
    ;                   5: X.....
    ;                   6: XXXXX.
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3E   ; r0: XXXXX.
    .db 0x20   ; r1: X.....
    .db 0x20   ; r2: X.....
    .db 0x3C   ; r3: XXXX..
    .db 0x20   ; r4: X.....
    .db 0x20   ; r5: X.....
    .db 0x3E   ; r6: XXXXX.
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 18: 'F'      sarake: 012345
    ;                   0: XXXXX.
    ;                   1: X.....
    ;                   2: X.....
    ;                   3: XXXX..
    ;                   4: X.....
    ;                   5: X.....
    ;                   6: X.....
    ;                   7: ......
    ; -----------------------------------------------------------------------
    .db 0x3E   ; r0: XXXXX.
    .db 0x20   ; r1: X.....
    .db 0x20   ; r2: X.....
    .db 0x3C   ; r3: XXXX..
    .db 0x20   ; r4: X.....
    .db 0x20   ; r5: X.....
    .db 0x20   ; r6: X.....
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 19: 'Ä' / 'ä' sarake: 012345
    ; -----------------------------------------------------------------------
    .db 0x2A   ; r0: X.X.X.
    .db 0x1C   ; r1: .XXX..
    .db 0x22   ; r2: X...X.
    .db 0x3E   ; r3: XXXXX.
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x22   ; r6: X...X.
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 20: 'Ö' / 'ö' sarake: 012345
    ; -----------------------------------------------------------------------
    .db 0x2A   ; r0: X.X.X.
    .db 0x1C   ; r1: .XXX..
    .db 0x22   ; r2: X...X.
    .db 0x22   ; r3: X...X.
    .db 0x22   ; r4: X...X.
    .db 0x22   ; r5: X...X.
    .db 0x1C   ; r6: .XXX..
    .db 0x00   ; r7: ......

    ; -----------------------------------------------------------------------
    ; Merkki 21: 'Å' / 'å' sarake: 012345
    ; -----------------------------------------------------------------------
    .db 0x10   ; r0: .X....
    .db 0x28   ; r1: X.X...
    .db 0x1C   ; r2: .XXX..
    .db 0x22   ; r3: X...X.
    .db 0x3E   ; r4: XXXXX.
    .db 0x22   ; r5: X...X.
    .db 0x22   ; r6: X...X.
    .db 0x00   ; r7: ......

BIG_FONT_END:

.const FONT_BIG_KIND_SINGLE, 0
.const FONT_BIG_KIND_PAIR,   1
.const FONT_BIG_KIND_BIG,    2

font_big_scratch_glyph:
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

font_big_expand_row_map:
    .db 0x00, 0x01, 0x01, 0x02, 0x03, 0x03, 0x04

font_big_expand_col_map:
    .db 0x00, 0x01, 0x01, 0x02, 0x02

font_big_micro_font:
    ; MICRO FONT 0x20..0x7E
    .db 0x00, 0x00, 0x00, 0x00, 0x00   ; 0x20
    .db 0x02, 0x02, 0x02, 0x00, 0x02   ; 0x21 !
    .db 0x05, 0x05, 0x00, 0x00, 0x00   ; 0x22 "
    .db 0x05, 0x07, 0x05, 0x07, 0x05   ; 0x23 #
    .db 0x02, 0x06, 0x07, 0x03, 0x02   ; 0x24 $
    .db 0x05, 0x01, 0x02, 0x04, 0x05   ; 0x25 %
    .db 0x02, 0x04, 0x03, 0x05, 0x03   ; 0x26 &
    .db 0x02, 0x02, 0x00, 0x00, 0x00   ; 0x27 '
    .db 0x01, 0x02, 0x02, 0x02, 0x01   ; 0x28 (
    .db 0x04, 0x02, 0x02, 0x02, 0x04   ; 0x29 )
    .db 0x00, 0x05, 0x02, 0x05, 0x00   ; 0x2A *
    .db 0x00, 0x02, 0x07, 0x02, 0x00   ; 0x2B +
    .db 0x00, 0x00, 0x00, 0x02, 0x04   ; 0x2C ,
    .db 0x00, 0x00, 0x07, 0x00, 0x00   ; 0x2D -
    .db 0x00, 0x00, 0x00, 0x00, 0x02   ; 0x2E .
    .db 0x01, 0x01, 0x02, 0x04, 0x04   ; 0x2F /
    .db 0x07, 0x05, 0x05, 0x05, 0x07   ; 0x30 0
    .db 0x02, 0x06, 0x02, 0x02, 0x07   ; 0x31 1
    .db 0x07, 0x01, 0x07, 0x04, 0x07   ; 0x32 2
    .db 0x07, 0x01, 0x07, 0x01, 0x07   ; 0x33 3
    .db 0x05, 0x05, 0x07, 0x01, 0x01   ; 0x34 4
    .db 0x07, 0x04, 0x07, 0x01, 0x07   ; 0x35 5
    .db 0x07, 0x04, 0x07, 0x05, 0x07   ; 0x36 6
    .db 0x07, 0x01, 0x02, 0x02, 0x02   ; 0x37 7
    .db 0x07, 0x05, 0x07, 0x05, 0x07   ; 0x38 8
    .db 0x07, 0x05, 0x07, 0x01, 0x07   ; 0x39 9
    .db 0x00, 0x02, 0x00, 0x02, 0x00   ; 0x3A :
    .db 0x00, 0x02, 0x00, 0x02, 0x04   ; 0x3B ;
    .db 0x01, 0x02, 0x04, 0x02, 0x01   ; 0x3C <
    .db 0x00, 0x07, 0x00, 0x07, 0x00   ; 0x3D =
    .db 0x04, 0x02, 0x01, 0x02, 0x04   ; 0x3E >
    .db 0x07, 0x01, 0x02, 0x00, 0x02   ; 0x3F ?
    .db 0x07, 0x05, 0x07, 0x04, 0x03   ; 0x40 @
    .db 0x02, 0x05, 0x07, 0x05, 0x05   ; 0x41 A
    .db 0x06, 0x05, 0x06, 0x05, 0x06   ; 0x42 B
    .db 0x03, 0x04, 0x04, 0x04, 0x03   ; 0x43 C
    .db 0x06, 0x05, 0x05, 0x05, 0x06   ; 0x44 D
    .db 0x07, 0x04, 0x06, 0x04, 0x07   ; 0x45 E
    .db 0x07, 0x04, 0x06, 0x04, 0x04   ; 0x46 F
    .db 0x03, 0x04, 0x05, 0x05, 0x03   ; 0x47 G
    .db 0x05, 0x05, 0x07, 0x05, 0x05   ; 0x48 H
    .db 0x07, 0x02, 0x02, 0x02, 0x07   ; 0x49 I
    .db 0x01, 0x01, 0x01, 0x05, 0x02   ; 0x4A J
    .db 0x05, 0x05, 0x06, 0x05, 0x05   ; 0x4B K
    .db 0x04, 0x04, 0x04, 0x04, 0x07   ; 0x4C L
    .db 0x05, 0x07, 0x07, 0x05, 0x05   ; 0x4D M
    .db 0x05, 0x07, 0x07, 0x07, 0x05   ; 0x4E N
    .db 0x07, 0x05, 0x05, 0x05, 0x07   ; 0x4F O
    .db 0x07, 0x05, 0x07, 0x04, 0x04   ; 0x50 P
    .db 0x07, 0x05, 0x05, 0x07, 0x01   ; 0x51 Q
    .db 0x06, 0x05, 0x06, 0x05, 0x05   ; 0x52 R
    .db 0x03, 0x04, 0x02, 0x01, 0x06   ; 0x53 S
    .db 0x07, 0x02, 0x02, 0x02, 0x02   ; 0x54 T
    .db 0x05, 0x05, 0x05, 0x05, 0x07   ; 0x55 U
    .db 0x05, 0x05, 0x05, 0x05, 0x02   ; 0x56 V
    .db 0x05, 0x05, 0x07, 0x07, 0x05   ; 0x57 W
    .db 0x05, 0x05, 0x02, 0x05, 0x05   ; 0x58 X
    .db 0x05, 0x05, 0x02, 0x02, 0x02   ; 0x59 Y
    .db 0x07, 0x01, 0x02, 0x04, 0x07   ; 0x5A Z
    .db 0x06, 0x04, 0x04, 0x04, 0x06   ; 0x5B [
    .db 0x04, 0x04, 0x02, 0x01, 0x01   ; 0x5C \
    .db 0x03, 0x01, 0x01, 0x01, 0x03   ; 0x5D ]
    .db 0x02, 0x05, 0x00, 0x00, 0x00   ; 0x5E ^
    .db 0x00, 0x00, 0x00, 0x00, 0x07   ; 0x5F _
    .db 0x04, 0x02, 0x00, 0x00, 0x00   ; 0x60 `
    .db 0x02, 0x05, 0x07, 0x05, 0x05   ; 0x61 a
    .db 0x06, 0x05, 0x06, 0x05, 0x06   ; 0x62 b
    .db 0x03, 0x04, 0x04, 0x04, 0x03   ; 0x63 c
    .db 0x06, 0x05, 0x05, 0x05, 0x06   ; 0x64 d
    .db 0x07, 0x04, 0x06, 0x04, 0x07   ; 0x65 e
    .db 0x07, 0x04, 0x06, 0x04, 0x04   ; 0x66 f
    .db 0x03, 0x04, 0x05, 0x05, 0x03   ; 0x67 g
    .db 0x05, 0x05, 0x07, 0x05, 0x05   ; 0x68 h
    .db 0x07, 0x02, 0x02, 0x02, 0x07   ; 0x69 i
    .db 0x01, 0x01, 0x01, 0x05, 0x02   ; 0x6A j
    .db 0x05, 0x05, 0x06, 0x05, 0x05   ; 0x6B k
    .db 0x04, 0x04, 0x04, 0x04, 0x07   ; 0x6C l
    .db 0x05, 0x07, 0x07, 0x05, 0x05   ; 0x6D m
    .db 0x05, 0x07, 0x07, 0x07, 0x05   ; 0x6E n
    .db 0x07, 0x05, 0x05, 0x05, 0x07   ; 0x6F o
    .db 0x07, 0x05, 0x07, 0x04, 0x04   ; 0x70 p
    .db 0x07, 0x05, 0x05, 0x07, 0x01   ; 0x71 q
    .db 0x06, 0x05, 0x06, 0x05, 0x05   ; 0x72 r
    .db 0x03, 0x04, 0x02, 0x01, 0x06   ; 0x73 s
    .db 0x07, 0x02, 0x02, 0x02, 0x02   ; 0x74 t
    .db 0x05, 0x05, 0x05, 0x05, 0x07   ; 0x75 u
    .db 0x05, 0x05, 0x05, 0x05, 0x02   ; 0x76 v
    .db 0x05, 0x05, 0x07, 0x07, 0x05   ; 0x77 w
    .db 0x05, 0x05, 0x02, 0x05, 0x05   ; 0x78 x
    .db 0x05, 0x05, 0x02, 0x02, 0x02   ; 0x79 y
    .db 0x07, 0x01, 0x02, 0x04, 0x07   ; 0x7A z
    .db 0x03, 0x02, 0x06, 0x02, 0x03   ; 0x7B {
    .db 0x02, 0x02, 0x02, 0x02, 0x02   ; 0x7C |
    .db 0x06, 0x02, 0x03, 0x02, 0x06   ; 0x7D }
    .db 0x00, 0x03, 0x06, 0x00, 0x00   ; 0x7E ~

font_big_ctrl_c0_pair_a:
    .db 0x4E, 0x53, 0x53, 0x45, 0x45, 0x45, 0x41, 0x42, 0x42, 0x48, 0x4C, 0x56, 0x46, 0x43, 0x53, 0x53
    .db 0x44, 0x44, 0x44, 0x44, 0x44, 0x4E, 0x53, 0x45, 0x43, 0x45, 0x53, 0x45, 0x46, 0x47, 0x52, 0x55

font_big_ctrl_c0_pair_b:
    .db 0x30, 0x48, 0x58, 0x58, 0x4F, 0x4E, 0x4B, 0x4C, 0x53, 0x54, 0x46, 0x54, 0x46, 0x52, 0x4F, 0x49
    .db 0x30, 0x31, 0x32, 0x33, 0x34, 0x4B, 0x59, 0x42, 0x4E, 0x4D, 0x42, 0x53, 0x53, 0x53, 0x53, 0x53

font_big_ctrl_c1_pair_a:
    .db 0x50, 0x48, 0x42, 0x4E, 0x49, 0x4E, 0x53, 0x45, 0x48, 0x48, 0x56, 0x50, 0x50, 0x52, 0x53, 0x53
    .db 0x44, 0x50, 0x50, 0x53, 0x43, 0x4D, 0x53, 0x45, 0x4F, 0x53, 0x53, 0x43, 0x53, 0x4F, 0x50, 0x41

font_big_ctrl_c1_pair_b:
    .db 0x41, 0x4F, 0x50, 0x42, 0x4E, 0x45, 0x41, 0x41, 0x53, 0x4A, 0x53, 0x44, 0x55, 0x49, 0x32, 0x33
    .db 0x43, 0x31, 0x32, 0x54, 0x48, 0x57, 0x50, 0x50, 0x53, 0x47, 0x43, 0x53, 0x54, 0x43, 0x4D, 0x50

font_big_latin1_kind:
    .db 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x02, 0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01
    .db 0x00, 0x00, 0x00, 0x00, 0x02, 0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00

font_big_latin1_code_a:
    .db 0x4E, 0x21, 0x43, 0x4C, 0x24, 0x59, 0x7C, 0x53, 0x22, 0x43, 0x41, 0x3C, 0x2D, 0x53, 0x52, 0x2D
    .db 0x4F, 0x2B, 0x32, 0x33, 0x27, 0x55, 0x50, 0x2E, 0x2C, 0x31, 0x4F, 0x3E, 0x31, 0x31, 0x33, 0x3F
    .db 0x41, 0x41, 0x41, 0x41, 0x13, 0x15, 0x41, 0x43, 0x45, 0x45, 0x45, 0x45, 0x49, 0x49, 0x49, 0x49
    .db 0x44, 0x4E, 0x4F, 0x4F, 0x4F, 0x4F, 0x14, 0x58, 0x4F, 0x55, 0x55, 0x55, 0x55, 0x59, 0x54, 0x53
    .db 0x61, 0x61, 0x61, 0x61, 0x13, 0x15, 0x41, 0x63, 0x65, 0x65, 0x65, 0x65, 0x69, 0x69, 0x69, 0x69
    .db 0x64, 0x6E, 0x6F, 0x6F, 0x6F, 0x6F, 0x14, 0x2F, 0x4F, 0x75, 0x75, 0x75, 0x75, 0x79, 0x54, 0x79

font_big_latin1_code_b:
    .db 0x42, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x48, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34, 0x32, 0x34, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x48, 0x53
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x48, 0x00

_font_big_get_ptr_from_idx:
    READ R1, BIG_WORDS_PER_CHAR
    MUL  R0, R1
    READ R1, BIG_FONT
    ADD  R0, R1
    READ R1, 1
    RET

_font_big_clear_scratch:
    READ R0, font_big_scratch_glyph
    CPY  R1, R0
    READ R2, 7
    ADD  R1, R2
    READ R2, 0
    FILL R0, R1, R2
    RET

_font_big_get_micro_ptr:
    READ R1, 0x20
    CMP  R0, R1
    JLT  _fbgmp_fallback
    READ R1, 0x7E
    CMP  R0, R1
    JGT  _fbgmp_fallback
_fbgmp_compute:
    READ R1, 0x20
    SUB  R0, R1
    READ R1, 5
    MUL  R0, R1
    READ R1, font_big_micro_font
    ADD  R0, R1
    RET
_fbgmp_fallback:
    READ R0, 0x3F
    JUMP _fbgmp_compute

_font_big_build_single:
    CPY  R13, R0
    CALL _font_big_clear_scratch
    CPY  R0, R13
    CALL _font_big_get_micro_ptr
    CPY  R11, R0
    READ R10, 0
_fbgs_row:
    READ R0, 7
    CMP  R10, R0
    JGE  _fbgs_done
    READ R0, font_big_expand_row_map
    ADD  R0, R10
    READ R9, [R0]
    CPY  R0, R11
    ADD  R0, R9
    READ R8, [R0]
    READ R7, 0
    READ R6, 0
_fbgs_col:
    READ R0, 5
    CMP  R6, R0
    JGE  _fbgs_store
    READ R0, font_big_expand_col_map
    ADD  R0, R6
    READ R5, [R0]
    READ R0, 2
    SUB  R0, R5
    CPY  R1, R8
    SHR  R1, R0
    READ R0, 1
    AND  R1, R0
    READ R0, 0
    CMP  R1, R0
    JZ   _fbgs_inc_col
    READ R0, 5
    SUB  R0, R6
    READ R1, 1
    SHL  R1, R0
    OR   R7, R1
_fbgs_inc_col:
    READ R0, 1
    ADD  R6, R0
    JUMP _fbgs_col
_fbgs_store:
    READ R0, font_big_scratch_glyph
    ADD  R0, R10
    STORE [R0], R7
    READ R0, 1
    ADD  R10, R0
    JUMP _fbgs_row
_fbgs_done:
    READ R0, font_big_scratch_glyph
    READ R1, 1
    RET

_font_big_build_pair:
    CPY  R13, R0
    CPY  R14, R1
    CALL _font_big_clear_scratch
    CPY  R0, R13
    CALL _font_big_get_micro_ptr
    CPY  R11, R0
    CPY  R0, R14
    CALL _font_big_get_micro_ptr
    CPY  R12, R0
    READ R10, 0
_fbgp_row:
    READ R0, 5
    CMP  R10, R0
    JGE  _fbgp_done
    CPY  R0, R11
    ADD  R0, R10
    READ R8, [R0]
    CPY  R0, R12
    ADD  R0, R10
    READ R9, [R0]
    CPY  R7, R8
    READ R0, 3
    SHL  R7, R0
    OR   R7, R9
    READ R0, font_big_scratch_glyph
    READ R1, 1
    ADD  R1, R10
    ADD  R0, R1
    STORE [R0], R7
    READ R0, 1
    ADD  R10, R0
    JUMP _fbgp_row
_fbgp_done:
    READ R0, font_big_scratch_glyph
    READ R1, 1
    RET

_font_big_build_latin1:
    READ R1, 0xA0
    SUB  R0, R1
    CPY  R15, R0
    READ R1, font_big_latin1_kind
    ADD  R1, R15
    READ R2, [R1]
    READ R1, font_big_latin1_code_a
    ADD  R1, R15
    READ R13, [R1]
    READ R1, font_big_latin1_code_b
    ADD  R1, R15
    READ R14, [R1]
    READ R0, FONT_BIG_KIND_BIG
    CMP  R2, R0
    JZ   _fbgl_big
    READ R0, FONT_BIG_KIND_PAIR
    CMP  R2, R0
    JZ   _fbgl_pair
    CPY  R0, R13
    CALL _font_big_build_single
    RET
_fbgl_pair:
    CPY  R0, R13
    CPY  R1, R14
    CALL _font_big_build_pair
    RET
_fbgl_big:
    CPY  R0, R13
    CALL _font_big_get_ptr_from_idx
    RET

font_big_get_glyph:
    READ R1, 0x20
    CMP  R0, R1
    JLT  _fbg_c0
    READ R1, 0x7E
    CMP  R0, R1
    JGT  _fbg_high

    READ R1, 0x30
    CMP  R0, R1
    JLT  _fbg_ascii_punct
    READ R1, 0x39
    CMP  R0, R1
    JGT  _fbg_ascii_punct
    READ R1, 0x30
    SUB  R0, R1
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_ascii_punct:
    READ R1, 58
    CMP  R0, R1
    JZ   _fbg_idx10
    READ R1, 46
    CMP  R0, R1
    JZ   _fbg_idx11
    READ R1, 32
    CMP  R0, R1
    JZ   _fbg_idx12
    READ R1, 65
    CMP  R0, R1
    JLT  _fbg_ascii_single
    READ R1, 70
    CMP  R0, R1
    JGT  _fbg_ascii_lower
    READ R1, 65
    SUB  R0, R1
    READ R1, 13
    ADD  R0, R1
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_ascii_lower:
    READ R1, 97
    CMP  R0, R1
    JLT  _fbg_ascii_single
    READ R1, 102
    CMP  R0, R1
    JGT  _fbg_ascii_single
    READ R1, 97
    SUB  R0, R1
    READ R1, 13
    ADD  R0, R1
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_ascii_single:
    CALL _font_big_build_single
    RET

_fbg_idx10:
    READ R0, 10
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_idx11:
    READ R0, 11
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_idx12:
    READ R0, 12
    CALL _font_big_get_ptr_from_idx
    RET

_fbg_c0:
    READ R1, 0x1F
    CMP  R0, R1
    JGT  _fbg_unknown
    CPY  R15, R0
    READ R1, font_big_ctrl_c0_pair_a
    ADD  R1, R15
    READ R13, [R1]
    READ R1, font_big_ctrl_c0_pair_b
    ADD  R1, R15
    READ R14, [R1]
    CPY  R0, R13
    CPY  R1, R14
    CALL _font_big_build_pair
    RET

_fbg_high:
    READ R1, 0x7F
    CMP  R0, R1
    JZ   _fbg_del
    READ R1, 0x80
    CMP  R0, R1
    JLT  _fbg_unknown
    READ R1, 0x9F
    CMP  R0, R1
    JGT  _fbg_latin1
    READ R1, 0x80
    SUB  R0, R1
    CPY  R15, R0
    READ R1, font_big_ctrl_c1_pair_a
    ADD  R1, R15
    READ R13, [R1]
    READ R1, font_big_ctrl_c1_pair_b
    ADD  R1, R15
    READ R14, [R1]
    CPY  R0, R13
    CPY  R1, R14
    CALL _font_big_build_pair
    RET

_fbg_latin1:
    READ R1, 0xA0
    CMP  R0, R1
    JLT  _fbg_unknown
    CALL _font_big_build_latin1
    RET

_fbg_del:
    READ R0, 0x44
    READ R1, 0x4C
    CALL _font_big_build_pair
    RET

_fbg_unknown:
    READ R0, 0x3F
    CALL _font_big_build_single
    RET
