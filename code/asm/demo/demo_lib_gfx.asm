; =============================================================================
; demo_lib_gfx.asm ? lib-gfx.asm kaikkien toimintojen esittely
; =============================================================================
;
; Jokainen sis?lt?vaihe esitell??n molemmissa grafiikkatiloissa:
;   ensin C, sitten B (yhteens? 22 vaihetta).
; Jokainen vaihe kest?? 5 s (50 x 100 ms).
; =============================================================================
; 
; GRAFIIKKATILAVAIHEET:
;   1) Kaikki demovaiheet ajetaan grafiikkatilassa B.
;   2) Kaikki demovaiheet ajetaan grafiikkatilassa C.
;   3) Aloitetaan uudelleen kohdasta 1.

; DEMOVAIHEET:
; Vaihe 1
;    Nimi: ruudun välkytys
;    Kesto: 3 sekuntia
;    Toiminta: ruutu tyhjennetään ja täytetään uudestaan kaksoispuskurointia käyttäen
;
; Vaihe 2
;    Nimi: satunnaiset pikselit
;    Kesto: 5 sekuntia
;    Toiminta: ruutuun lisätään yksittäisiä pisteitä satunnaisiin koordinaatteihin.
;
; Vaihe 3
;    Nimi: satunnaiset viivat
;    Kesto: 5 sekuntia
;    Toiminta: ruutuun lisätään satunnaisia viivoja satunnaisiin koordinaatteihin.
;
; Vaihe 4
;    Nimi: skrollaus oikealle
;    Kesto: 5 sekuntia
;    Toiminta: piirrä näytölle satunnaisia viivoja, skrollaa oikealle, piirrä uudestaan ja skrollaa uudestaan.
; Vaihe 5
;    Nimi: skrollaus vasemmalle
;    Kesto: 5 sekuntia
;    Toiminta: piirrä näytölle satunnaisia viivoja, skrollaa vasemmalle, piirrä uudestaan ja skrollaa uudestaan.
; Vaihe 6
;    Nimi: skrollaus ylös
;    Kesto: 5 sekuntia
;    Toiminta: piirrä näytölle satunnaisia viivoja, skrollaa ylös, piirrä uudestaan ja skrollaa uudestaan.
; Vaihe 7
;    Nimi: skrollaus alas
;    Kesto: 5 sekuntia
;    Toiminta: piirrä näytölle satunnaisia viivoja, skrollaa alas, piirrä uudestaan ja skrollaa uudestaan.
;
; Vaihe 8
;    Nimi: pientä tekstiä
;    Kesto: 5 sekuntia
;    Toiminta: piirrä kaikki lib-font_small.asm:n merkit näytölle yksitellen.
;
; Vaihe 9
;    Nimi: isoa tekstiä
;    Kesto: 5 sekuntia
;    Toiminta: piirrä kaikki lib-font_big.asm:n merkit näytölle yksitellen.
;
; Vaihe 10
;    Nimi: pacman sprite
;    Kesto: 5 sekuntia
;    Toiminta: piirrä näytölle PACMAN-tyylinen 8x8 sprite, joka liikkuu satunnaisiin koordinaatteisin ja toistaa tätä koko ajan.
;
; Vaihe 11
;    Nimi: sprite törmäys
;    Kesto: 30 sekuntia
;    Toiminta: piirrä näytön keskelle PACMAN-tyylinen  8x8 sprite. Joka liikkuu satunnaisiin kohtiin näytöllä, kuten vaiheessa 10. Piirrä näytön jokaiseen kulmaan HAAMU-sprite (yhteensä 4 kpl), jotka liikkuvat kohti PACMAN-spriteä. Mikä PACMAN-spriteen osuu HAAMU-sprite, HAAMU-sprite siirtyy aloituskulmaansa ja jatkaa liikkuakseen kohti PACMAN-spriteä. Näytön keskellä näkyy teksti "C0", "C1" tai "C2" sen mukaan.
;

       .origin 0x0200

        JUMP  main

        .include "../lib/lib-gfx.asm"

.const BASE_PHASE_COUNT, 11
.const PHASE_COUNT, 22
.const TICK_MS, 100
.const PHASE_TICKS, 50
.const SPRITE_FB_BASE_64X32, 0x3000

.state_text 0, 0, "gfx_clear"
.state_text 1, 0, "gfx_pixel"
.state_text 2, 0, "gfx_line"
.state_text 3, 0, "gfx_set_draw_mode"
.state_text 4, 0, "gfx_scroll_up"
.state_text 5, 0, "gfx_scroll_down"
.state_text 6, 0, "gfx_scroll_left"
.state_text 7, 0, "gfx_scroll_right"
.state_text 8, 0, "gfx_draw_text_small"
.state_text 9, 0, "gfx_set_flip_enabled + gfx_flip"
.state_text 10, 0, "gfx_sprite_xor_1bpp_64x32"

phase:
        .db 0
drawn_phase:
        .db 0xFFFF
phase_subticks:
        .db 0
anim_step:
        .db 0
current_mode:
        .db 0
sprite_collision_second:
        .db 0

msg_hex:
        .dstr "ABCD0123"
msg_flip:
        .dstr "F1"
msg_col0:
        .dstr "C0"
msg_col1:
        .dstr "C1"

sprite_demo_5x5:
        .db 0xF0, 0x90, 0x90, 0x90, 0xF0

clock_handler:
        PUSH  R0
        PUSH  R1
        PUSH  R2

        READ  R0, [anim_step]
        READ  R1, 1
        ADD   R0, R1
        STORE [anim_step], R0

        READ  R0, [phase_subticks]
        ADD   R0, R1
        STORE [phase_subticks], R0
        READ  R2, PHASE_TICKS
        CMP   R0, R2
        JLT   _ch_rearm

        READ  R0, 0
        STORE [phase_subticks], R0

        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        READ  R2, PHASE_COUNT
        CMP   R0, R2
        JLT   _ch_store
        READ  R0, 0
_ch_store:
        STORE [phase], R0

_ch_rearm:
        READ  R0, TICK_MS
        SCTMR R0

        POP   R2
        POP   R1
        POP   R0
        IRET

_set_mode_only:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        RET

_draw_common_mode:
        CALL  _set_mode_only
        CALL  gfx_clear
        RET

_get_demo_bounds:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_C
        CMP   R0, R1
        JZ    _gdb_mode_c
        READ  R2, 79
        READ  R3, 47
        RET
_gdb_mode_c:
        READ  R2, 159
        READ  R3, 95
        RET

_set_mode_and_base_phase:
        READ  R1, BASE_PHASE_COUNT
        CMP   R0, R1
        JLT   _smbp_c
        SUB   R0, R1
        READ  R1, GFX_MODE_B
        STORE [current_mode], R1
        RET
_smbp_c:
        READ  R1, GFX_MODE_C
        STORE [current_mode], R1
        RET

demo_clear:
        CALL  _draw_common_mode
        READ  R4, [anim_step]
        READ  R0, 0x003F
        AND   R0, R4
        READ  R1, [anim_step]
        READ  R2, 1
        SHR   R1, R2
        READ  R2, 0x001F
        AND   R1, R2
        READ  R2, 8
        ADD   R0, R2
        READ  R2, 8
        ADD   R1, R2
        READ  R2, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  gfx_pixel
        CALL  gfx_flip
        RET

demo_pixel:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, [anim_step]
        READ  R1, 0x003F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 1
        SHR   R1, R2
        READ  R2, 0x001F
        AND   R1, R2
        CALL  gfx_pixel

        READ  R0, [anim_step]
        READ  R2, 21
        ADD   R0, R2
        READ  R1, 0x003F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 2
        SHR   R1, R2
        READ  R2, 7
        ADD   R1, R2
        READ  R2, 0x001F
        AND   R1, R2
        CALL  gfx_pixel

        READ  R0, [anim_step]
        READ  R2, 41
        ADD   R0, R2
        READ  R1, 0x003F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 3
        SHR   R1, R2
        READ  R2, 13
        ADD   R1, R2
        READ  R2, 0x001F
        AND   R1, R2
        CALL  gfx_pixel

        CALL  gfx_flip
        RET

demo_line:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _get_demo_bounds
        CPY   R6, R2
        CPY   R7, R3

        READ  R5, [anim_step]
        READ  R2, 0x001F
        AND   R5, R2

        READ  R0, 0
        CPY   R1, R5
        CPY   R2, R6
        CPY   R3, R7
        SUB   R3, R5
        CALL  gfx_line

        CPY   R0, R6
        CPY   R1, R5
        READ  R2, 0
        CPY   R3, R7
        SUB   R3, R5
        CALL  gfx_line

        READ  R0, 0
        READ  R1, 8
        ADD   R1, R5
        CPY   R2, R6
        CPY   R3, R1
        CALL  gfx_line

        CALL  gfx_flip
        RET

demo_draw_mode:
        CALL  _draw_common_mode
        CALL  _get_demo_bounds
        CPY   R6, R2

        READ  R5, [anim_step]
        READ  R2, 0x000F
        AND   R5, R2

        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 4
        READ  R1, 8
        ADD   R1, R5
        CPY   R2, R6
        READ  R3, 4
        SUB   R2, R3
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        READ  R0, 4
        READ  R1, 18
        ADD   R1, R5
        CPY   R2, R6
        READ  R3, 4
        SUB   R2, R3
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_BG
        CALL  gfx_set_draw_mode
        READ  R0, 4
        READ  R1, 28
        ADD   R1, R5
        CPY   R2, R6
        READ  R3, 4
        SUB   R2, R3
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        CALL  gfx_flip
        RET

demo_scroll_up:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_up
        READ  R0, 0
        CALL  _get_demo_bounds
        CPY   R1, R3
        CPY   R2, R2
        CPY   R3, R1
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_down:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_down
        READ  R0, 0
        READ  R1, 0
        CALL  _get_demo_bounds
        READ  R3, 0
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_left:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_left
        CALL  _get_demo_bounds
        CPY   R0, R2
        READ  R1, 0
        CPY   R2, R0
        CPY   R3, R3
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_right:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_right
        READ  R0, 0
        READ  R1, 0
        READ  R2, 0
        CALL  _get_demo_bounds
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_text_small:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, msg_hex
        READ  R1, [anim_step]
        READ  R2, 0x003F
        AND   R1, R2
        READ  R2, [anim_step]
        READ  R3, 1
        SHR   R2, R3
        READ  R3, 0x001F
        AND   R2, R3
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_flip_enabled:
        CALL  _draw_common_mode
        CALL  _get_demo_bounds
        CPY   R6, R2
        CPY   R7, R3

        READ  R4, [anim_step]
        READ  R5, 1
        AND   R4, R5
        READ  R0, 0
        CMP   R4, R5
        JNZ   _dfe_set_mode
        READ  R0, 1
_dfe_set_mode:
        CALL  gfx_set_flip_enabled

        READ  R0, [anim_step]
        READ  R1, 0x001F
        AND   R0, R1
        READ  R1, 0
        CPY   R2, R6
        CPY   R3, R7
        SUB   R3, R0
        CALL  gfx_line
        CALL  gfx_flip

        READ  R0, msg_flip
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_sprite_xor_1bpp:
        CALL  _draw_common_mode

        READ  R1, [anim_step]
        READ  R2, 0x001F
        AND   R1, R2
        READ  R3, 10
        ADD   R1, R3
        READ  R2, [anim_step]
        READ  R3, 1
        SHR   R2, R3
        READ  R3, 0x000F
        AND   R2, R3
        READ  R3, 8
        ADD   R2, R3

        READ  R0, SPRITE_FB_BASE_64X32
        READ  R3, sprite_demo_5x5
        READ  R4, 5
        CALL  gfx_sprite_xor_1bpp_64x32

        READ  R4, [anim_step]
        READ  R5, 1
        AND   R4, R5
        READ  R6, 0
        CMP   R4, R6
        JZ    _dcs_single

        READ  R0, SPRITE_FB_BASE_64X32
        READ  R3, sprite_demo_5x5
        READ  R4, 5
        CALL  gfx_sprite_xor_1bpp_64x32
        STORE [sprite_collision_second], R0
        JUMP  _dcs_status

_dcs_single:
        READ  R0, 0
        STORE [sprite_collision_second], R0

_dcs_status:
        READ  R1, [sprite_collision_second]
        READ  R2, 0
        CMP   R1, R2
        JZ    _dcs_msg0
        READ  R0, msg_col1
        JUMP  _dcs_draw
_dcs_msg0:
        READ  R0, msg_col0
_dcs_draw:
        READ  R1, 4
        READ  R2, 4
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

_emit_state_for_phase:
        READ  R1, 0
        CMP   R0, R1
        JZ    _es0
        READ  R1, 1
        CMP   R0, R1
        JZ    _es1
        READ  R1, 2
        CMP   R0, R1
        JZ    _es2
        READ  R1, 3
        CMP   R0, R1
        JZ    _es3
        READ  R1, 4
        CMP   R0, R1
        JZ    _es4
        READ  R1, 5
        CMP   R0, R1
        JZ    _es5
        READ  R1, 6
        CMP   R0, R1
        JZ    _es6
        READ  R1, 7
        CMP   R0, R1
        JZ    _es7
        READ  R1, 8
        CMP   R0, R1
        JZ    _es8
        READ  R1, 9
        CMP   R0, R1
        JZ    _es9
        STATE 10
        RET
_es0:
        STATE 0
        RET
_es1:
        STATE 1
        RET
_es2:
        STATE 2
        RET
_es3:
        STATE 3
        RET
_es4:
        STATE 4
        RET
_es5:
        STATE 5
        RET
_es6:
        STATE 6
        RET
_es7:
        STATE 7
        RET
_es8:
        STATE 8
        RET
_es9:
        STATE 9
        RET

_dispatch_phase:
        READ  R1, 0
        CMP   R0, R1
        JZ    demo_clear
        READ  R1, 1
        CMP   R0, R1
        JZ    demo_pixel
        READ  R1, 2
        CMP   R0, R1
        JZ    demo_line
        READ  R1, 3
        CMP   R0, R1
        JZ    demo_draw_mode
        READ  R1, 4
        CMP   R0, R1
        JZ    demo_scroll_up
        READ  R1, 5
        CMP   R0, R1
        JZ    demo_scroll_down
        READ  R1, 6
        CMP   R0, R1
        JZ    demo_scroll_left
        READ  R1, 7
        CMP   R0, R1
        JZ    demo_scroll_right
        READ  R1, 8
        CMP   R0, R1
        JZ    demo_text_small
        READ  R1, 9
        CMP   R0, R1
        JZ    demo_flip_enabled
        CALL  demo_sprite_xor_1bpp
        RET

main:
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

        READ  R0, 0
        STORE [phase], R0
        STORE [phase_subticks], R0
        STORE [anim_step], R0
        STORE [drawn_phase], 0xFFFF

        READ  R0, GFX_MODE_C
        STORE [current_mode], R0

        READ  R0, 1
        CALL  gfx_set_flip_enabled

        READ  R0, TICK_MS
        SCTMR R0
        STI

main_loop:
        READ  R0, [phase]
        READ  R1, [drawn_phase]
        CMP   R0, R1
        JZ    _draw_frame

        STORE [drawn_phase], R0
        CALL  _set_mode_and_base_phase
        CALL  _draw_common_mode
        CALL  _emit_state_for_phase

_draw_frame:
        READ  R0, [phase]
        CALL  _set_mode_and_base_phase
        CALL  _dispatch_phase
        JUMP  main_loop

