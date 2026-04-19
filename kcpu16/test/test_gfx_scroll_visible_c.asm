; =============================================================================
; test_gfx_scroll_visible_c.asm — scrollaus käyttää näkyvää etupuskuria tilassa C.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_C
        STORE [GFX_MODE_REG], R0
        READ  R0, 1
        CALL  gfx_set_flip_enabled
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Scroll right.
        CALL  gfx_clear
        READ  R0, 12
        READ  R1, 12
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_right
        READ  R0, 13
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0610], R0
        READ  R0, 12
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0611], R0

        ; Scroll left.
        CALL  gfx_clear
        READ  R0, 14
        READ  R1, 12
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_left
        READ  R0, 13
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0612], R0
        READ  R0, 14
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0613], R0

        ; Scroll up.
        CALL  gfx_clear
        READ  R0, 12
        READ  R1, 13
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_up
        READ  R0, 12
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0614], R0
        READ  R0, 12
        READ  R1, 13
        CALL  _gfx_get_pixel
        STORE [0x0615], R0

        ; Scroll down.
        CALL  gfx_clear
        READ  R0, 12
        READ  R1, 12
        CALL  gfx_pixel
        CALL  gfx_flip
        CALL  gfx_clear
        READ  R0, 1
        CALL  gfx_scroll_down
        READ  R0, 12
        READ  R1, 13
        CALL  _gfx_get_pixel
        STORE [0x0616], R0
        READ  R0, 12
        READ  R1, 12
        CALL  _gfx_get_pixel
        STORE [0x0617], R0

        HALT

.expect_mem 0x0610, 1
.expect_mem 0x0611, 0
.expect_mem 0x0612, 1
.expect_mem 0x0613, 0
.expect_mem 0x0614, 1
.expect_mem 0x0615, 0
.expect_mem 0x0616, 1
.expect_mem 0x0617, 0