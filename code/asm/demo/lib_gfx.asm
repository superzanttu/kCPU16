; =============================================================================
; demo_lib_gfx.asm — lib-gfx.asm kaikkien toimintojen esittely
; =============================================================================
;
; Jokainen vaihe kestaa 10 sekuntia (INT 9 + SCTMR 10000).
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

        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, PHASE_COUNT
        CMP   R0, R1
        JLT   _ch_store
        READ  R0, 0
_ch_store:
        STORE [phase], R0

        READ  R0, 10000
        SCTMR R0

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
        STATE 0
        CALL  _draw_common_mode_c
        CALL  gfx_flip
        RET

demo_pixel:
        STATE 1
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 10
        READ  R1, 10
        CALL  gfx_pixel
        READ  R0, 40
        READ  R1, 20
        CALL  gfx_pixel
        READ  R0, 80
        READ  R1, 48
        CALL  gfx_pixel
        CALL  gfx_flip
        RET

demo_line:
        STATE 2
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, 0
        READ  R1, 0
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line

        READ  R0, 159
        READ  R1, 0
        READ  R2, 0
        READ  R3, 95
        CALL  gfx_line

        READ  R0, 0
        READ  R1, 48
        READ  R2, 159
        READ  R3, 48
        CALL  gfx_line

        CALL  gfx_flip
        RET

demo_draw_mode:
        STATE 3
        CALL  _draw_common_mode_c

        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 20
        READ  R1, 20
        READ  R2, 140
        READ  R3, 20
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        READ  R0, 20
        READ  R1, 20
        READ  R2, 140
        READ  R3, 20
        CALL  gfx_line

        READ  R0, GFX_DRAW_BG
        CALL  gfx_set_draw_mode
        READ  R0, 30
        READ  R1, 30
        READ  R2, 130
        READ  R3, 30
        CALL  gfx_line

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        CALL  gfx_flip
        RET

demo_scroll_up:
        STATE 4
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 0
        READ  R1, 50
        READ  R2, 159
        READ  R3, 50
        CALL  gfx_line
        READ  R0, 6
        CALL  gfx_scroll_up
        CALL  gfx_flip
        RET

demo_scroll_down:
        STATE 5
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 0
        READ  R1, 20
        READ  R2, 159
        READ  R3, 20
        CALL  gfx_line
        READ  R0, 6
        CALL  gfx_scroll_down
        CALL  gfx_flip
        RET

demo_scroll_left:
        STATE 6
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 120
        READ  R1, 0
        READ  R2, 120
        READ  R3, 95
        CALL  gfx_line
        READ  R0, 8
        CALL  gfx_scroll_left
        CALL  gfx_flip
        RET

demo_scroll_right:
        STATE 7
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, 30
        READ  R1, 0
        READ  R2, 30
        READ  R3, 95
        CALL  gfx_line
        READ  R0, 8
        CALL  gfx_scroll_right
        CALL  gfx_flip
        RET

demo_text_small:
        STATE 8
        CALL  _draw_common_mode_c
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        READ  R0, msg_hex
        READ  R1, 8
        READ  R2, 8
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_flip_enabled:
        STATE 9
        CALL  _draw_common_mode_b

        READ  R0, 0
        CALL  gfx_set_flip_enabled
        READ  R0, 0
        READ  R1, 0
        READ  R2, 79
        READ  R3, 47
        CALL  gfx_line
        CALL  gfx_flip

        READ  R0, 1
        CALL  gfx_set_flip_enabled
        CALL  gfx_flip

        READ  R0, msg_flip
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_chip8_sprite:
        STATE 10
        CALL  _draw_common_mode_c

        READ  R0, CH8_FB_BASE
        READ  R1, 10
        READ  R2, 8
        READ  R3, chip8_sprite_demo
        READ  R4, 5
        CALL  gfx_chip8_sprite_xor

        READ  R0, CH8_FB_BASE
        READ  R1, 10
        READ  R2, 8
        READ  R3, chip8_sprite_demo
        READ  R4, 5
        CALL  gfx_chip8_sprite_xor
        STORE [chip8_col2], R0

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

        READ  R0, 10000
        SCTMR R0
        STI

main_loop:
        READ  R0, [phase]
        READ  R1, [drawn_phase]
        CMP   R0, R1
        JZ    main_loop

        STORE [drawn_phase], R0
        CALL  _dispatch_phase
        JUMP  main_loop
