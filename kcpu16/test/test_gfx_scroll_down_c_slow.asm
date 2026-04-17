; =============================================================================
; test_gfx_scroll_down_c_slow.asm — gfx_scroll_down 1 px tilassa C.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_C
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, 0
        READ  R1, 92
        CALL  gfx_pixel
        READ  R0, 0
        READ  R1, 93
        CALL  gfx_pixel
        READ  R0, 0
        READ  R1, 94
        CALL  gfx_pixel

        READ  R0, 1
        CALL  gfx_scroll_down
        HALT

.expect_mem  0xFF30, 0x0046
.expect_mem  0xFEE0, 0x0000