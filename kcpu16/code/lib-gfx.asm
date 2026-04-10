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
;   gfx_clear         — Tyhjennä näyttö (nollaa koko VRAM)
;   gfx_flip          — Flipaa kaksoisbufferointi (triggeroi näytönpäivitys)
;   gfx_set_draw_mode — Aseta piirtotila (R0 = piirtotila)
;   gfx_pixel         — Piirra pikseli (R0=x, R1=y)
;   gfx_line          — Piirrä viiva (R0=x0, R1=y0, R2=x1, R3=y1)
;
; PIIRTOTILAT (gfx_set_draw_mode:n R0-arvo):
;   GFX_DRAW_XOR (0) — XOR-tila: vaihtaa pikselin tilaa (oletus)
;   GFX_DRAW_FG  (1) — Etuväri:   asettaa pikselin päälle
;   GFX_DRAW_BG  (2) — Taustaväri: nollaa pikselin
;
; REKISTERIKÄYTTÖ (clobbers):
;   gfx_clear:         R0–R2  (käyttää FILL-käskyä, ei enää R3:a)
;   gfx_flip:          R0
;   gfx_set_draw_mode: —
;   gfx_pixel:         R0–R7
;   gfx_line:          R0–R12  (kutsuu gfx_pixel sisäisesti)
;
; KÄYTTÖESIMERKKI:
;   ; Aseta tila B
;   READ  R0, GFX_MODE_B
;   READ  R1, GFX_MODE_REG
;   STORE [R1], R0
;
;   ; Tyhjennä näyttö (kirjoittaa VRAMiin = taustapuskuri)
;   CALL  gfx_clear
;
;   ; Piirrä pikseli (10, 5)
;   READ  R0, 10
;   READ  R1, 5
;   CALL  gfx_pixel
;
;   ; Piirrä viiva (0,0)→(79,47)
;   READ  R0, 0
;   READ  R1, 0
;   READ  R2, 79
;   READ  R3, 47
;   CALL  gfx_line
;
;   ; Kehys valmis — flipaa etupuskuriin (tiloissa B ja C)
;   CALL  gfx_flip
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

; Näyttötilarekisterin osoite ($FF80) ja grafiikkatilakoodit ovat
; arkkitehtuurivakioita (ARCH_SYMBOLS) — ei tarvita .const-määrittelyjä:
;   GFX_MODE_REG = 0xFF80,  GFX_MODE_A = 0,  GFX_MODE_B = 1,  GFX_MODE_C = 2
;   GFX_FLIP_REG = 0xFF81   (kaksoisbufferoinnin flip-rekisteri)

; Piirtotilat (käytetään gfx_set_draw_mode-funktiolle)
.const GFX_DRAW_XOR, 0     ; XOR-tila: vaihtaa pikselin tilaa (oletus)
.const GFX_DRAW_FG,  1     ; Etuväri:   asettaa pikselin päälle
.const GFX_DRAW_BG,  2     ; Taustaväri: nollaa pikselin

; Huom: VRAM_START (0xF800), VRAM_WORDS (1920), INT_BREAKPOINT (3),
; GFX_MODE_REG, GFX_MODE_A/B/C ja GFX_FLIP_REG ovat arkkitehtuurivakioita
; jotka assembler injektoi automaattisesti (ARCH_SYMBOLS).
; Niitä ei tarvitse määritellä .const-direktiivillä.

; =============================================================================
; gfx_draw_mode — Nykyinen piirtotila (1-sanainen muuttuja)
; Arvo: GFX_DRAW_XOR=0 (oletus), GFX_DRAW_FG=1, GFX_DRAW_BG=2
; =============================================================================

gfx_draw_mode:
        .db  0

; =============================================================================
; gfx_set_draw_mode — Aseta piirtotila
;
; Sisään:  R0 = uusi piirtotila (GFX_DRAW_XOR / GFX_DRAW_FG / GFX_DRAW_BG)
; Ulos:    —
; Clobbers: —
; =============================================================================

gfx_set_draw_mode:
        STORE [gfx_draw_mode], R0
        RET

; =============================================================================
; gfx_flip — Flipaa kaksoisbufferointi (triggeroi näytönpäivitys)
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0
;
; Kirjoittaa GFX_FLIP_REG:iin (0xFF81) arvon 1, jolloin TUI renderöi
; nykyisen VRAMin etupuskuriin ja päivittää näytön atomisesti. Rekisteri
; nollataan automaattisesti flipin jälkeen.
;
; Kutsu tämä kun koko kehys on piirretty (gfx_clear + piirtokäskyt).
; Ei vaikutusta tekstitilassa A — kaksoisbufferointi on vain tiloissa B ja C.
; =============================================================================

gfx_flip:
        READ  R0, 1
        STORE [GFX_FLIP_REG], R0
        RET

; =============================================================================
; gfx_clear — Tyhjennä grafiikkanäyttö
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R2
;
; Nollaa kaikki 1920 VRAM-sanaa ($F800–$FF7F) FILL-käskyllä.
; Huom: toiminto ohittaa gfx_draw_mode — tyhjentää aina taustaan.
; Laukaisee INT INT_BREAKPOINT (INT 3) jos näyttötila on A ($FF80 = 0).
; =============================================================================

gfx_clear:
        ; --- Tarkista näyttötila ---
        READ  R0, [GFX_MODE_REG]      ; R0 = nykyinen tila
        READ  R1, 0
        CMP   R0, R1
        JNZ   _gfx_clear_ok
        INT   INT_BREAKPOINT          ; Virhe: käyttö tekstitilassa A
_gfx_clear_ok:
        ; --- Nollaa koko VRAM FILL-käskyllä ---
        READ  R0, VRAM_START          ; R0 = alkuosoite ($F800)
        READ  R1, VRAM_END            ; R1 = loppuosoite ($FF7F, inklusiivinen)
        READ  R2, 0                   ; R2 = täyttöarvo (nolla)
        FILL  R0, R1, R2              ; täytä [VRAM_START..VRAM_END] nollilla
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
        READ  R2, [GFX_MODE_REG]      ; R2 = nykyinen tila
        READ  R3, 0
        CMP   R2, R3
        JNZ   _gfx_pixel_ok
        INT   INT_BREAKPOINT          ; Virhe: käyttö tekstitilassa A
_gfx_pixel_ok:
        ; Valitse laskentapolku tilan mukaan
        READ  R3, GFX_MODE_B
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
        READ  R2, 2
        CPY   R3, R0
        DIV   R3, R2                  ; R3 = char_col = px // 2

        ; pt_col = px - char_col * 2
        CPY   R4, R3
        MUL   R4, R2                  ; R4 = char_col * 2
        CPY   R5, R0
        SUB   R5, R4                  ; R5 = pt_col = px mod 2

        ; char_row = py // 4
        READ  R2, 4
        CPY   R6, R1
        DIV   R6, R2                  ; R6 = char_row = py // 4

        ; pt_row = py - char_row * 4
        CPY   R4, R6
        MUL   R4, R2                  ; R4 = char_row * 4
        CPY   R7, R1
        SUB   R7, R4                  ; R7 = pt_row = py mod 4

        ; VRAM-osoite = VRAM_START + char_row * 80 + char_col
        READ  R2, 80
        MUL   R6, R2                  ; R6 = char_row * 80
        ADD   R6, R3                  ; R6 = char_row * 80 + char_col
        READ  R2, VRAM_START
        ADD   R6, R2                  ; R6 = VRAM-osoite

        ; Laske bittinumero
        ; R5 = pt_col, R7 = pt_row
        READ  R2, 3
        CMP   R7, R2                  ; pt_row == 3?
        JZ    _gfx_pixel_c_row3

        ; pt_row < 3: bit_num = pt_col * 3 + pt_row
        MUL   R5, R2                  ; R5 = pt_col * 3
        ADD   R5, R7                  ; R5 = pt_col * 3 + pt_row
        JUMP  _gfx_pixel_c_xor

_gfx_pixel_c_row3:
        ; pt_row == 3: bit_num = 6 + pt_col
        READ  R2, 6
        ADD   R5, R2                  ; R5 = 6 + pt_col

_gfx_pixel_c_xor:
        ; Bittikuva = 1 << bit_num
        READ  R4, 1
        SHL   R4, R5                  ; R4 = 1 << bit_num  (R5=bit_num, R6=osoite)
        CPY   R5, R4                  ; R5 = bitmask
        JUMP  _gfx_apply              ; → yhteinen piirtokäsittelijä

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
        READ  R2, 2
        CPY   R3, R1
        DIV   R3, R2                  ; R3 = y // 2
        READ  R4, 80
        MUL   R3, R4                  ; R3 = (y // 2) * 80
        ADD   R3, R0                  ; R3 = (y // 2) * 80 + x
        READ  R4, VRAM_START
        ADD   R3, R4                  ; R3 = VRAM-osoite

        ; y mod 2: parillinen → bitti 1 (= 2), pariton → bitti 0 (= 1)
        CPY   R4, R1                  ; R4 = y
        CPY   R5, R1
        DIV   R5, R2                  ; R5 = y // 2
        MUL   R5, R2                  ; R5 = (y // 2) * 2
        SUB   R4, R5                  ; R4 = y mod 2

        READ  R5, 0
        CMP   R4, R5
        JZ    _gfx_pixel_b_upper      ; y parillinen → ylempi pikseli

        ; y pariton: alempi pikseli → bitti 0
        READ  R5, 1
        JUMP  _gfx_pixel_b_xor

_gfx_pixel_b_upper:
        ; y parillinen: ylempi pikseli → bitti 1
        READ  R5, 2

_gfx_pixel_b_xor:
        CPY   R6, R3                  ; R6 = VRAM-osoite, R5 = bitmask
        JUMP  _gfx_apply              ; → yhteinen piirtokäsittelijä

; =============================================================================
; _gfx_apply — Yhteinen piirtokäsittelijä (sisäinen apurutiini)
;
; Sisään:  R6 = VRAM-osoite
;          R5 = bitmask (asetettavat bitit)
; Ulos:    —
; Clobbers: R3, R4, R6  (gfx_pixel:n clobber-rajoissa)
;
; Lukee gfx_draw_mode ja soveltaa:
;   GFX_DRAW_XOR (0): VRAM[R6] ^= R5
;   GFX_DRAW_FG  (1): VRAM[R6] |= R5
;   GFX_DRAW_BG  (2): VRAM[R6] &= ~R5
; =============================================================================

_gfx_apply:
        READ  R3, [gfx_draw_mode]     ; R3 = piirtotila
        READ  R4, GFX_DRAW_FG
        CMP   R3, R4
        JZ    _gfx_apply_fg
        READ  R4, GFX_DRAW_BG
        CMP   R3, R4
        JZ    _gfx_apply_bg
        ; GFX_DRAW_XOR (0, oletus)
        READ  R3, [R6]
        XOR   R3, R5
        STORE [R6], R3
        RET
_gfx_apply_fg:
        READ  R3, [R6]
        OR    R3, R5
        STORE [R6], R3
        RET
_gfx_apply_bg:
        CPY   R4, R5                  ; R4 = bitmask-kopio
        NOT   R4                      ; R4 = ~bitmask
        READ  R3, [R6]
        AND   R3, R4
        STORE [R6], R3
        RET

; =============================================================================
; gfx_line — Piirrä viiva (Bresenham)
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
        READ  R4, [GFX_MODE_REG]      ; R4 = nykyinen tila
        READ  R5, 0
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
        READ  R0, 0
        CMP   R9, R0
        JGE   _gfx_line_sx_pos
        ; x1 < x0: sx = −1, dx = −R9
        READ  R11, 0xFFFF             ; sx = −1 (kaksoiskomplemenitti: 0xFFFF = −1)
        NOT   R9                      ; ~R9
        READ  R0, 1
        ADD   R9, R0                  ; R9 = |x1−x0| = dx
        JUMP  _gfx_line_dy
_gfx_line_sx_pos:
        READ  R11, 1                  ; sx = 1  (R9 = dx, jo >= 0)

        ; --- Laske dy_neg ja sy ---
        ; dy_neg = −|y1 − y0|  (nolla tai negatiivinen), sy = sign(y1 − y0)
_gfx_line_dy:
        CPY   R10, R7
        SUB   R10, R5                 ; R10 = y1 − y0
        READ  R0, 0
        CMP   R10, R0
        JGE   _gfx_line_sy_pos
        ; y1 < y0: sy = −1, R10 on jo negatiivinen (= −|dy|)
        READ  R12, 0xFFFF             ; sy = −1 (kaksoiskomplemenitti: 0xFFFF = −1)
        JUMP  _gfx_line_err
_gfx_line_sy_pos:
        READ  R12, 1                  ; sy = 1
        ; R10 = |dy| > 0; negaa → dy_neg = −|dy|
        NOT   R10
        READ  R0, 1
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
        READ  R1, 2
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
