; =============================================================================
; test_gfx_circle_modes.asm — gfx_circle piirtää outline- ja filled-muodot.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_C
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear

        ; Outline ympyra XOR-tilassa.
        READ  R0, 20
        READ  R1, 20
        READ  R2, 3
        READ  R3, 0
        READ  R4, GFX_DRAW_XOR
        CALL  gfx_circle

        READ  R0, 23
        READ  R1, 20
        CALL  _gfx_get_pixel
        CPY   R8, R0

        READ  R0, 17
        READ  R1, 20
        CALL  _gfx_get_pixel
        CPY   R9, R0

        READ  R0, 20
        READ  R1, 23
        CALL  _gfx_get_pixel
        CPY   R10, R0

        READ  R0, 20
        READ  R1, 17
        CALL  _gfx_get_pixel
        CPY   R11, R0

        READ  R0, 20
        READ  R1, 20
        CALL  _gfx_get_pixel
        CPY   R12, R0

        CALL  gfx_clear

        ; Täytetty ympyra foreground-tilassa.
        READ  R0, 30
        READ  R1, 30
        READ  R2, 3
        READ  R3, 1
        READ  R4, GFX_DRAW_FG
        CALL  gfx_circle

        READ  R0, 30
        READ  R1, 30
        CALL  _gfx_get_pixel
        CPY   R13, R0

        READ  R0, 33
        READ  R1, 30
        CALL  _gfx_get_pixel
        CPY   R14, R0

        READ  R0, 34
        READ  R1, 30
        CALL  _gfx_get_pixel
        CPY   R15, R0

        HALT

.expect_reg R8,  1
.expect_reg R9,  1
.expect_reg R10, 1
.expect_reg R11, 1
.expect_reg R12, 0
.expect_reg R13, 1
.expect_reg R14, 1
.expect_reg R15, 0