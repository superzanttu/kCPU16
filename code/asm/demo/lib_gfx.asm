; =============================================================================
; demo_lib_gfx.asm — lib-gfx.asm kaikkien toimintojen esittely
; =============================================================================
;
; Jokainen vaihe kestaa 5 sekuntia (50 x 100 ms tikkia).
; Vaiheet:
;   0  gfx_clear
;   1  gfx_pixel
;   2  gfx_line
;   3  gfx_set_draw_mode
;   4  gfx_scroll_up
;   5  gfx_scroll_down
;   6  gfx_scroll_left
;   7  gfx_scroll_right
;   8  gfx_draw_text_small
;   9  gfx_set_flip_enabled + gfx_flip
;   10 gfx_chip8_sprite_xor
;
; Huom: demo pyorii ikuisesti.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../lib/lib-gfx.asm"

.const PHASE_COUNT, 11
.const CH8_FB_BASE, 0x3000
.const TICK_MS, 100
.const PHASE_TICKS, 50

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
.state_text 10, 0, "gfx_chip8_sprite_xor"

phase:
        .db 0
drawn_phase:
        .db 0xFFFF
phase_subticks:
        .db 0
anim_step:
        .db 0
chip8_col2:
        .db 0

msg_hex:
        .dstr "ABCD0123"
msg_flip:
        .dstr "F1"
msg_col0:
        .dstr "C0"
msg_col1:
        .dstr "C1"

chip8_sprite_demo:
        .db 0xF0, 0x90, 0x90, 0x90, 0xF0

clock_handler:
        PUSH  R0
        PUSH  R1
        PUSH  R2

        ; Globaali animaatiolaskuri kasvaa joka 100 ms.
        READ  R0, [anim_step]
        READ  R1, 1
        ADD   R0, R1
        STORE [anim_step], R0

        ; Vaihda vaihetta 50 tikin (5 s) valein.
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

_draw_common_mode_c:
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        CALL  gfx_clear
        RET

_draw_common_mode_b:
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        CALL  gfx_clear
        RET

demo_clear:
        CALL  _draw_common_mode_c
        READ  R4, [anim_step]
        READ  R0, 0x007F
        AND   R0, R4
        READ  R1, [anim_step]
        READ  R2, 2
        SHR   R1, R2
        READ  R2, 0x003F
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
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, [anim_step]
        READ  R1, 0x009F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 1
        SHR   R1, R2
        READ  R2, 0x005F
        AND   R1, R2
        CALL  gfx_pixel
        READ  R0, [anim_step]
        READ  R2, 53
        ADD   R0, R2
        READ  R1, 0x009F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 2
        SHR   R1, R2
        READ  R2, 29
        ADD   R1, R2
        READ  R2, 0x005F
        AND   R1, R2
        CALL  gfx_pixel
        READ  R0, [anim_step]
        READ  R2, 101
        ADD   R0, R2
        READ  R1, 0x009F
        AND   R0, R1
        READ  R1, [anim_step]
        READ  R2, 3
        SHR   R1, R2
        READ  R2, 61
        ADD   R1, R2
        READ  R2, 0x005F
        AND   R1, R2
        CALL  gfx_pixel
        CALL  gfx_flip
        RET

demo_line:
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, [anim_step]
        READ  R1, 0x003F
        AND   R1, R0
        READ  R2, 159
        READ  R3, 95
        SUB   R3, R1
        CALL  gfx_line

        READ  R0, 159
        READ  R1, [anim_step]
        READ  R2, 0x003F
        AND   R1, R2
        READ  R2, 0
        READ  R3, 95
        SUB   R3, R1
        CALL  gfx_line

        READ  R0, 0
        READ  R1, [anim_step]
        READ  R2, 0x001F
        AND   R1, R2
        READ  R2, 32
        ADD   R1, R2
        READ  R2, 159
        CPY   R3, R1
        CALL  gfx_line

        CALL  gfx_flip
        RET

demo_draw_mode:
        CALL  _draw_common_mode_c

        READ  R5, [anim_step]
        READ  R6, 0x003F
        AND   R5, R6

        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 20
        READ  R1, 20
        ADD   R1, R5
        READ  R2, 140
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        READ  R0, 20
        READ  R1, 45
        ADD   R1, R5
        READ  R2, 140
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_BG
        CALL  gfx_set_draw_mode
        READ  R0, 30
        READ  R1, 70
        ADD   R1, R5
        READ  R2, 130
        CPY   R3, R1
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        CALL  gfx_flip
        RET

demo_scroll_up:
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_up
        READ  R0, 0
        READ  R1, 95
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_down:
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_down
        READ  R0, 0
        READ  R1, 0
        READ  R2, 159
        READ  R3, 0
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_left:
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_left
        READ  R0, 159
        READ  R1, 0
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_scroll_right:
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 1
        CALL  gfx_scroll_right
        READ  R0, 0
        READ  R1, 0
        READ  R2, 0
        READ  R3, 95
        CALL  gfx_line
        CALL  gfx_flip
        RET

demo_text_small:
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, msg_hex
        READ  R1, [anim_step]
        READ  R2, 0x003F
        AND   R1, R2
        READ  R2, 8
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_flip_enabled:
        CALL  _draw_common_mode_b

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
        READ  R1, 0x003F
        AND   R0, R1
        READ  R1, 0
        READ  R2, 79
        READ  R3, 47
        SUB   R3, R0
        CALL  gfx_line
        CALL  gfx_flip

        READ  R0, msg_flip
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_chip8_sprite:
        CALL  _draw_common_mode_c

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

        READ  R0, CH8_FB_BASE
        READ  R3, chip8_sprite_demo
        READ  R4, 5
        CALL  gfx_chip8_sprite_xor

        ; Törmäysstatus vilkkuu: parittomilla frameilla piirretään kahdesti.
        READ  R4, [anim_step]
        READ  R5, 1
        AND   R4, R5
        READ  R6, 0
        CMP   R4, R6
        JZ    _dcs_single

        READ  R0, CH8_FB_BASE
        READ  R3, chip8_sprite_demo
        READ  R4, 5
        CALL  gfx_chip8_sprite_xor
        STORE [chip8_col2], R0
        JUMP  _dcs_status

_dcs_single:
        READ  R0, 0
        STORE [chip8_col2], R0

_dcs_status:

        READ  R1, [chip8_col2]
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
        CALL  demo_chip8_sprite
        RET

main:
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

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
        CALL  _emit_state_for_phase

_draw_frame:
        READ  R0, [phase]
        CALL  _dispatch_phase
        JUMP  main_loop
