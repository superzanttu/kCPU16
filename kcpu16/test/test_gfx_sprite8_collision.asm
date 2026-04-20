; =============================================================================
; test_gfx_sprite8_collision.asm — 8x8 sprite-slot collision flags.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

sprite_block_8x8:
        .db 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF

main:
        READ  R0, GFX_MODE_B
        STORE [GFX_MODE_REG], R0
        CALL  gfx_sprite8_reset_all

        ; sprite 0: visible + collision enabled
        READ  R0, 0
        READ  R1, sprite_block_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 0
        READ  R1, 10
        READ  R2, 10
        CALL  gfx_sprite8_set_pos
        READ  R0, 0
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 0
        READ  R1, 1
        CALL  gfx_sprite8_set_visible
        READ  R0, 0
        READ  R1, 1
        CALL  gfx_sprite8_set_collision_check

        ; sprite 1: overlaps sprite 0, visible + collision enabled
        READ  R0, 1
        READ  R1, sprite_block_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 1
        READ  R1, 15
        READ  R2, 15
        CALL  gfx_sprite8_set_pos
        READ  R0, 1
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 1
        READ  R1, 1
        CALL  gfx_sprite8_set_visible
        READ  R0, 1
        READ  R1, 1
        CALL  gfx_sprite8_set_collision_check

        ; sprite 2: overlaps but collision disabled -> no flag
        READ  R0, 2
        READ  R1, sprite_block_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 2
        READ  R1, 12
        READ  R2, 12
        CALL  gfx_sprite8_set_pos
        READ  R0, 2
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 2
        READ  R1, 1
        CALL  gfx_sprite8_set_visible
        READ  R0, 2
        READ  R1, 0
        CALL  gfx_sprite8_set_collision_check

        ; sprite 3: hidden -> no flag even if overlapping
        READ  R0, 3
        READ  R1, sprite_block_8x8
        CALL  gfx_sprite8_set_bitmap
        READ  R0, 3
        READ  R1, 11
        READ  R2, 11
        CALL  gfx_sprite8_set_pos
        READ  R0, 3
        READ  R1, GFX_SPRITE_DRAW_1
        CALL  gfx_sprite8_set_draw_mode
        READ  R0, 3
        READ  R1, 0
        CALL  gfx_sprite8_set_visible
        READ  R0, 3
        READ  R1, 1
        CALL  gfx_sprite8_set_collision_check

        CALL  gfx_sprite8_update_collisions

        READ  R0, 0
        CALL  gfx_sprite8_get_collision
        STORE [0x3000], R0
        READ  R0, 1
        CALL  gfx_sprite8_get_collision
        STORE [0x3001], R0
        READ  R0, 2
        CALL  gfx_sprite8_get_collision
        STORE [0x3002], R0
        READ  R0, 3
        CALL  gfx_sprite8_get_collision
        STORE [0x3003], R0

        ; Move sprite 1 away and verify flags clear on recompute.
        READ  R0, 1
        READ  R1, 30
        READ  R2, 30
        CALL  gfx_sprite8_set_pos
        CALL  gfx_sprite8_update_collisions

        READ  R0, 0
        CALL  gfx_sprite8_get_collision
        STORE [0x3004], R0
        READ  R0, 1
        CALL  gfx_sprite8_get_collision
        STORE [0x3005], R0
        READ  R0, 2
        CALL  gfx_sprite8_get_collision
        STORE [0x3006], R0
        READ  R0, 3
        CALL  gfx_sprite8_get_collision
        STORE [0x3007], R0

        HALT

.expect_mem 0x3000, 1
.expect_mem 0x3001, 1
.expect_mem 0x3002, 0
.expect_mem 0x3003, 0
.expect_mem 0x3004, 0
.expect_mem 0x3005, 0
.expect_mem 0x3006, 0
.expect_mem 0x3007, 0
