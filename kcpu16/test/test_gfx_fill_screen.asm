; =============================================================================
; test_gfx_fill_screen.asm — gfx_fill_screen tayttaa koko ruudun 0/1 molemmissa tiloissa.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        ; Tila B: kaikki paalle
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        READ  R0, 1
        CALL  gfx_fill_screen

        READ  R0, 0
        READ  R1, 0
        CALL  _gfx_get_pixel
        STORE [0x3020], R0

        READ  R0, 79
        READ  R1, 47
        CALL  _gfx_get_pixel
        STORE [0x3021], R0

        ; Tila B: kaikki pois
        READ  R0, 0
        CALL  gfx_fill_screen

        READ  R0, 0
        READ  R1, 0
        CALL  _gfx_get_pixel
        STORE [0x3022], R0

        READ  R0, 79
        READ  R1, 47
        CALL  _gfx_get_pixel
        STORE [0x3023], R0

        ; Tila C: kaikki paalle
        READ  R0, GFX_MODE_C
        STORE [GFX_MODE_REG], R0
        READ  R0, 1
        CALL  gfx_fill_screen

        READ  R0, 0
        READ  R1, 0
        CALL  _gfx_get_pixel
        STORE [0x3024], R0

        READ  R0, 159
        READ  R1, 95
        CALL  _gfx_get_pixel
        STORE [0x3025], R0

        ; Tila C: kaikki pois
        READ  R0, 0
        CALL  gfx_fill_screen

        READ  R0, 0
        READ  R1, 0
        CALL  _gfx_get_pixel
        STORE [0x3026], R0

        READ  R0, 159
        READ  R1, 95
        CALL  _gfx_get_pixel
        STORE [0x3027], R0

        HALT

.expect_mem 0x3020, 1
.expect_mem 0x3021, 1
.expect_mem 0x3022, 0
.expect_mem 0x3023, 0
.expect_mem 0x3024, 1
.expect_mem 0x3025, 1
.expect_mem 0x3026, 0
.expect_mem 0x3027, 0
