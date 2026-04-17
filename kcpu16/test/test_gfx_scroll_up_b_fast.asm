; =============================================================================
; test_gfx_scroll_up_b_fast.asm — gfx_scroll_up 2 px fastpath tilassa B.
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
        READ  R0, 0x0003
        STORE [0xF850], R0
        READ  R0, 0x0001
        STORE [0xF8A0], R0

        READ  R0, 2
        CALL  gfx_scroll_up
        HALT

.expect_mem  0xF800, 0x0003
.expect_mem  0xF850, 0x0001
.expect_mem  0xF8A0, 0x0000