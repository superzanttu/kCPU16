; =============================================================================
; test_gfx_rect_modes.asm — gfx_rect tukee fill-flagia ja draw_mode-parametria.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        CALL  gfx_clear

        ; Täytetty suorakaide foreground-tilassa.
        READ  R0, 10
        READ  R1, 10
        READ  R2, 4
        READ  R3, 3
        READ  R4, 1
        READ  R5, GFX_DRAW_FG
        CALL  gfx_rect

        READ  R0, 11
        READ  R1, 11
        CALL  _gfx_get_pixel
        CPY   R8, R0

        READ  R0, 9
        READ  R1, 9
        CALL  _gfx_get_pixel
        CPY   R9, R0

        ; Sama alue taustatilassa pois.
        READ  R0, 10
        READ  R1, 10
        READ  R2, 4
        READ  R3, 3
        READ  R4, 1
        READ  R5, GFX_DRAW_BG
        CALL  gfx_rect

        READ  R0, 11
        READ  R1, 11
        CALL  _gfx_get_pixel
        CPY   R10, R0

        ; Ääriviiva XOR-tilassa ei saa tuhota kulmia.
        READ  R0, 20
        READ  R1, 20
        READ  R2, 4
        READ  R3, 4
        READ  R4, 0
        READ  R5, GFX_DRAW_XOR
        CALL  gfx_rect

        READ  R0, 20
        READ  R1, 20
        CALL  _gfx_get_pixel
        CPY   R11, R0

        READ  R0, 23
        READ  R1, 23
        CALL  _gfx_get_pixel
        CPY   R12, R0

        READ  R0, 21
        READ  R1, 21
        CALL  _gfx_get_pixel
        CPY   R13, R0

        READ  R0, 21
        READ  R1, 20
        CALL  _gfx_get_pixel
        CPY   R14, R0

        READ  R0, 20
        READ  R1, 21
        CALL  _gfx_get_pixel
        CPY   R15, R0

        HALT

.expect_reg R8,  1
.expect_reg R9,  0
.expect_reg R10, 0
.expect_reg R11, 1
.expect_reg R12, 1
.expect_reg R13, 0
.expect_reg R14, 1
.expect_reg R15, 1