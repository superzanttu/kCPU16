; =============================================================================
; test_gfx_scroll_visible_b.asm — scrollaus käyttää näkyvää etupuskuria tilassa B.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        READ  R0, 1
        CALL  gfx_set_flip_enabled
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Scroll right: näkyvä pikseli siirtyy oikealle vaikka taustapuskuri tyhjennetään.
        CALL  gfx_clear
        READ  R0, 2
        READ  R1, 2
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_right
        READ  R0, 3
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0600], R0
        READ  R0, 2
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0601], R0

        ; Scroll left.
        CALL  gfx_clear
        READ  R0, 4
        READ  R1, 2
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_left
        READ  R0, 3
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0602], R0
        READ  R0, 4
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0603], R0

        ; Scroll up.
        CALL  gfx_clear
        READ  R0, 2
        READ  R1, 3
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_up
        READ  R0, 2
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0604], R0
        READ  R0, 2
        READ  R1, 3
        CALL  _gfx_get_pixel
        STORE [0x0605], R0

        ; Scroll down.
        CALL  gfx_clear
        READ  R0, 2
        READ  R1, 2
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_down
        READ  R0, 2
        READ  R1, 3
        CALL  _gfx_get_pixel
        STORE [0x0606], R0
        READ  R0, 2
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x0607], R0

        HALT

.expect_mem 0x0600, 1
.expect_mem 0x0601, 0
.expect_mem 0x0602, 1
.expect_mem 0x0603, 0
.expect_mem 0x0604, 1
.expect_mem 0x0605, 0
.expect_mem 0x0606, 1
.expect_mem 0x0607, 0