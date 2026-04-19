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
;   gfx_fill_screen   — Täytä koko näyttö pikseliarvolla 0/1 mahdollisimman nopeasti
;   gfx_clear         — Tyhjennä näyttö (nollaa koko VRAM)
;   gfx_flip          — Flipaa kaksoisbufferointi (triggeroi näytönpäivitys)
;   gfx_set_draw_mode — Aseta piirtotila (R0 = piirtotila)
;   gfx_rect          — Piirrä suorakaide (R0=x, R1=y, R2=w, R3=h, R4=filled, R5=draw_mode)
;   gfx_circle        — Piirrä ympyrä (R0=cx, R1=cy, R2=radius, R3=filled, R4=draw_mode)
;   gfx_scroll_up     — Scrollaa kuvaa ylöspäin (R0 = 1..15 px)
;   gfx_scroll_down   — Scrollaa kuvaa alaspäin (R0 = 1..15 px)
;   gfx_scroll_left   — Scrollaa kuvaa vasemmalle (R0 = 1..15 px)
;   gfx_scroll_right  — Scrollaa kuvaa oikealle (R0 = 1..15 px)
;   gfx_step_towards_point_1px — Siirrä pistetta yksi pikseli/frame kohti kohdetta
;   gfx_pixel         — Piirra pikseli (R0=x, R1=y)
;   gfx_line          — Piirrä viiva (R0=x0, R1=y0, R2=x1, R3=y1)
;   gfx_draw_char_big — Piirrä yksi 6x8 BIG-merkki tavuarvosta 0x00..0xFF
;   gfx_draw_text_big — Piirrä 6x8 BIG-teksti (0x01..0xFF; 0x00 paattaa merkkijonon)
;   gfx_sprite8_reset_all — Tyhjennä kaikki 16 kiintean 8x8 sprite-slotia
;   gfx_sprite8_set_bitmap — Aseta 8x8 spritebitmapin osoite
;   gfx_sprite8_set_pos — Aseta 8x8 spriten sijainti [x, y]
;   gfx_sprite8_set_draw_mode — Aseta spritepiirtotapa 0/1/XOR
;   gfx_sprite8_set_visible — Aseta spriten näkyvyys 0/1
;   gfx_sprite8_set_collision_check — Aseta kiintean 8x8 bounding box -törmäystarkistus 0/1
;   gfx_sprite8_get_collision — Lue viimeisin automaattinen 8x8 bounding box -törmäystulos
;   gfx_sprite8_update_collisions — Päivitä spritejen automaattiset 8x8 bounding box -törmäykset
;
; PIIRTOTILAT (gfx_set_draw_mode:n R0-arvo):
;   GFX_DRAW_XOR (0) — XOR-tila: vaihtaa pikselin tilaa (oletus)
;   GFX_DRAW_FG  (1) — Etuväri:   asettaa pikselin päälle
;   GFX_DRAW_BG  (2) — Taustaväri: nollaa pikselin
;
; REKISTERIKÄYTTÖ (clobbers):
;   gfx_fill_screen:   R0–R3
;   gfx_clear:         R0–R3
;   gfx_flip:          R0
;   gfx_set_draw_mode: —
;   gfx_rect:          R0–R15
;   gfx_circle:        R0–R15
;   gfx_scroll_*:      R0–R12
;   gfx_step_towards_point_1px: R0–R7
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
;   GFX_SCROLL_CMD_REG = 0xFF82 (visible->VRAM scroll-komento)

; Piirtotilat (käytetään gfx_set_draw_mode-funktiolle)
.const GFX_DRAW_XOR, 0     ; XOR-tila: vaihtaa pikselin tilaa (oletus)
.const GFX_DRAW_FG,  1     ; Etuväri:   asettaa pikselin päälle
.const GFX_DRAW_BG,  2     ; Taustaväri: nollaa pikselin
.const GFX_SPRITE8_COUNT, 16
.const GFX_SPRITE8_SIZE, 8   ; kiintea spritekoko ja collision-bboxin sivun pituus
.const GFX_SPRITE_DRAW_0,   0
.const GFX_SPRITE_DRAW_1,   1
.const GFX_SPRITE_DRAW_XOR, 2
.const GFX_SCROLL_DIR_UP,    0
.const GFX_SCROLL_DIR_DOWN,  1
.const GFX_SCROLL_DIR_LEFT,  2
.const GFX_SCROLL_DIR_RIGHT, 3

; Huom: VRAM_START (0xF800), VRAM_WORDS (1920), INT_BREAKPOINT (3),
; GFX_MODE_REG, GFX_MODE_A/B/C, GFX_FLIP_REG ja GFX_SCROLL_CMD_REG ovat
; arkkitehtuurivakioita
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
gfx_sprite8_x:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_y:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_bitmap:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_draw_mode:
        .dw 1, 1, 1, 1, 1, 1, 1, 1
        .dw 1, 1, 1, 1, 1, 1, 1, 1
gfx_sprite8_visible:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_collision_check:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_collision_flag:
        .dw 0, 0, 0, 0, 0, 0, 0, 0
        .dw 0, 0, 0, 0, 0, 0, 0, 0
gfx_sprite8_data_end:

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
; nykyisen VRAMin etupuskuriin ja päivittää näytön atomisesti. Ennen flipiä
; näkyvät 8x8-spritet piirretään taustapuskuriin slot-järjestyksessä 0..15.
; Rekisteri nollataan automaattisesti flipin jälkeen.
;
; Kutsu tämä kun koko kehys on piirretty (gfx_clear + piirtokäskyt).
; Ei vaikutusta tekstitilassa A — kaksoisbufferointi on vain tiloissa B ja C.
; =============================================================================

gfx_flip:
        READ  R1, [gfx_flip_enabled]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gfx_flip_done
        CALL  _gfx_sprite8_render_all
        READ  R0, 1
        STORE [GFX_FLIP_REG], R0
_gfx_flip_done:
        RET

; =============================================================================
; gfx_scroll_up / down / left / right — Scrollaa näkyvää kehystä takaisin VRAMiin
;
; Sisään:  R0 = amount (1..15 px)
; Ulos:    —
; Clobbers: R0–R2
; =============================================================================

_gfx_scroll_visible_common:
        READ  R2, 0
        CMP   R0, R2
        JZ    _gfx_scroll_done
        READ  R2, 8
        SHL   R1, R2
        OR    R0, R1
        STORE [GFX_SCROLL_CMD_REG], R0
_gfx_scroll_done:
        RET

gfx_scroll_up:
        READ  R1, GFX_SCROLL_DIR_UP
        JUMP  _gfx_scroll_visible_common

gfx_scroll_down:
        READ  R1, GFX_SCROLL_DIR_DOWN
        JUMP  _gfx_scroll_visible_common

gfx_scroll_left:
        READ  R1, GFX_SCROLL_DIR_LEFT
        JUMP  _gfx_scroll_visible_common

gfx_scroll_right:
        READ  R1, GFX_SCROLL_DIR_RIGHT
        JUMP  _gfx_scroll_visible_common

; =============================================================================
; gfx_fill_screen — Täytä koko grafiikkanäyttö pikseliarvolla 0/1
;
; Sisään:  R0 = 0 -> kaikki pikselit pois, muu -> kaikki pikselit paalle
; Ulos:    —
; Clobbers: R0–R3
;
; Toteutus valitsee aktiivisen grafiikkatilan mukaisen VRAM-täytesanan ja
; käyttää yhtä FILL-käskyä koko ruudun yli.
;   Tila B: 0x0000 / 0x0003
;   Tila C: 0x0000 / 0x00FF
; Tekstitila A laukaisee INT INT_BREAKPOINT kuten muutkin gfx-rutiinit.
; =============================================================================

gfx_fill_screen:
        READ  R1, [GFX_MODE_REG]
        READ  R2, 0
        CMP   R1, R2
        JNZ   _gfx_fill_screen_mode_ok
        INT   INT_BREAKPOINT
_gfx_fill_screen_mode_ok:
        READ  R2, 0
        CMP   R0, R2
        JZ    _gfx_fill_screen_zero

        READ  R2, GFX_MODE_B
        CMP   R1, R2
        JZ    _gfx_fill_screen_mode_b
        READ  R2, 0x00FF
        JUMP  _gfx_fill_screen_do
_gfx_fill_screen_mode_b:
        READ  R2, 0x0003
        JUMP  _gfx_fill_screen_do

_gfx_fill_screen_zero:
        READ  R2, 0

_gfx_fill_screen_do:
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        FILL  R0, R1, R2
        RET

; =============================================================================
; gfx_clear — Tyhjennä grafiikkanäyttö
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R3
;
; Nollaa kaikki 1920 VRAM-sanaa ($F800–$FF7F) kutsumalla gfx_fill_screen.
; Huom: toiminto ohittaa gfx_draw_mode — tyhjentää aina taustaan.
; Laukaisee INT INT_BREAKPOINT (INT 3) jos näyttötila on A ($FF80 = 0).
; =============================================================================

gfx_clear:
        READ  R0, 0
        JUMP  gfx_fill_screen

; =============================================================================
; gfx_step_towards_point_1px — Siirrä pistettä yksi pikseli kohti kohdetta
;
; Sisään:  R0 = x, R1 = y, R2 = target_x, R3 = target_y
; Ulos:    R0 = uusi x, R1 = uusi y, R2 = 1 jos kohde saavutettu, muuten 0
; Clobbers: R0–R7
;
; Liike on korkeintaan yksi pikseli per frame. Jos sekä x- että y-etäisyys ovat
; ei-nollia, askel otetaan suuremman etäisyyden akselilla. Tasatilanteessa x
; priorisoidaan. Tätä voi käyttää spritejen deterministiseen 1 px/frame
; liikkeeseen ilman kahden akselin samanaikaista askelta.
; =============================================================================

gfx_step_towards_point_1px:
        CPY   R4, R0                  ; x
        CPY   R5, R1                  ; y
        CPY   R6, R2                  ; target_x
        CPY   R7, R3                  ; target_y

        CMP   R4, R6
        JNZ   _gstp_need_step
        CMP   R5, R7
        JNZ   _gstp_need_step
        CPY   R0, R4
        CPY   R1, R5
        READ  R2, 1
        RET

_gstp_need_step:
        CPY   R0, R6
        SUB   R0, R4                  ; dx
        CPY   R1, R7
        SUB   R1, R5                  ; dy

        CPY   R2, R0                  ; abs(dx)
        READ  R3, 0
        CMP   R2, R3
        JGE   _gstp_dx_abs_ok
        NOT   R2
        READ  R3, 1
        ADD   R2, R3
_gstp_dx_abs_ok:
        CPY   R3, R1                  ; abs(dy)
        READ  R0, 0
        CMP   R3, R0
        JGE   _gstp_dy_abs_ok
        NOT   R3
        READ  R0, 1
        ADD   R3, R0
_gstp_dy_abs_ok:
        CMP   R2, R3
        JLT   _gstp_step_y
        CMP   R4, R6
        JNZ   _gstp_step_x

_gstp_step_y:
        CMP   R5, R7
        JGT   _gstp_step_y_dec
        READ  R0, 1
        ADD   R5, R0
        JUMP  _gstp_finish
_gstp_step_y_dec:
        READ  R0, 1
        SUB   R5, R0
        JUMP  _gstp_finish

_gstp_step_x:
        CMP   R4, R6
        JGT   _gstp_step_x_dec
        READ  R0, 1
        ADD   R4, R0
        JUMP  _gstp_finish
_gstp_step_x_dec:
        READ  R0, 1
        SUB   R4, R0

_gstp_finish:
        CPY   R0, R4
        CPY   R1, R5
        READ  R2, 0
        CMP   R4, R6
        JNZ   _gstp_done
        CMP   R5, R7
        JNZ   _gstp_done
        READ  R2, 1
_gstp_done:
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
        JZ    _gfx_get_pixel_b_bounds

        READ  R3, 160
        CMP   R0, R3
        JGE   _gfx_get_oob
        READ  R3, 96
        CMP   R1, R3
        JGE   _gfx_get_oob

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

_gfx_get_pixel_b_bounds:
        READ  R3, 80
        CMP   R0, R3
        JGE   _gfx_get_oob
        READ  R3, 48
        CMP   R1, R3
        JGE   _gfx_get_oob
        JUMP  _gfx_get_pixel_b

_gfx_get_oob:
        READ  R0, 0
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
        JZ    _gfx_put_pixel_b_bounds

        READ  R4, 160
        CMP   R0, R4
        JGE   _gfx_put_oob
        READ  R4, 96
        CMP   R1, R4
        JGE   _gfx_put_oob

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

_gfx_put_pixel_b_bounds:
        READ  R4, 80
        CMP   R0, R4
        JGE   _gfx_put_oob
        READ  R4, 48
        CMP   R1, R4
        JGE   _gfx_put_oob
        JUMP  _gfx_put_pixel_b

_gfx_put_oob:
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
; _gfx_hspan — Piirrä vaakasuuntainen pikselijono nykyisellä piirtotilalla
;
; Sisään:  R0 = x0, R1 = x1, R2 = y
; Ulos:    —
; Clobbers: R0–R12
; =============================================================================

_gfx_hspan:
        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12

        CPY   R8, R0
        CPY   R9, R1
        CPY   R10, R2
        CMP   R8, R9
        JLE   _gfx_hspan_ordered
        CPY   R11, R8
        CPY   R8, R9
        CPY   R9, R11

_gfx_hspan_ordered:
        CPY   R11, R8
_gfx_hspan_loop:
        CMP   R11, R9
        JGT   _gfx_hspan_done
        CPY   R0, R11
        CPY   R1, R10
        CALL  gfx_pixel
        READ  R0, 1
        ADD   R11, R0
        JUMP  _gfx_hspan_loop

_gfx_hspan_done:
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8
        RET

; =============================================================================
; gfx_rect — Piirrä suorakaide
;
; Sisään:  R0 = x, R1 = y, R2 = leveys, R3 = korkeus
;          R4 = 0 -> ääriviiva, muu -> täytetty
;          R5 = piirtotila (GFX_DRAW_XOR / GFX_DRAW_FG / GFX_DRAW_BG)
; Ulos:    —
; Clobbers: R0–R15
; =============================================================================

gfx_rect:
        READ  R6, 0
        CMP   R2, R6
        JLE   _gfx_rect_done
        CMP   R3, R6
        JLE   _gfx_rect_done

        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        PUSH  R14

        READ  R8, [gfx_draw_mode]
        STORE [gfx_draw_mode], R5

        CPY   R9, R0                  ; x0
        CPY   R10, R1                 ; y0

        CPY   R11, R0                 ; x1
        ADD   R11, R2
        READ  R6, 1
        SUB   R11, R6

        CPY   R12, R1                 ; y1
        ADD   R12, R3
        SUB   R12, R6

        READ  R6, 0
        CMP   R4, R6
        JZ    _gfx_rect_outline

        CPY   R13, R10                ; current y
_gfx_rect_fill_loop:
        CMP   R13, R12
        JGT   _gfx_rect_restore
        CPY   R0, R9
        CPY   R1, R11
        CPY   R2, R13
        CALL  _gfx_hspan
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gfx_rect_fill_loop

_gfx_rect_outline:
        CPY   R0, R9
        CPY   R1, R11
        CPY   R2, R10
        CALL  _gfx_hspan

        CMP   R12, R10
        JZ    _gfx_rect_restore

        CPY   R0, R9
        CPY   R1, R11
        CPY   R2, R12
        CALL  _gfx_hspan

        CPY   R13, R10
        READ  R0, 1
        ADD   R13, R0                 ; y = y0 + 1
        CPY   R14, R12
        SUB   R14, R0                 ; y_end = y1 - 1

_gfx_rect_side_loop:
        CMP   R13, R14
        JGT   _gfx_rect_restore

        CPY   R0, R9
        CPY   R1, R13
        CALL  gfx_pixel

        CMP   R11, R9
        JZ    _gfx_rect_side_next
        CPY   R0, R11
        CPY   R1, R13
        CALL  gfx_pixel

_gfx_rect_side_next:
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gfx_rect_side_loop

_gfx_rect_restore:
        STORE [gfx_draw_mode], R8
        POP   R14
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8
_gfx_rect_done:
        RET

; =============================================================================
; _gfx_circle_plot_outline — Piirrä ympyrän symmetriapisteet ilman duplikaatteja
;
; Käyttää seuraavia rekistereitä kutsujalta:
;   R9 = cx, R10 = cy, R11 = x, R12 = y
; =============================================================================

_gfx_circle_plot_outline:
        READ  R0, 0
        CMP   R12, R0
        JZ    _gfx_circle_outline_y0
        CMP   R11, R12
        JZ    _gfx_circle_outline_diag

        CPY   R0, R9
        ADD   R0, R11
        CPY   R1, R10
        ADD   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R10
        ADD   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        ADD   R0, R11
        CPY   R1, R10
        SUB   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R10
        SUB   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        ADD   R0, R12
        CPY   R1, R10
        ADD   R1, R11
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R12
        CPY   R1, R10
        ADD   R1, R11
        CALL  gfx_pixel

        CPY   R0, R9
        ADD   R0, R12
        CPY   R1, R10
        SUB   R1, R11
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R12
        CPY   R1, R10
        SUB   R1, R11
        CALL  gfx_pixel
        RET

_gfx_circle_outline_y0:
        CPY   R0, R9
        ADD   R0, R11
        CPY   R1, R10
        CALL  gfx_pixel

        READ  R0, 0
        CMP   R11, R0
        JZ    _gfx_circle_outline_done

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R10
        CALL  gfx_pixel

        CPY   R0, R9
        CPY   R1, R10
        ADD   R1, R11
        CALL  gfx_pixel

        CPY   R0, R9
        CPY   R1, R10
        SUB   R1, R11
        CALL  gfx_pixel
_gfx_circle_outline_done:
        RET

_gfx_circle_outline_diag:
        CPY   R0, R9
        ADD   R0, R11
        CPY   R1, R10
        ADD   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R10
        ADD   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        ADD   R0, R11
        CPY   R1, R10
        SUB   R1, R12
        CALL  gfx_pixel

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R10
        SUB   R1, R12
        CALL  gfx_pixel
        RET

; =============================================================================
; _gfx_circle_plot_filled — Piirrä täytetyn ympyrän symmetriaspanit
;
; Käyttää seuraavia rekistereitä kutsujalta:
;   R9 = cx, R10 = cy, R11 = x, R12 = y
; =============================================================================

_gfx_circle_plot_filled:
        READ  R0, 0
        CMP   R12, R0
        JZ    _gfx_circle_filled_y0
        CMP   R11, R12
        JZ    _gfx_circle_filled_diag

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R9
        ADD   R1, R11
        CPY   R2, R10
        ADD   R2, R12
        CALL  _gfx_hspan

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R9
        ADD   R1, R11
        CPY   R2, R10
        SUB   R2, R12
        CALL  _gfx_hspan

        CPY   R0, R9
        SUB   R0, R12
        CPY   R1, R9
        ADD   R1, R12
        CPY   R2, R10
        ADD   R2, R11
        CALL  _gfx_hspan

        CPY   R0, R9
        SUB   R0, R12
        CPY   R1, R9
        ADD   R1, R12
        CPY   R2, R10
        SUB   R2, R11
        CALL  _gfx_hspan
        RET

_gfx_circle_filled_y0:
        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R9
        ADD   R1, R11
        CPY   R2, R10
        CALL  _gfx_hspan

        READ  R0, 0
        CMP   R11, R0
        JZ    _gfx_circle_filled_done

        CPY   R0, R9
        CPY   R1, R9
        CPY   R2, R10
        ADD   R2, R11
        CALL  _gfx_hspan

        CPY   R0, R9
        CPY   R1, R9
        CPY   R2, R10
        SUB   R2, R11
        CALL  _gfx_hspan
_gfx_circle_filled_done:
        RET

_gfx_circle_filled_diag:
        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R9
        ADD   R1, R11
        CPY   R2, R10
        ADD   R2, R12
        CALL  _gfx_hspan

        CPY   R0, R9
        SUB   R0, R11
        CPY   R1, R9
        ADD   R1, R11
        CPY   R2, R10
        SUB   R2, R12
        CALL  _gfx_hspan
        RET

; =============================================================================
; gfx_circle — Piirrä ympyrä
;
; Sisään:  R0 = cx, R1 = cy, R2 = säde
;          R3 = 0 -> ääriviiva, muu -> täytetty
;          R4 = piirtotila (GFX_DRAW_XOR / GFX_DRAW_FG / GFX_DRAW_BG)
; Ulos:    —
; Clobbers: R0–R15
; =============================================================================

gfx_circle:
        READ  R5, 0
        CMP   R2, R5
        JGE   _gfx_circle_start
        RET

_gfx_circle_start:
        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        PUSH  R14
        PUSH  R15

        READ  R8, [gfx_draw_mode]
        STORE [gfx_draw_mode], R4

        CPY   R9, R0                  ; cx
        CPY   R10, R1                 ; cy
        CPY   R11, R2                 ; x = radius
        READ  R12, 0                  ; y = 0
        READ  R13, 1
        SUB   R13, R11                ; err = 1 - radius
        CPY   R14, R3                 ; filled flag

_gfx_circle_loop:
        CMP   R11, R12
        JLT   _gfx_circle_restore

        READ  R0, 0
        CMP   R14, R0
        JZ    _gfx_circle_outline_step
        CALL  _gfx_circle_plot_filled
        JUMP  _gfx_circle_after_plot

_gfx_circle_outline_step:
        CALL  _gfx_circle_plot_outline

_gfx_circle_after_plot:
        READ  R0, 1
        ADD   R12, R0                 ; y++

        READ  R0, 0
        CMP   R13, R0
        JLT   _gfx_circle_err_neg

        READ  R0, 1
        SUB   R11, R0                 ; x--
        CPY   R15, R12
        SUB   R15, R11                ; y - x
        READ  R0, 1
        SHL   R15, R0                 ; 2 * (y - x)
        READ  R0, 1
        ADD   R15, R0                 ; 2 * (y - x) + 1
        ADD   R13, R15
        JUMP  _gfx_circle_loop

_gfx_circle_err_neg:
        CPY   R15, R12
        READ  R0, 1
        SHL   R15, R0                 ; 2 * y
        READ  R0, 1
        ADD   R15, R0                 ; 2 * y + 1
        ADD   R13, R15
        JUMP  _gfx_circle_loop

_gfx_circle_restore:
        STORE [gfx_draw_mode], R8
        POP   R15
        POP   R14
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8
        RET

; =============================================================================
; gfx_draw_char_big — Piirrä yksi 6x8 BIG-merkki tavuarvosta 0x00..0xFF
;
; Sisään:  R0 = tavuarvo / merkki
;          R1 = x
;          R2 = y
; Ulos:    —
; Clobbers: R0–R14
; =============================================================================

gfx_draw_char_big:
        PUSH  R13
        PUSH  R14
        CPY   R13, R1                 ; base x
        CPY   R12, R2                 ; base y

        CALL  font_big_get_glyph      ; R0 = glyph ptr
        CPY   R11, R0                 ; glyph ptr

        READ  R10, 0                  ; row idx
_gdcb_row:
        READ  R0, BIG_CHAR_H
        CMP   R10, R0
        JGE   _gdcb_done

        READ  R9, [R11]               ; row bits
        READ  R8, 0                   ; col idx
_gdcb_col:
        READ  R0, BIG_CHAR_W
        CMP   R8, R0
        JGE   _gdcb_next_row

        READ  R0, 5
        SUB   R0, R8                  ; shift = 5-col
        CPY   R1, R9
        SHR   R1, R0
        READ  R0, 1
        AND   R1, R0
        READ  R0, 0
        CMP   R1, R0
        JZ    _gdcb_inc_col

        CPY   R0, R13
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

_gdcb_inc_col:
        READ  R0, 1
        ADD   R8, R0
        JUMP  _gdcb_col

_gdcb_next_row:
        READ  R0, 1
        ADD   R10, R0
        ADD   R11, R0
        JUMP  _gdcb_row

_gdcb_done:
        POP   R14
        POP   R13
        RET

; =============================================================================
; gfx_draw_text_big — Piirrä 6x8 BIG-teksti (0x01..0xFF; 0x00 päättää)
;
; Sisään:  R0 = merkkijonon osoite (null-terminoitu)
;          R1 = x
;          R2 = y
; Ulos:    —
; Clobbers: R0–R14
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

        PUSH  R12
        PUSH  R13
        PUSH  R14
        CPY   R1, R14
        CPY   R2, R12
        CALL  gfx_draw_char_big
        POP   R14
        POP   R13
        POP   R12

        READ  R0, 7
        ADD   R14, R0
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gdtb_next_char

_gdtb_done:
        POP   R14
        POP   R13
        RET

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
        JZ    _gfx_pixel_b_bounds

        READ  R3, 160
        CMP   R0, R3
        JGE   _gfx_pixel_oob
        READ  R3, 96
        CMP   R1, R3
        JGE   _gfx_pixel_oob

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

_gfx_pixel_b_bounds:
        READ  R3, 80
        CMP   R0, R3
        JGE   _gfx_pixel_oob
        READ  R3, 48
        CMP   R1, R3
        JGE   _gfx_pixel_oob
        JUMP  _gfx_pixel_b

_gfx_pixel_oob:
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
; _gfx_sprite8_bbox_overlap — 8x8 bounding box -tormaystesti
;
; Sisään:  R0 = ax, R1 = ay, R2 = bx, R3 = by
; Ulos:    R0 = 1 jos overlap, muuten 0
; Clobbers: R4–R6
; =============================================================================

_gfx_sprite8_bbox_overlap:
        READ  R4, GFX_SPRITE8_SIZE
        CPY   R5, R0
        ADD   R5, R4
        CPY   R6, R2
        ADD   R6, R4
        CMP   R5, R2
        JLE   _gs8bo_no
        CMP   R6, R0
        JLE   _gs8bo_no

        CPY   R5, R1
        ADD   R5, R4
        CPY   R6, R3
        ADD   R6, R4
        CMP   R5, R3
        JLE   _gs8bo_no
        CMP   R6, R1
        JLE   _gs8bo_no
        READ  R0, 1
        RET
_gs8bo_no:
        READ  R0, 0
        RET

; =============================================================================
; _gfx_sprite8_draw_one — Piirrä yksi 8x8 sprite nykyisellä piirtotilalla
;
; Sisään:  R0 = x, R1 = y, R2 = bitmap_ptr
; Ulos:    —
; Clobbers: R0–R9
; =============================================================================

_gfx_sprite8_draw_one:
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R9

        CPY   R7, R0
        CPY   R8, R1
        CPY   R9, R2
        READ  R6, 0
_gs8do_row:
        READ  R0, GFX_SPRITE8_SIZE
        CMP   R6, R0
        JGE   _gs8do_done

        READ  R5, [R9]
        READ  R0, 1
        ADD   R9, R0

        READ  R4, 0
_gs8do_bit:
        READ  R0, GFX_SPRITE8_SIZE
        CMP   R4, R0
        JGE   _gs8do_next_row

        READ  R0, 0x0080
        SHR   R0, R4
        CPY   R3, R5
        AND   R3, R0
        READ  R0, 0
        CMP   R3, R0
        JZ    _gs8do_inc_bit

        CPY   R0, R7
        ADD   R0, R4
        CPY   R1, R8
        ADD   R1, R6
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R9
        CALL  gfx_pixel
        POP   R9
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4

_gs8do_inc_bit:
        READ  R0, 1
        ADD   R4, R0
        JUMP  _gs8do_bit

_gs8do_next_row:
        READ  R0, 1
        ADD   R6, R0
        JUMP  _gs8do_row

_gs8do_done:
        POP   R9
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        RET

; =============================================================================
; _gfx_sprite8_map_draw_mode — Muunna spritepiirtotapa gfx_draw_mode-arvoksi
;
; Sisään:  R0 = GFX_SPRITE_DRAW_0 / _1 / _XOR
; Ulos:    R0 = GFX_DRAW_BG / _FG / _XOR
; Clobbers: R1
; =============================================================================

_gfx_sprite8_map_draw_mode:
        READ  R1, GFX_SPRITE_DRAW_1
        CMP   R0, R1
        JZ    _gs8md_fg
        READ  R1, GFX_SPRITE_DRAW_XOR
        CMP   R0, R1
        JZ    _gs8md_xor
        READ  R0, GFX_DRAW_BG
        RET
_gs8md_fg:
        READ  R0, GFX_DRAW_FG
        RET
_gs8md_xor:
        READ  R0, GFX_DRAW_XOR
        RET

; =============================================================================
; gfx_sprite8_reset_all — Tyhjennä kaikki 16 sprite-slotia
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R2
; =============================================================================

gfx_sprite8_reset_all:
        READ  R0, gfx_sprite8_x
        READ  R1, gfx_sprite8_data_end
        READ  R2, 1
        SUB   R1, R2
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R0, gfx_sprite8_draw_mode
        READ  R1, gfx_sprite8_visible
        READ  R2, 1
        SUB   R1, R2
        READ  R2, GFX_SPRITE_DRAW_1
        FILL  R0, R1, R2
        RET

; =============================================================================
; gfx_sprite8_set_bitmap — Aseta 8x8 spritebitmapin osoite
;
; Sisään:  R0 = sprite idx (0..15), R1 = bitmap_ptr
; Ulos:    —
; Clobbers: R2
; =============================================================================

gfx_sprite8_set_bitmap:
        READ  R2, GFX_SPRITE8_COUNT
        CMP   R0, R2
        JGE   _gs8sb_done
        READ  R2, gfx_sprite8_bitmap
        ADD   R2, R0
        STORE [R2], R1
_gs8sb_done:
        RET

; =============================================================================
; gfx_sprite8_set_pos — Aseta spriten sijainti [x, y]
;
; Sisään:  R0 = sprite idx (0..15), R1 = x, R2 = y
; Ulos:    —
; Clobbers: R3
; =============================================================================

gfx_sprite8_set_pos:
        READ  R3, GFX_SPRITE8_COUNT
        CMP   R0, R3
        JGE   _gs8sp_done
        READ  R3, gfx_sprite8_x
        ADD   R3, R0
        STORE [R3], R1
        READ  R3, gfx_sprite8_y
        ADD   R3, R0
        STORE [R3], R2
_gs8sp_done:
        RET

; =============================================================================
; gfx_sprite8_set_draw_mode — Aseta spritepiirtotapa 0/1/XOR
;
; Sisään:  R0 = sprite idx (0..15), R1 = GFX_SPRITE_DRAW_0 / _1 / _XOR
; Ulos:    —
; Clobbers: R2
; =============================================================================

gfx_sprite8_set_draw_mode:
        READ  R2, GFX_SPRITE8_COUNT
        CMP   R0, R2
        JGE   _gs8sd_done
        READ  R2, GFX_SPRITE_DRAW_1
        CMP   R1, R2
        JZ    _gs8sd_store
        READ  R2, GFX_SPRITE_DRAW_XOR
        CMP   R1, R2
        JZ    _gs8sd_store
        READ  R1, GFX_SPRITE_DRAW_0
_gs8sd_store:
        READ  R2, gfx_sprite8_draw_mode
        ADD   R2, R0
        STORE [R2], R1
_gs8sd_done:
        RET

; =============================================================================
; gfx_sprite8_set_visible — Aseta spriten näkyvyys 0/1
;
; Sisään:  R0 = sprite idx (0..15), R1 = 0/1
; Ulos:    —
; Clobbers: R2
; =============================================================================

gfx_sprite8_set_visible:
        READ  R2, GFX_SPRITE8_COUNT
        CMP   R0, R2
        JGE   _gs8sv_done
        READ  R2, 0
        CMP   R1, R2
        JZ    _gs8sv_store
        READ  R1, 1
_gs8sv_store:
        READ  R2, gfx_sprite8_visible
        ADD   R2, R0
        STORE [R2], R1
_gs8sv_done:
        RET

; =============================================================================
; gfx_sprite8_set_collision_check — Aseta bounding box -törmäystarkistus 0/1
;
; Sisään:  R0 = sprite idx (0..15), R1 = 0/1
; Ulos:    —
; Clobbers: R2
; =============================================================================

gfx_sprite8_set_collision_check:
        READ  R2, GFX_SPRITE8_COUNT
        CMP   R0, R2
        JGE   _gs8sc_done
        READ  R2, 0
        CMP   R1, R2
        JZ    _gs8sc_store
        READ  R1, 1
_gs8sc_store:
        READ  R2, gfx_sprite8_collision_check
        ADD   R2, R0
        STORE [R2], R1
_gs8sc_done:
        RET

; =============================================================================
; gfx_sprite8_get_collision — Lue viimeisin bounding box -törmäystulos
;
; Sisään:  R0 = sprite idx (0..15)
; Ulos:    R0 = 0/1
; Clobbers: R1
; =============================================================================

gfx_sprite8_get_collision:
        READ  R1, GFX_SPRITE8_COUNT
        CMP   R0, R1
        JGE   _gs8gc_zero
        READ  R1, gfx_sprite8_collision_flag
        ADD   R1, R0
        READ  R0, [R1]
        RET
_gs8gc_zero:
        READ  R0, 0
        RET

; =============================================================================
; gfx_sprite8_update_collisions — Päivitä kaikki 8x8 bounding box -törmäykset
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R13
; =============================================================================

gfx_sprite8_update_collisions:
        READ  R0, gfx_sprite8_collision_flag
        READ  R1, gfx_sprite8_collision_flag
        READ  R2, GFX_SPRITE8_COUNT
        ADD   R1, R2
        READ  R2, 1
        SUB   R1, R2
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R13, 0
_gs8uc_outer:
        READ  R0, GFX_SPRITE8_COUNT
        CMP   R13, R0
        JGE   _gs8uc_done

        READ  R0, gfx_sprite8_visible
        ADD   R0, R13
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_i

        READ  R0, gfx_sprite8_collision_check
        ADD   R0, R13
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_i

        READ  R0, gfx_sprite8_bitmap
        ADD   R0, R13
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_i

        READ  R0, gfx_sprite8_x
        ADD   R0, R13
        READ  R10, [R0]
        READ  R0, gfx_sprite8_y
        ADD   R0, R13
        READ  R11, [R0]

        CPY   R12, R13
        READ  R0, 1
        ADD   R12, R0
_gs8uc_inner:
        READ  R0, GFX_SPRITE8_COUNT
        CMP   R12, R0
        JGE   _gs8uc_next_i

        READ  R0, gfx_sprite8_visible
        ADD   R0, R12
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_j

        READ  R0, gfx_sprite8_collision_check
        ADD   R0, R12
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_j

        READ  R0, gfx_sprite8_bitmap
        ADD   R0, R12
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8uc_next_j

        READ  R0, gfx_sprite8_x
        ADD   R0, R12
        READ  R2, [R0]
        READ  R0, gfx_sprite8_y
        ADD   R0, R12
        READ  R3, [R0]
        CPY   R0, R10
        CPY   R1, R11
        CALL  _gfx_sprite8_bbox_overlap
        READ  R1, 0
        CMP   R0, R1
        JZ    _gs8uc_next_j

        READ  R0, gfx_sprite8_collision_flag
        ADD   R0, R13
        READ  R1, 1
        STORE [R0], R1
        READ  R0, gfx_sprite8_collision_flag
        ADD   R0, R12
        STORE [R0], R1

_gs8uc_next_j:
        READ  R0, 1
        ADD   R12, R0
        JUMP  _gs8uc_inner

_gs8uc_next_i:
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gs8uc_outer

_gs8uc_done:
        RET

; =============================================================================
; _gfx_sprite8_render_all — Renderöi näkyvät spritet slot-järjestyksessä 0..15
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0
; =============================================================================

_gfx_sprite8_render_all:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        PUSH  R14
        PUSH  R15

        READ  R14, [gfx_draw_mode]
        CALL  gfx_sprite8_update_collisions

        READ  R13, 0
_gs8r_loop:
        READ  R0, GFX_SPRITE8_COUNT
        CMP   R13, R0
        JGE   _gs8r_done

        READ  R0, gfx_sprite8_visible
        ADD   R0, R13
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _gs8r_next

        READ  R0, gfx_sprite8_bitmap
        ADD   R0, R13
        READ  R12, [R0]
        READ  R0, 0
        CMP   R12, R0
        JZ    _gs8r_next

        READ  R0, gfx_sprite8_x
        ADD   R0, R13
        READ  R10, [R0]
        READ  R0, gfx_sprite8_y
        ADD   R0, R13
        READ  R11, [R0]

        READ  R0, gfx_sprite8_draw_mode
        ADD   R0, R13
        READ  R0, [R0]
        CALL  _gfx_sprite8_map_draw_mode
        STORE [gfx_draw_mode], R0

        CPY   R0, R10
        CPY   R1, R11
        CPY   R2, R12
        CALL  _gfx_sprite8_draw_one

_gs8r_next:
        READ  R0, 1
        ADD   R13, R0
        JUMP  _gs8r_loop

_gs8r_done:
        STORE [gfx_draw_mode], R14
        POP   R15
        POP   R14
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        POP   R1
        RET
