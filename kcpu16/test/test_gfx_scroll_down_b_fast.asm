; =============================================================================
; test_gfx_scroll_down_b_fast.asm — gfx_scroll_down 2 px fastpath tilassa B.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear

        READ  R0, 0x0002
        STORE [0xF800], R0
        READ  R0, 0x0001
        STORE [0xFE90], R0
        READ  R0, 0x0003
        STORE [0xFEE0], R0

        READ  R0, 2
        CALL  gfx_scroll_down
        HALT

.expect_mem  0xF800, 0x0000
.expect_mem  0xFE90, 0x0000
.expect_mem  0xFEE0, 0x0001
.expect_mem  0xFF30, 0x0003