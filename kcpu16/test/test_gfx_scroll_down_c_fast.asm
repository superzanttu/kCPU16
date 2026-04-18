; =============================================================================
; test_gfx_scroll_down_c_fast.asm — gfx_scroll_down 4 px fastpath tilassa C.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_C
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear

        READ  R0, 0x0081
        STORE [0xF800], R0
        READ  R0, 0x0004
        STORE [0xF850], R0

        READ  R0, 4
        CALL  gfx_scroll_down
        HALT

.expect_mem  0xF800, 0x0000
.expect_mem  0xF850, 0x0081
.expect_mem  0xF8A0, 0x0004