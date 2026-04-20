; =============================================================================
; test_gfx_sprite8_render_order.asm — 8x8 sprite-slot render order on gfx_flip.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

sprite_dot_8x8:
        .db 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        READ  R0, 1
        CALL  gfx_set_flip_enabled
        CALL  gfx_clear
        CALL  gfx_sprite8_reset_all

        ; slot 0 draws 1, slot 1 draws 0 -> final pixel must be 0.
        READ  R0, 0
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 0
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 0
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 0
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        READ  R0, 1
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 1
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 1
        READ  R1, GFX_SPRITE_DRAW_0
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 1
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        ; slot 2 draws 0, slot 3 draws 1 -> final pixel must be 1.
        READ  R0, 2
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 2
        READ  R1, 4
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 2
        READ  R1, GFX_SPRITE_DRAW_0
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 2
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        READ  R0, 3
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 3
        READ  R1, 4
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 3
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 3
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        ; slot 6 XORs first, slot 7 forces 1 last -> final pixel must be 1.
        READ  R0, 6
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 6
        READ  R1, 8
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 6
        READ  R1, GFX_SPRITE_DRAW_XOR
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 6
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        READ  R0, 7
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 7
        READ  R1, 8
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 7
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 7
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        ; Highest slots still render in ascending order: 14 then 15.
        READ  R0, 14
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 14
        READ  R1, 6
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 14
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 14
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        READ  R0, 15
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 15
        READ  R1, 6
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 15
        READ  R1, GFX_SPRITE_DRAW_0
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 15
        READ  R1, 1
        CALL  gfx_sprite8_set_visible

        ; Hidden sprite must not affect output.
        READ  R0, 8
        READ  R1, sprite_dot_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 8
        READ  R1, 10
        READ  R2, 2
        CALL  gfx_sprite8_set_pos
        READ  R0, 8
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 8
        READ  R1, 0
        CALL  gfx_sprite8_set_visible

        CALL  gfx_flip

        READ  R0, 2
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x3010], R0

        READ  R0, 4
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x3011], R0

        READ  R0, 6
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x3012], R0

        READ  R0, 8
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x3013], R0

        READ  R0, 10
        READ  R1, 2
        CALL  _gfx_get_pixel
        STORE [0x3014], R0

        HALT

.expect_mem 0x3010, 0
.expect_mem 0x3011, 1
.expect_mem 0x3012, 0
.expect_mem 0x3013, 1
.expect_mem 0x3014, 0
