; =============================================================================
; lib-gfx.asm — Grafiikkakirjasto (tilat B ja C)
; =============================================================================
;
; KUVAUS:
;   Grafiikkakirjasto kCPU16-prosessorille. Tukee grafiikkatiloja B ja C.
;   Käyttö tekstitilassa A ($FF80 = 0) laukaisee INT INT_BREAKPOINT (INT 3).
;
; NÄYTTÖTILAT:
;   Tila B — Puoliblokkipikseli:  80 × 48 pikseliä  ($FF80 = 1)
;   Tila C — Braille:            160 × 96 pikseliä  ($FF80 = 2)
;
; TOIMINNOT:
;   gfx_clear  — Tyhjennä näyttö (nollaa koko VRAM)
;   gfx_pixel  — Piirra pikseli XOR-toimintona (R0=x, R1=y)
;   gfx_line   — Piirrä viiva XOR-toimintona  (R0=x0, R1=y0, R2=x1, R3=y1)
;
; REKISTERIKÄYTTÖ (clobbers):
;   gfx_clear: R0–R3
;   gfx_pixel: R0–R7
;   gfx_line:  R0–R12  (kutsuu gfx_pixel sisäisesti)
;
; KÄYTTÖESIMERKKI:
;   ; Aseta tila B
;   LOAD R0, 1
;   LOAD R1, GFX_MODE_REG
;   STORE [R1], R0
;
;   ; Tyhjennä näyttö
;   CALL gfx_clear
;
;   ; Piirrä pikseli (10, 5)
;   LOAD R0, 10
;   LOAD R1, 5
;   CALL gfx_pixel
;
;   ; Piirrä viiva (0,0)→(79,47)
;   LOAD R0, 0
;   LOAD R1, 0
;   LOAD R2, 79
;   LOAD R3, 47
;   CALL gfx_line
;
; VIRHEKÄSITTELY:
;   Jos $FF80 = 0 (tekstitila A), jokainen funktio laukaisee INT INT_BREAKPOINT.
;   Ohjelma ei palaa funktiosta — INT 3 siirtyy sen käsittelijään.
;
; PIKSELIFORMAATIT:
;   Tila B (bitti 1 = ylempi pikseli, bitti 0 = alempi pikseli per VRAM-sana):
;     osoite = VRAM_START + (y // 2) * 80 + x
;     bittikuva = 2 jos y parillinen (ylempi), 1 jos y pariton (alempi)
;
;   Tila C (8 braille-pikseliä per VRAM-sana, braille-bittikuvio alainen tavu):
;     char_col = x // 2
;     char_row = y // 4
;     pt_col   = x mod 2
;     pt_row   = y mod 4
;     osoite   = VRAM_START + char_row * 80 + char_col
;     bittinumero:
;       jos pt_row < 3:  bitti = pt_col * 3 + pt_row
;       jos pt_row == 3: bitti = 6 + pt_col
;
; =============================================================================

; Näyttötilarekisterin osoite ($FF80)
.const GFX_MODE_REG, 0xFF80

; Grafiikkatilakoodit
.const GFX_MODE_B, 1       ; Tila B — puoliblokkipikseli 80×48
.const GFX_MODE_C, 2       ; Tila C — braille 160×96

; =============================================================================
; gfx_clear — Tyhjennä grafiikkanäyttö
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R3
;
; Nollaa kaikki 1920 VRAM-sanaa ($F800–$FF7F).
; Laukaisee INT INT_BREAKPOINT (INT 3) jos näyttötila on A ($FF80 = 0).
; =============================================================================

gfx_clear:
        ; --- Tarkista näyttötila ---
        LOAD  R0, [GFX_MODE_REG]      ; R0 = nykyinen tila
        LOAD  R1, 0
        CMP   R0, R1
        JNZ   _gfx_clear_ok
        INT   INT_BREAKPOINT          ; Virhe: käyttö tekstitilassa A
_gfx_clear_ok:
        ; --- Nollaa koko VRAM ---
        LOAD  R0, VRAM_START          ; R0 = kirjoitusosoitin
        LOAD  R1, VRAM_WORDS          ; R1 = jäljellä olevat sanat (1920)
        LOAD  R2, 0                   ; R2 = nollaustäyte
        LOAD  R3, 1                   ; R3 = askeleen koko
_gfx_clear_loop:
        STORE [R0], R2                ; kirjoita 0
        ADD   R0, R3                  ; osoitin++
        SUB   R1, R3                  ; laskuri--
        JNZ   _gfx_clear_loop
        RET

; =============================================================================
; gfx_pixel — Piirra pikseli XOR-toimintona
;
; Sisään:  R0 = x-koordinaatti
;          R1 = y-koordinaatti
; Ulos:    —
; Clobbers: R0–R7
;
; Tila B: x ∈ [0, 79],  y ∈ [0, 47]
; Tila C: x ∈ [0, 159], y ∈ [0, 95]
;
; Lukee nykyisen VRAM-sanan ja XOR:aa sen laskettua bittikuvaa vasten.
; Laukaisee INT INT_BREAKPOINT (INT 3) jos näyttötila on A ($FF80 = 0).
; =============================================================================

gfx_pixel:
        ; --- Tarkista näyttötila ---
        LOAD  R2, [GFX_MODE_REG]      ; R2 = nykyinen tila
        LOAD  R3, 0
        CMP   R2, R3
        JNZ   _gfx_pixel_ok
        INT   INT_BREAKPOINT          ; Virhe: käyttö tekstitilassa A
_gfx_pixel_ok:
        ; Valitse laskentapolku tilan mukaan
        LOAD  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_pixel_b

        ; -----------------------------------------------------------------------
        ; Tila C (braille) — koordinaatti (px=R0, py=R1)
        ;
        ; char_col = px // 2                     → R3
        ; pt_col   = px mod 2 = px - char_col*2  → R4
        ; char_row = py // 4                     → R5
        ; pt_row   = py mod 4 = py - char_row*4  → R6
        ; addr     = VRAM_START + char_row*80 + char_col → R7
        ; bit_num:
        ;   jos pt_row < 3:  R5 = pt_col*3 + pt_row
        ;   jos pt_row == 3: R5 = 6 + pt_col
        ; bittikuva = 1 << bit_num               → R5
        ; -----------------------------------------------------------------------

        ; char_col = px // 2
        LOAD  R2, 2
        CPY   R3, R0
        DIV   R3, R2                  ; R3 = char_col = px // 2

        ; pt_col = px - char_col * 2
        CPY   R4, R3
        MUL   R4, R2                  ; R4 = char_col * 2
        CPY   R5, R0
        SUB   R5, R4                  ; R5 = pt_col = px mod 2

        ; char_row = py // 4
        LOAD  R2, 4
        CPY   R6, R1
        DIV   R6, R2                  ; R6 = char_row = py // 4

        ; pt_row = py - char_row * 4
        CPY   R4, R6
        MUL   R4, R2                  ; R4 = char_row * 4
        CPY   R7, R1
        SUB   R7, R4                  ; R7 = pt_row = py mod 4

        ; VRAM-osoite = VRAM_START + char_row * 80 + char_col
        LOAD  R2, 80
        MUL   R6, R2                  ; R6 = char_row * 80
        ADD   R6, R3                  ; R6 = char_row * 80 + char_col
        LOAD  R2, VRAM_START
        ADD   R6, R2                  ; R6 = VRAM-osoite

        ; Laske bittinumero
        ; R5 = pt_col, R7 = pt_row
        LOAD  R2, 3
        CMP   R7, R2                  ; pt_row == 3?
        JZ    _gfx_pixel_c_row3

        ; pt_row < 3: bit_num = pt_col * 3 + pt_row
        MUL   R5, R2                  ; R5 = pt_col * 3
        ADD   R5, R7                  ; R5 = pt_col * 3 + pt_row
        JUMP  _gfx_pixel_c_xor

_gfx_pixel_c_row3:
        ; pt_row == 3: bit_num = 6 + pt_col
        LOAD  R2, 6
        ADD   R5, R2                  ; R5 = 6 + pt_col

_gfx_pixel_c_xor:
        ; Bittikuva = 1 << bit_num
        LOAD  R4, 1
        SHL   R4, R5                  ; R4 = 1 << bit_num

        ; XOR VRAM-sana
        LOAD  R5, [R6]                ; R5 = nykyinen VRAM-sana
        XOR   R5, R4                  ; R5 ^= bittikuva
        STORE [R6], R5                ; kirjoita takaisin
        RET

_gfx_pixel_b:
        ; -----------------------------------------------------------------------
        ; Tila B (puoliblokkipikseli) — koordinaatti (x=R0, y=R1)
        ;
        ; addr     = VRAM_START + (y // 2) * 80 + x  → R3
        ; bittikuva = 2 jos y parillinen (ylempi pikseli, bitti 1)
        ;           = 1 jos y pariton  (alempi pikseli, bitti 0) → R5
        ; VRAM[addr] ^= bittikuva
        ; -----------------------------------------------------------------------

        ; addr = VRAM_START + (y // 2) * 80 + x
        LOAD  R2, 2
        CPY   R3, R1
        DIV   R3, R2                  ; R3 = y // 2
        LOAD  R4, 80
        MUL   R3, R4                  ; R3 = (y // 2) * 80
        ADD   R3, R0                  ; R3 = (y // 2) * 80 + x
        LOAD  R4, VRAM_START
        ADD   R3, R4                  ; R3 = VRAM-osoite

        ; y mod 2: parillinen → bitti 1 (= 2), pariton → bitti 0 (= 1)
        CPY   R4, R1                  ; R4 = y
        CPY   R5, R1
        DIV   R5, R2                  ; R5 = y // 2
        MUL   R5, R2                  ; R5 = (y // 2) * 2
        SUB   R4, R5                  ; R4 = y mod 2

        LOAD  R5, 0
        CMP   R4, R5
        JZ    _gfx_pixel_b_upper      ; y parillinen → ylempi pikseli

        ; y pariton: alempi pikseli → bitti 0
        LOAD  R5, 1
        JUMP  _gfx_pixel_b_xor

_gfx_pixel_b_upper:
        ; y parillinen: ylempi pikseli → bitti 1
        LOAD  R5, 2

_gfx_pixel_b_xor:
        LOAD  R6, [R3]                ; R6 = nykyinen VRAM-sana
        XOR   R6, R5                  ; R6 ^= bittikuva
        STORE [R3], R6                ; kirjoita takaisin
        RET

; =============================================================================
; gfx_line — Piirrä viiva XOR-toimintona (Bresenham)
;
; Sisään:  R0 = x0 (aloituspiste x)
;          R1 = y0 (aloituspiste y)
;          R2 = x1 (päätepiste x)
;          R3 = y1 (päätepiste y)
; Ulos:    —
; Clobbers: R0–R12
;
; Piirtää viivan pisteestä (x0, y0) pisteeseen (x1, y1) Bresenhamin
; algoritmilla kutsumalla gfx_pixel jokaiselle viivan pikselille.
; Laukaisee INT INT_BREAKPOINT (INT 3) jos näyttötila on A ($FF80 = 0).
;
; Rekisterikartta Bresenham-silmukan aikana:
;   R4  = cx    (nykyinen x, muuttuu iteraatioittain)
;   R5  = cy    (nykyinen y, muuttuu iteraatioittain)
;   R6  = x1    (kohde x, pysyy vakiona)
;   R7  = y1    (kohde y, pysyy vakiona)
;   R8  = err   (Bresenhamin virhemuuttuja)
;   R9  = dx    (|x1 − x0|, positiivinen)
;   R10 = dy_neg (−|y1 − y0|, nolla tai negatiivinen)
;   R11 = sx    (1 tai −1 = 0xFFFF, x:n askelsuunta)
;   R12 = sy    (1 tai −1 = 0xFFFF, y:n askelsuunta)
; =============================================================================

gfx_line:
        ; --- Tarkista näyttötila ---
        LOAD  R4, [GFX_MODE_REG]      ; R4 = nykyinen tila
        LOAD  R5, 0
        CMP   R4, R5
        JNZ   _gfx_line_ok
        INT   INT_BREAKPOINT          ; Virhe: käyttö tekstitilassa A
_gfx_line_ok:
        ; Alusta Bresenham-muuttujat
        CPY   R4, R0                  ; R4 = cx = x0
        CPY   R5, R1                  ; R5 = cy = y0
        CPY   R6, R2                  ; R6 = x1
        CPY   R7, R3                  ; R7 = y1

        ; --- Laske dx ja sx ---
        ; dx = |x1 − x0|, sx = sign(x1 − x0)
        CPY   R9, R6
        SUB   R9, R4                  ; R9 = x1 − x0
        LOAD  R0, 0
        CMP   R9, R0
        JGE   _gfx_line_sx_pos
        ; x1 < x0: sx = −1, dx = −R9
        LOAD  R11, 0xFFFF             ; sx = −1 (kaksoiskomplemenitti: 0xFFFF = −1)
        NOT   R9                      ; ~R9
        LOAD  R0, 1
        ADD   R9, R0                  ; R9 = |x1−x0| = dx
        JUMP  _gfx_line_dy
_gfx_line_sx_pos:
        LOAD  R11, 1                  ; sx = 1  (R9 = dx, jo >= 0)

        ; --- Laske dy_neg ja sy ---
        ; dy_neg = −|y1 − y0|  (nolla tai negatiivinen), sy = sign(y1 − y0)
_gfx_line_dy:
        CPY   R10, R7
        SUB   R10, R5                 ; R10 = y1 − y0
        LOAD  R0, 0
        CMP   R10, R0
        JGE   _gfx_line_sy_pos
        ; y1 < y0: sy = −1, R10 on jo negatiivinen (= −|dy|)
        LOAD  R12, 0xFFFF             ; sy = −1 (kaksoiskomplemenitti: 0xFFFF = −1)
        JUMP  _gfx_line_err
_gfx_line_sy_pos:
        LOAD  R12, 1                  ; sy = 1
        ; R10 = |dy| > 0; negaa → dy_neg = −|dy|
        NOT   R10
        LOAD  R0, 1
        ADD   R10, R0                 ; R10 = dy_neg = −|dy|

        ; --- Alusta err = dx + dy_neg ---
_gfx_line_err:
        CPY   R8, R9
        ADD   R8, R10                 ; R8 = err = dx + dy_neg

        ; --- Pääsilmukka ---
_gfx_line_loop:
        ; Piirrä nykyinen piste gfx_pixel(cx, cy)
        CPY   R0, R4                  ; R0 = cx
        CPY   R1, R5                  ; R1 = cy
        ; Tallenna Bresenham-tila pinoon (gfx_pixel clobbers R0–R7)
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        CALL  gfx_pixel
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4

        ; Tarkista onko kohde saavutettu (cx == x1 ja cy == y1)
        CMP   R4, R6                  ; cx == x1?
        JNZ   _gfx_line_step
        CMP   R5, R7                  ; cy == y1?
        JZ    _gfx_line_done

_gfx_line_step:
        ; e2 = 2 * err
        CPY   R0, R8
        LOAD  R1, 2
        MUL   R0, R1                  ; R0 = e2 = 2 * err

        ; Jos e2 >= dy_neg: err += dy_neg; cx += sx
        ; (dy_neg on negatiivinen, joten e2 >= dy_neg tarkoittaa e2 ei liian pieni)
        CMP   R0, R10                 ; e2 − dy_neg (signed)
        JLT   _gfx_line_no_x         ; e2 < dy_neg → ohita
        ADD   R8, R10                 ; err += dy_neg
        ADD   R4, R11                 ; cx += sx
_gfx_line_no_x:

        ; Jos e2 <= dx: err += dx; cy += sy
        CMP   R0, R9                  ; e2 − dx (signed)
        JGT   _gfx_line_no_y         ; e2 > dx → ohita
        ADD   R8, R9                  ; err += dx
        ADD   R5, R12                 ; cy += sy
_gfx_line_no_y:

        JUMP  _gfx_line_loop

_gfx_line_done:
        RET
