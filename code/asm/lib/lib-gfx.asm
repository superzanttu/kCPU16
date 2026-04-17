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
;   gfx_scroll_up     — Scrollaa kuvaa ylöspäin (R0 = 1..15 px)
;   gfx_scroll_down   — Scrollaa kuvaa alaspäin (R0 = 1..15 px)
;   gfx_scroll_left   — Scrollaa kuvaa vasemmalle (R0 = 1..15 px)
;   gfx_scroll_right  — Scrollaa kuvaa oikealle (R0 = 1..15 px)
;   gfx_pixel         — Piirra pikseli (R0=x, R1=y)
;   gfx_line          — Piirrä viiva (R0=x0, R1=y0, R2=x1, R3=y1)
;   gfx_draw_text_big — Piirrä 6x8 BIG-teksti (0-9, :, ., valilyonti)
;   gfx_sprite_xor_1bpp_64x32 — XOR-piirto 64x32 1bpp framebufferiin
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
;   gfx_scroll_*:      R0–R12
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

        .include "lib-font_small.asm"
        .include "lib-font_big.asm"

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
gfx_flip_enabled:
        .db  1

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
; gfx_set_flip_enabled — Ota kaksoispuskurointi paalle/pois
;
; Sisään:  R0 = 0 (pois), muu kuin 0 (paalle)
; Ulos:    —
; Clobbers: —
; =============================================================================

gfx_set_flip_enabled:
        READ  R1, 0
        CMP   R0, R1
        JZ    _gfx_sfe_off
        READ  R0, 1
_gfx_sfe_off:
        STORE [gfx_flip_enabled], R0
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
        READ  R1, [gfx_flip_enabled]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gfx_flip_done
        READ  R0, 1
        STORE [GFX_FLIP_REG], R0
_gfx_flip_done:
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
; _gfx_get_dims — Palauta aktiivisen grafiikkatilan mitat
;
; Sisään:  —
; Ulos:    R10 = leveys, R11 = korkeus
; Clobbers: R2–R3
;
; Huom: Laukaisee INT INT_BREAKPOINT jos näyttötila on A.
; =============================================================================

_gfx_get_dims:
        READ  R2, [GFX_MODE_REG]
        READ  R3, 0
        CMP   R2, R3
        JNZ   _gfx_dims_ok
        INT   INT_BREAKPOINT
_gfx_dims_ok:
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_dims_b
        READ  R10, 160
        READ  R11, 96
        RET
_gfx_dims_b:
        READ  R10, 80
        READ  R11, 48
        RET

; =============================================================================
; _gfx_get_pixel — Lue yksittainen pikseli (0/1) tilassa B tai C
;
; Sisään:  R0 = x, R1 = y
; Ulos:    R0 = 0 tai 1
; Clobbers: R2–R7
; =============================================================================

_gfx_get_pixel:
        READ  R2, [GFX_MODE_REG]
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_get_pixel_b

        ; Tila C
        READ  R2, 2
        CPY   R3, R0
        DIV   R3, R2                  ; char_col = x // 2
        CPY   R4, R3
        MUL   R4, R2
        CPY   R5, R0
        SUB   R5, R4                  ; pt_col = x mod 2

        READ  R2, 4
        CPY   R6, R1
        DIV   R6, R2                  ; char_row = y // 4
        CPY   R4, R6
        MUL   R4, R2
        CPY   R7, R1
        SUB   R7, R4                  ; pt_row = y mod 4

        READ  R2, 80
        MUL   R6, R2
        ADD   R6, R3
        READ  R2, VRAM_START
        ADD   R6, R2                  ; R6 = addr

        READ  R2, 3
        CMP   R7, R2
        JZ    _gfx_get_c_row3
        MUL   R5, R2
        ADD   R5, R7                  ; bit_num = pt_col*3 + pt_row
        JUMP  _gfx_get_c_mask
_gfx_get_c_row3:
        READ  R2, 6
        ADD   R5, R2                  ; bit_num = 6 + pt_col
_gfx_get_c_mask:
        READ  R4, 1
        SHL   R4, R5                  ; mask
        READ  R3, [R6]
        AND   R3, R4
        READ  R0, 0
        CMP   R3, R0
        JZ    _gfx_get_ret
        READ  R0, 1
_gfx_get_ret:
        RET

_gfx_get_pixel_b:
        ; Tila B
        READ  R2, 2
        CPY   R3, R1
        DIV   R3, R2                  ; y // 2
        READ  R4, 80
        MUL   R3, R4
        ADD   R3, R0
        READ  R4, VRAM_START
        ADD   R3, R4                  ; R3 = addr

        CPY   R4, R1
        CPY   R5, R1
        DIV   R5, R2
        MUL   R5, R2
        SUB   R4, R5                  ; y mod 2
        READ  R5, 0
        CMP   R4, R5
        JZ    _gfx_get_b_upper
        READ  R5, 1
        JUMP  _gfx_get_b_mask
_gfx_get_b_upper:
        READ  R5, 2
_gfx_get_b_mask:
        READ  R4, [R3]
        AND   R4, R5
        READ  R0, 0
        CMP   R4, R0
        JZ    _gfx_get_b_ret
        READ  R0, 1
_gfx_get_b_ret:
        RET

; =============================================================================
; _gfx_put_pixel — Kirjoita yksittainen pikseli absoluuttisesti (0/1)
;
; Sisään:  R0 = x, R1 = y, R2 = arvo (0/1)
; Ulos:    —
; Clobbers: R3–R7
; =============================================================================

_gfx_put_pixel:
        READ  R3, [GFX_MODE_REG]
        READ  R4, GFX_MODE_B
        CMP   R3, R4
        JZ    _gfx_put_pixel_b

        ; Tila C
        READ  R3, 2
        CPY   R4, R0
        DIV   R4, R3                  ; char_col
        CPY   R5, R4
        MUL   R5, R3
        CPY   R6, R0
        SUB   R6, R5                  ; pt_col

        READ  R3, 4
        CPY   R7, R1
        DIV   R7, R3                  ; char_row
        CPY   R5, R7
        MUL   R5, R3
        CPY   R3, R1
        SUB   R3, R5                  ; pt_row

        READ  R5, 80
        MUL   R7, R5
        ADD   R7, R4
        READ  R5, VRAM_START
        ADD   R7, R5                  ; R7 = addr

        READ  R5, 3
        CMP   R3, R5
        JZ    _gfx_put_c_row3
        MUL   R6, R5
        ADD   R6, R3
        JUMP  _gfx_put_c_mask
_gfx_put_c_row3:
        READ  R5, 6
        ADD   R6, R5
_gfx_put_c_mask:
        READ  R4, 1
        SHL   R4, R6                  ; mask
        READ  R6, [R7]
        READ  R5, 0
        CMP   R2, R5
        JZ    _gfx_put_c_clear
        OR    R6, R4
        STORE [R7], R6
        RET
_gfx_put_c_clear:
        NOT   R4
        AND   R6, R4
        STORE [R7], R6
        RET

_gfx_put_pixel_b:
        ; Tila B
        READ  R3, 2
        CPY   R4, R1
        DIV   R4, R3                  ; y // 2
        READ  R5, 80
        MUL   R4, R5
        ADD   R4, R0
        READ  R5, VRAM_START
        ADD   R4, R5                  ; R4 = addr

        CPY   R5, R1
        CPY   R6, R1
        DIV   R6, R3
        MUL   R6, R3
        SUB   R5, R6                  ; y mod 2
        READ  R6, 0
        CMP   R5, R6
        JZ    _gfx_put_b_upper
        READ  R5, 1
        JUMP  _gfx_put_b_mask
_gfx_put_b_upper:
        READ  R5, 2
_gfx_put_b_mask:
        READ  R6, [R4]
        READ  R7, 0
        CMP   R2, R7
        JZ    _gfx_put_b_clear
        OR    R6, R5
        STORE [R4], R6
        RET
_gfx_put_b_clear:
        NOT   R5
        AND   R6, R5
        STORE [R4], R6
        RET

; =============================================================================
; gfx_scroll_up/down/left/right — Scrollaus 1..15 pikselia
;
; Sisään:  R0 = siirtomaara pikseleina (1..15, >15 clampataan)
; Ulos:    —
; Clobbers: R0–R12
; =============================================================================

gfx_scroll_up:
        CALL  _gfx_get_dims
        READ  R1, 0
        CMP   R0, R1
        JLE   _gfx_scroll_up_done
        READ  R1, 15
        CMP   R0, R1
        JLE   _gfx_scroll_up_amt_ok
        CPY   R0, R1
_gfx_scroll_up_amt_ok:
        CPY   R12, R0                 ; amount
        CMP   R12, R11
        JLT   _gfx_scroll_up_try_fast
        CALL  gfx_clear
        RET

        ; Fastpath: käytä COPY/FILL:ä kun siirto osuu VRAM-rivijaolle.
        ; Tila B: amount % 2 == 0  -> row_shift = amount / 2
        ; Tila C: amount % 4 == 0  -> row_shift = amount / 4
_gfx_scroll_up_try_fast:
        READ  R2, [GFX_MODE_REG]
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_scroll_up_try_fast_b

        ; Tila C: tarkista jaaollisuus luvulla 4
        READ  R3, 4
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = row_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = row_shift * 4
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 4
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_up_loop
        JUMP  _gfx_scroll_up_fast

_gfx_scroll_up_try_fast_b:
        ; Tila B: tarkista jaaollisuus luvulla 2
        READ  R3, 2
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = row_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = row_shift * 2
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 2
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_up_loop

_gfx_scroll_up_fast:
        ; row_ofs_words = row_shift * 80
        READ  R6, 80
        MUL   R4, R6                  ; R4 = row_ofs_words

        ; COPY [VRAM_START + ofs .. VRAM_END] -> VRAM_START
        READ  R0, VRAM_START
        ADD   R0, R4
        READ  R1, VRAM_END
        READ  R2, VRAM_START
        COPY  R0, R1, R2

        ; FILL [VRAM_END - ofs + 1 .. VRAM_END] = 0
        READ  R0, VRAM_END
        SUB   R0, R4
        READ  R1, 1
        ADD   R0, R1
        READ  R1, VRAM_END
        READ  R2, 0
        FILL  R0, R1, R2
        RET

_gfx_scroll_up_loop:
        READ  R4, 0                   ; y
_gfx_scroll_up_y:
        CMP   R4, R11
        JGE   _gfx_scroll_up_done
        CPY   R6, R4
        ADD   R6, R12                 ; src_y = y + amount
        READ  R5, 0                   ; x
_gfx_scroll_up_x:
        CMP   R5, R10
        JGE   _gfx_scroll_up_next_y
        CPY   R1, R6
        CMP   R1, R11
        JGE   _gfx_scroll_up_clear

        CPY   R0, R5
        CPY   R1, R6
        CALL  _gfx_get_pixel          ; R0 = src pixel
        CPY   R2, R0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel
        JUMP  _gfx_scroll_up_inc_x

_gfx_scroll_up_clear:
        READ  R2, 0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel

_gfx_scroll_up_inc_x:
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gfx_scroll_up_x

_gfx_scroll_up_next_y:
        READ  R0, 1
        ADD   R4, R0
        JUMP  _gfx_scroll_up_y

_gfx_scroll_up_done:
        RET

gfx_scroll_down:
        CALL  _gfx_get_dims
        READ  R1, 0
        CMP   R0, R1
        JLE   _gfx_scroll_down_done
        READ  R1, 15
        CMP   R0, R1
        JLE   _gfx_scroll_down_amt_ok
        CPY   R0, R1
_gfx_scroll_down_amt_ok:
        CPY   R12, R0                 ; amount
        CMP   R12, R11
        JLT   _gfx_scroll_down_try_fast
        CALL  gfx_clear
        RET

        ; Fastpath: käytä COPY/FILL:ä kun siirto osuu VRAM-rivijaolle.
        ; Tila B: amount % 2 == 0  -> row_shift = amount / 2
        ; Tila C: amount % 4 == 0  -> row_shift = amount / 4
_gfx_scroll_down_try_fast:
        READ  R2, [GFX_MODE_REG]
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_scroll_down_try_fast_b

        ; Tila C: tarkista jaaollisuus luvulla 4
        READ  R3, 4
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = row_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = row_shift * 4
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 4
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_down_loop
        JUMP  _gfx_scroll_down_fast

_gfx_scroll_down_try_fast_b:
        ; Tila B: tarkista jaaollisuus luvulla 2
        READ  R3, 2
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = row_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = row_shift * 2
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 2
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_down_loop

_gfx_scroll_down_fast:
        ; row_ofs_words = row_shift * 80
        READ  R6, 80
        MUL   R4, R6                  ; R4 = row_ofs_words

        ; COPY [VRAM_START .. VRAM_END - ofs] -> VRAM_START + ofs
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        SUB   R1, R4
        READ  R2, VRAM_START
        ADD   R2, R4
        COPY  R0, R1, R2

        ; FILL [VRAM_START .. VRAM_START + ofs - 1] = 0
        READ  R0, VRAM_START
        READ  R1, VRAM_START
        ADD   R1, R4
        READ  R3, 1
        SUB   R1, R3
        READ  R2, 0
        FILL  R0, R1, R2
        RET

_gfx_scroll_down_loop:
        CPY   R4, R11
        READ  R0, 1
        SUB   R4, R0                  ; y = h - 1
_gfx_scroll_down_y:
        READ  R0, 0
        CMP   R4, R0
        JLT   _gfx_scroll_down_done
        CPY   R6, R4
        SUB   R6, R12                 ; src_y = y - amount
        READ  R5, 0                   ; x
_gfx_scroll_down_x:
        CMP   R5, R10
        JGE   _gfx_scroll_down_prev_y

        READ  R0, 0
        CMP   R6, R0
        JLT   _gfx_scroll_down_clear

        CPY   R0, R5
        CPY   R1, R6
        CALL  _gfx_get_pixel
        CPY   R2, R0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel
        JUMP  _gfx_scroll_down_inc_x

_gfx_scroll_down_clear:
        READ  R2, 0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel

_gfx_scroll_down_inc_x:
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gfx_scroll_down_x

_gfx_scroll_down_prev_y:
        READ  R0, 1
        SUB   R4, R0
        JUMP  _gfx_scroll_down_y

_gfx_scroll_down_done:
        RET

gfx_scroll_left:
        CALL  _gfx_get_dims
        READ  R1, 0
        CMP   R0, R1
        JLE   _gfx_scroll_left_done
        READ  R1, 15
        CMP   R0, R1
        JLE   _gfx_scroll_left_amt_ok
        CPY   R0, R1
_gfx_scroll_left_amt_ok:
        CPY   R12, R0                 ; amount
        CMP   R12, R10
        JLT   _gfx_scroll_left_try_fast
        CALL  gfx_clear
        RET

        ; Fastpath: vaakasiirto sanarajassa.
        ; Tila B: 1 px = 1 sana -> aina fastpath.
        ; Tila C: 2 px = 1 sana -> fastpath kun amount % 2 == 0.
_gfx_scroll_left_try_fast:
        READ  R2, [GFX_MODE_REG]
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_scroll_left_fast_b

        ; Tila C: amount / 2 (vain jos jaollinen)
        READ  R3, 2
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = word_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = word_shift * 2
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 2
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_left_loop
        CPY   R12, R4                 ; R12 = word_shift
        JUMP  _gfx_scroll_left_fast

_gfx_scroll_left_fast_b:
        ; Tila B: R12 (px) == word_shift
_gfx_scroll_left_fast:
        READ  R4, VRAM_START          ; row_base
        READ  R5, 0                   ; row_idx
        READ  R6, 24                  ; VRAM-rivien maara (molemmissa tiloissa)

_gfx_scroll_left_fast_row:
        CMP   R5, R6
        JGE   _gfx_scroll_left_done

        ; COPY [row_base + shift .. row_base + 79] -> row_base
        CPY   R0, R4
        ADD   R0, R12
        CPY   R1, R4
        READ  R2, 79
        ADD   R1, R2
        CPY   R2, R4
        COPY  R0, R1, R2

        ; FILL [row_base + (80 - shift) .. row_base + 79] = 0
        CPY   R0, R4
        READ  R1, 80
        ADD   R0, R1
        SUB   R0, R12
        CPY   R1, R4
        READ  R2, 79
        ADD   R1, R2
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R0, 80
        ADD   R4, R0
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gfx_scroll_left_fast_row

_gfx_scroll_left_loop:
        READ  R4, 0                   ; y
_gfx_scroll_left_y:
        CMP   R4, R11
        JGE   _gfx_scroll_left_done
        READ  R5, 0                   ; x
_gfx_scroll_left_x:
        CMP   R5, R10
        JGE   _gfx_scroll_left_next_y
        CPY   R6, R5
        ADD   R6, R12                 ; src_x = x + amount
        CPY   R1, R6
        CMP   R1, R10
        JGE   _gfx_scroll_left_clear

        CPY   R0, R6
        CPY   R1, R4
        CALL  _gfx_get_pixel
        CPY   R2, R0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel
        JUMP  _gfx_scroll_left_inc_x

_gfx_scroll_left_clear:
        READ  R2, 0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel

_gfx_scroll_left_inc_x:
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gfx_scroll_left_x

_gfx_scroll_left_next_y:
        READ  R0, 1
        ADD   R4, R0
        JUMP  _gfx_scroll_left_y

_gfx_scroll_left_done:
        RET

gfx_scroll_right:
        CALL  _gfx_get_dims
        READ  R1, 0
        CMP   R0, R1
        JLE   _gfx_scroll_right_done
        READ  R1, 15
        CMP   R0, R1
        JLE   _gfx_scroll_right_amt_ok
        CPY   R0, R1
_gfx_scroll_right_amt_ok:
        CPY   R12, R0                 ; amount
        CMP   R12, R10
        JLT   _gfx_scroll_right_try_fast
        CALL  gfx_clear
        RET

        ; Fastpath: vaakasiirto sanarajassa.
        ; Tila B: 1 px = 1 sana -> aina fastpath.
        ; Tila C: 2 px = 1 sana -> fastpath kun amount % 2 == 0.
_gfx_scroll_right_try_fast:
        READ  R2, [GFX_MODE_REG]
        READ  R3, GFX_MODE_B
        CMP   R2, R3
        JZ    _gfx_scroll_right_fast_b

        ; Tila C: amount / 2 (vain jos jaollinen)
        READ  R3, 2
        CPY   R4, R12
        DIV   R4, R3                  ; R4 = word_shift
        CPY   R5, R4
        MUL   R5, R3                  ; R5 = word_shift * 2
        CPY   R6, R12
        SUB   R6, R5                  ; R6 = amount % 2
        READ  R7, 0
        CMP   R6, R7
        JNZ   _gfx_scroll_right_loop
        CPY   R12, R4                 ; R12 = word_shift
        JUMP  _gfx_scroll_right_fast

_gfx_scroll_right_fast_b:
        ; Tila B: R12 (px) == word_shift
_gfx_scroll_right_fast:
        READ  R4, VRAM_START          ; row_base
        READ  R5, 0                   ; row_idx
        READ  R6, 24                  ; VRAM-rivien maara (molemmissa tiloissa)

_gfx_scroll_right_fast_row:
        CMP   R5, R6
        JGE   _gfx_scroll_right_done

        ; COPY [row_base .. row_base + (79 - shift)] -> row_base + shift
        CPY   R0, R4
        CPY   R1, R4
        READ  R2, 79
        ADD   R1, R2
        SUB   R1, R12
        CPY   R2, R4
        ADD   R2, R12
        COPY  R0, R1, R2

        ; FILL [row_base .. row_base + shift - 1] = 0
        CPY   R0, R4
        CPY   R1, R4
        ADD   R1, R12
        READ  R2, 1
        SUB   R1, R2
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R0, 80
        ADD   R4, R0
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gfx_scroll_right_fast_row

_gfx_scroll_right_loop:
        READ  R4, 0                   ; y
_gfx_scroll_right_y:
        CMP   R4, R11
        JGE   _gfx_scroll_right_done

        CPY   R5, R10
        READ  R0, 1
        SUB   R5, R0                  ; x = w - 1
_gfx_scroll_right_x:
        READ  R0, 0
        CMP   R5, R0
        JLT   _gfx_scroll_right_next_y
        CPY   R6, R5
        SUB   R6, R12                 ; src_x = x - amount
        READ  R0, 0
        CMP   R6, R0
        JLT   _gfx_scroll_right_clear

        CPY   R0, R6
        CPY   R1, R4
        CALL  _gfx_get_pixel
        CPY   R2, R0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel
        JUMP  _gfx_scroll_right_dec_x

_gfx_scroll_right_clear:
        READ  R2, 0
        CPY   R0, R5
        CPY   R1, R4
        CALL  _gfx_put_pixel

_gfx_scroll_right_dec_x:
        READ  R0, 1
        SUB   R5, R0
        JUMP  _gfx_scroll_right_x

_gfx_scroll_right_next_y:
        READ  R0, 1
        ADD   R4, R0
        JUMP  _gfx_scroll_right_y

_gfx_scroll_right_done:
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

; =============================================================================
; gfx_draw_text_small — Piirrä 4x5 heksateksti (0-9, A-F)
;
; Sisään:  R0 = merkkijonon osoite (null-terminoitu)
;          R1 = x
;          R2 = y
; Ulos:    —
; Clobbers: R0–R12
;
; Tuntemattomat merkit käsitellään välilyöntinä.
; =============================================================================

gfx_draw_text_small:
        PUSH  R13
        PUSH  R14
        CPY   R13, R0                 ; str ptr
        CPY   R14, R1                 ; cursor x
        CPY   R12, R2                 ; base y

_gdt_next_char:
        READ  R0, [R13]
        READ  R1, 0
        CMP   R0, R1
        JZ    _gdt_done

        CALL  font_small_get_glyph    ; R0=ptr, R1=valid
        READ  R2, 0
        CMP   R1, R2
        JZ    _gdt_advance

        CPY   R11, R0                 ; glyph ptr
        READ  R10, 0                  ; row
_gdt_row:
        READ  R0, 5
        CMP   R10, R0
        JGE   _gdt_advance

        READ  R9, [R11]               ; row bits
        READ  R8, 0                   ; col
_gdt_col:
        READ  R0, 4
        CMP   R8, R0
        JGE   _gdt_next_row

        READ  R0, 3
        SUB   R0, R8                  ; shift = 3-col
        CPY   R1, R9
        SHR   R1, R0
        READ  R0, 1
        AND   R1, R0
        READ  R0, 0
        CMP   R1, R0
        JZ    _gdt_inc_col

        CPY   R0, R14
        ADD   R0, R8
        CPY   R1, R12
        ADD   R1, R10

        ; Tallenna silmukkatilat gfx_pixel-kutsun yli
        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        PUSH  R14
        CALL  gfx_pixel
        POP   R14
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8

_gdt_inc_col:
        READ  R0, 1
        ADD   R8, R0
        JUMP  _gdt_col

_gdt_next_row:
        READ  R0, 1
        ADD   R10, R0
        ADD   R11, R0
        JUMP  _gdt_row

_gdt_advance:
        ; 1 pikseli väli glyphien väliin
        READ  R0, 5
        ADD   R14, R0
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gdt_next_char

_gdt_done:
        POP   R14
        POP   R13
        RET

; =============================================================================
; gfx_draw_text_big — Piirrä 6x8 BIG-teksti (0-9, :, ., valilyonti)
;
; Sisään:  R0 = merkkijonon osoite (null-terminoitu)
;          R1 = x
;          R2 = y
; Ulos:    —
; Clobbers: R0–R14
;
; Tuntemattomat merkit käsitellään valilyöntinä.
; =============================================================================

gfx_draw_text_big:
        PUSH  R13
        PUSH  R14
        CPY   R13, R0                 ; str ptr
        CPY   R14, R1                 ; cursor x
        CPY   R12, R2                 ; base y

_gdtb_next_char:
        READ  R0, [R13]
        READ  R1, 0
        CMP   R0, R1
        JZ    _gdtb_done

        ; Muunna merkki BIG_FONT-indeksiksi (0..12)
        READ  R1, 48                  ; '0'
        CMP   R0, R1
        JLT   _gdtb_check_colon
        READ  R1, 57                  ; '9'
        CMP   R0, R1
        JGT   _gdtb_check_colon
        READ  R1, 48
        SUB   R0, R1                  ; 0..9
        JUMP  _gdtb_have_idx

_gdtb_check_colon:
        READ  R1, 58                  ; ':'
        CMP   R0, R1
        JNZ   _gdtb_check_dot
        READ  R0, 10
        JUMP  _gdtb_have_idx

_gdtb_check_dot:
        READ  R1, 46                  ; '.'
        CMP   R0, R1
        JNZ   _gdtb_check_space
        READ  R0, 11
        JUMP  _gdtb_have_idx

_gdtb_check_space:
        READ  R1, 32                  ; ' '
        CMP   R0, R1
        JNZ   _gdtb_unknown
        READ  R0, 12
        JUMP  _gdtb_have_idx

_gdtb_unknown:
        READ  R0, 12                  ; valilyonti fallback

_gdtb_have_idx:
        ; glyph_ptr = BIG_FONT + idx * BIG_WORDS_PER_CHAR
        READ  R1, BIG_WORDS_PER_CHAR
        MUL   R0, R1
        READ  R1, BIG_FONT
        ADD   R0, R1
        CPY   R11, R0                 ; glyph ptr

        READ  R10, 0                  ; row idx
_gdtb_row:
        READ  R0, BIG_CHAR_H
        CMP   R10, R0
        JGE   _gdtb_advance

        READ  R9, [R11]               ; row bits
        READ  R8, 0                   ; col idx
_gdtb_col:
        READ  R0, BIG_CHAR_W
        CMP   R8, R0
        JGE   _gdtb_next_row

        READ  R0, 5
        SUB   R0, R8                  ; shift = 5-col
        CPY   R1, R9
        SHR   R1, R0
        READ  R0, 1
        AND   R1, R0
        READ  R0, 0
        CMP   R1, R0
        JZ    _gdtb_inc_col

        CPY   R0, R14
        ADD   R0, R8
        CPY   R1, R12
        ADD   R1, R10

        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        PUSH  R14
        CALL  gfx_pixel
        POP   R14
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8

_gdtb_inc_col:
        READ  R0, 1
        ADD   R8, R0
        JUMP  _gdtb_col

_gdtb_next_row:
        READ  R0, 1
        ADD   R10, R0
        ADD   R11, R0
        JUMP  _gdtb_row

_gdtb_advance:
        ; 1 px valitys merkkien valiin
        READ  R0, 7
        ADD   R14, R0
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gdtb_next_char

_gdtb_done:
        POP   R14
        POP   R13
        RET

; =============================================================================
; gfx_sprite_xor_1bpp_64x32 — XOR-piirto 64x32 1bpp framebufferiin
;
; Sisään:  R0 = fb_base (64x32, 1 sana / pikseli)
;          R1 = x (0..63)
;          R2 = y (0..31)
;          R3 = sprite_ptr (N tavua / sanaa)
;          R4 = N (rivikorkeus)
; Ulos:    R0 = collision (0/1)
; Clobbers: R0–R12
; =============================================================================

gfx_sprite_xor_1bpp_64x32:
        CPY   R12, R0                 ; fb base
        READ  R10, 0x003F
        AND   R1, R10
        READ  R10, 0x001F
        AND   R2, R10
        READ  R0, 0                   ; collision = 0

        READ  R9, 0                   ; row index
_gcs_row:
        CMP   R9, R4
        JGE   _gcs_done

        READ  R8, [R3]                ; sprite byte
        READ  R11, 1
        ADD   R3, R11

        CPY   R7, R2
        ADD   R7, R9
        READ  R10, 0x001F
        AND   R7, R10                 ; sy

        READ  R6, 0                   ; bit index
_gcs_bit:
        READ  R10, 8
        CMP   R6, R10
        JGE   _gcs_next_row

        READ  R10, 0x0080
        SHR   R10, R6
        CPY   R5, R8
        AND   R5, R10
        READ  R10, 0
        CMP   R5, R10
        JZ    _gcs_inc_bit

        CPY   R5, R1
        ADD   R5, R6
        READ  R10, 0x003F
        AND   R5, R10                 ; sx

        CPY   R10, R7
        READ  R11, 6
        SHL   R10, R11
        ADD   R10, R5
        ADD   R10, R12                ; addr

        READ  R11, [R10]
        READ  R5, 1
        CMP   R11, R5
        JNZ   _gcs_xor
        READ  R0, 1                   ; collision = 1

_gcs_xor:
        READ  R5, 1
        XOR   R11, R5
        STORE [R10], R11

_gcs_inc_bit:
        READ  R10, 1
        ADD   R6, R10
        JUMP  _gcs_bit

_gcs_next_row:
        READ  R10, 1
        ADD   R9, R10
        JUMP  _gcs_row

_gcs_done:
        RET
