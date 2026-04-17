; =============================================================================
; test_gfx_scroll_up_b_slow.asm — gfx_scroll_up 1 px tilassa B.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, 0
        READ  R1, 0
        CALL  gfx_pixel
        READ  R0, 0
        READ  R1, 1
        CALL  gfx_pixel
        READ  R0, 0
        READ  R1, 2
        CALL  gfx_pixel

        READ  R0, 1
        CALL  gfx_scroll_up
        HALT

.expect_mem  0xF800, 0x0003
.expect_mem  0xF850, 0x0000