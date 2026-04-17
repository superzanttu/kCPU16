; =============================================================================
; demo_lib_gfx.asm - lib-gfx.asm toimintojen esittely
; =============================================================================
;
; GRAFIIKKATILAVAIHEET:
;   1) Kaikki demovaiheet ajetaan grafiikkatilassa B.
;   2) Kaikki demovaiheet ajetaan grafiikkatilassa C.
;   3) Aloitetaan uudelleen kohdasta 1.
;
; DEMOVAIHEET:
;   1) Ruudun valkytys (3 s)
;   2) Satunnaiset pikselit (5 s)
;   3) Satunnaiset viivat (5 s)
;   4) Skrollaus oikealle (5 s)
;   5) Skrollaus vasemmalle (5 s)
;   6) Skrollaus ylos (5 s)
;   7) Skrollaus alas (5 s)
;   8) Pienta tekstia (5 s)
;   9) Isoa tekstia (5 s)
;  10) Pacman sprite (10 s)
;  11) Sprite tormays (30 s)
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../lib/lib-gfx.asm"

.const BASE_PHASE_COUNT, 11
.const PHASE_COUNT, 22
.const TICK_MS, 100
.const SPRITE_SIZE_8, 8

; 100 ms tickit per vaihe (B- ja C-kierros jakavat samat kestot)
phase_ticks_table:
        .db 30, 50, 50, 50, 50, 50, 50, 50, 50, 100, 300

.state_text 0, 0,  "B1: ruudun valkytys"
.state_text 1, 0,  "B2: satunnaiset pikselit"
.state_text 2, 0,  "B3: satunnaiset viivat"
.state_text 3, 0,  "B4: skrollaus oikealle"
.state_text 4, 0,  "B5: skrollaus vasemmalle"
.state_text 5, 0,  "B6: skrollaus ylos"
.state_text 6, 0,  "B7: skrollaus alas"
.state_text 7, 0,  "B8: pienta tekstia"
.state_text 8, 0,  "B9: isoa tekstia"
.state_text 9, 0,  "B10: pacman sprite"
.state_text 10, 0, "B11: sprite tormays"
.state_text 11, 0, "C1: ruudun valkytys"
.state_text 12, 0, "C2: satunnaiset pikselit"
.state_text 13, 0, "C3: satunnaiset viivat"
.state_text 14, 0, "C4: skrollaus oikealle"
.state_text 15, 0, "C5: skrollaus vasemmalle"
.state_text 16, 0, "C6: skrollaus ylos"
.state_text 17, 0, "C7: skrollaus alas"
.state_text 18, 0, "C8: pienta tekstia"
.state_text 19, 0, "C9: isoa tekstia"
.state_text 20, 0, "C10: pacman sprite"
.state_text 21, 0, "C11: sprite tormays"

phase:
        .db 0
drawn_phase:
        .db 0xFFFF
phase_subticks:
        .db 0
anim_step:
        .db 0
current_mode:
        .db 0
rng_state:
        .db 0xACE1

pac_x:
        .db 8
pac_y:
        .db 8
ghost0_x:
        .db 0
ghost0_y:
        .db 0
ghost1_x:
        .db 72
ghost1_y:
        .db 0
ghost2_x:
        .db 0
ghost2_y:
        .db 40
ghost3_x:
        .db 72
ghost3_y:
        .db 40

small_text_all:
        .dstr "0123456789ABCDEF"
big_text_all:
        .dstr "0123456789:. "
one_char_buf:
        .db 0, 0
msg_col0:
        .dstr "C0"
msg_col1:
        .dstr "C1"
msg_col2:
        .dstr "C2"

sprite_pacman_8x8:
        .db 0x3C, 0x7E, 0xFC, 0xF8, 0xF8, 0xFC, 0x7E, 0x3C
sprite_ghost_8x8:
        .db 0x3C, 0x7E, 0xDB, 0xFF, 0xFF, 0xE7, 0xA5, 0x00

clock_handler:
        PUSH  R0
        PUSH  R1
        PUSH  R2

        READ  R0, [anim_step]
        READ  R1, 1
        ADD   R0, R1
        STORE [anim_step], R0

        READ  R0, [phase_subticks]
        ADD   R0, R1
        STORE [phase_subticks], R0

        READ  R2, [phase]
        CPY   R0, R2
        CALL  _get_phase_tick_limit   ; R2 = tick-limit
        READ  R0, [phase_subticks]
        CMP   R0, R2
        JLT   _ch_rearm

        READ  R0, 0
        STORE [phase_subticks], R0

        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        READ  R2, PHASE_COUNT
        CMP   R0, R2
        JLT   _ch_store
        READ  R0, 0
_ch_store:
        STORE [phase], R0

_ch_rearm:
        READ  R0, TICK_MS
        SCTMR R0

        POP   R2
        POP   R1
        POP   R0
        IRET

_set_mode_only:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_REG
        STORE [R1], R0
        RET

_draw_common_mode:
        CALL  _set_mode_only
        CALL  gfx_clear
        RET

_get_demo_bounds:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_C
        CMP   R0, R1
        JZ    _gdb_mode_c
        READ  R2, 79
        READ  R3, 47
        RET
_gdb_mode_c:
        READ  R2, 159
        READ  R3, 95
        RET

_set_mode_and_base_phase:
        READ  R1, BASE_PHASE_COUNT
        CMP   R0, R1
        JLT   _smbp_b
        SUB   R0, R1
        READ  R1, GFX_MODE_C
        STORE [current_mode], R1
        RET
_smbp_b:
        READ  R1, GFX_MODE_B
        STORE [current_mode], R1
        RET

_get_phase_tick_limit:
        READ  R1, BASE_PHASE_COUNT
        CMP   R0, R1
        JLT   _gptl_base_ok
        SUB   R0, R1
_gptl_base_ok:
        READ  R1, phase_ticks_table
        ADD   R1, R0
        READ  R2, [R1]
        RET

_rand_u16:
        READ  R0, [rng_state]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _rand_mix
        READ  R0, 0xACE1
_rand_mix:
        CPY   R1, R0
        READ  R2, 7
        SHL   R1, R2
        XOR   R0, R1

        CPY   R1, R0
        READ  R2, 9
        SHR   R1, R2
        XOR   R0, R1

        CPY   R1, R0
        READ  R2, 8
        SHL   R1, R2
        XOR   R0, R1

        STORE [rng_state], R0
        RET

_rand_range:
        ; Sisaan R0=max_inclusive, ulos R0=0..max
        CPY   R3, R0
        READ  R1, 1
        ADD   R1, R3                  ; n = max + 1
        READ  R4, 0
        CMP   R1, R4
        JNZ   _rr_div_ok
        ; Reuna-arvo: jos n wrapataan nollaksi (max=0xFFFF), palaa 0
        READ  R0, 0
        RET
_rr_div_ok:
        CALL  _rand_u16               ; R0 = rand
        CPY   R2, R0                  ; R2 = rand
        CPY   R3, R2
        DIV   R3, R1                  ; q
        MUL   R3, R1                  ; q*n
        SUB   R2, R3                  ; rand % n
        CPY   R0, R2
        RET

_draw_random_pixel:
        CALL  _get_demo_bounds
        CPY   R6, R2                  ; xmax
        CPY   R7, R3                  ; ymax
        CPY   R0, R6
        CALL  _rand_range
        CPY   R4, R0
        CPY   R0, R7
        CALL  _rand_range
        CPY   R1, R0
        CPY   R0, R4
        CALL  gfx_pixel
        RET

_draw_random_line:
        CALL  _get_demo_bounds
        CPY   R10, R2                 ; xmax
        CPY   R11, R3                 ; ymax

        CPY   R0, R10
        CALL  _rand_range
        CPY   R4, R0
        CPY   R0, R11
        CALL  _rand_range
        CPY   R5, R0

        CPY   R0, R10
        CALL  _rand_range
        CPY   R6, R0
        CPY   R0, R11
        CALL  _rand_range
        CPY   R7, R0

        CPY   R0, R4
        CPY   R1, R5
        CPY   R2, R6
        CPY   R3, R7
        CALL  gfx_line
        RET

_draw_sprite_8x8:
        ; Sisaan: R0=x, R1=y, R2=sprite_ptr
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R9

        CPY   R7, R0                  ; base x
        CPY   R8, R1                  ; base y
        CPY   R9, R2                  ; sprite ptr
        READ  R6, 0                   ; row idx
_dsp_row:
        READ  R0, 8
        CMP   R6, R0
        JGE   _dsp_done

        READ  R5, [R9]
        READ  R0, 1
        ADD   R9, R0

        READ  R4, 0                   ; bit idx
_dsp_bit:
        READ  R0, 8
        CMP   R4, R0
        JGE   _dsp_next_row

        READ  R0, 0x0080
        SHR   R0, R4
        CPY   R3, R5
        AND   R3, R0
        READ  R0, 0
        CMP   R3, R0
        JZ    _dsp_inc_bit

        CPY   R0, R7
        ADD   R0, R4
        CPY   R1, R8
        ADD   R1, R6
        CALL  gfx_pixel

_dsp_inc_bit:
        READ  R0, 1
        ADD   R4, R0
        JUMP  _dsp_bit

_dsp_next_row:
        READ  R0, 1
        ADD   R6, R0
        JUMP  _dsp_row

_dsp_done:
        POP   R9
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4
        POP   R3
        RET

_update_pacman_random:
        CALL  _get_demo_bounds
        READ  R4, SPRITE_SIZE_8
        SUB   R2, R4
        SUB   R3, R4
        CPY   R6, R2                  ; xmax-8
        CPY   R7, R3                  ; ymax-8
        CPY   R0, R6
        CALL  _rand_range
        STORE [pac_x], R0
        CPY   R0, R7
        CALL  _rand_range
        STORE [pac_y], R0
        RET

_emit_state_for_base_phase:
        READ  R1, 0
        CMP   R0, R1
        JZ    _esbp0
        READ  R1, 1
        CMP   R0, R1
        JZ    _esbp1
        READ  R1, 2
        CMP   R0, R1
        JZ    _esbp2
        READ  R1, 3
        CMP   R0, R1
        JZ    _esbp3
        READ  R1, 4
        CMP   R0, R1
        JZ    _esbp4
        READ  R1, 5
        CMP   R0, R1
        JZ    _esbp5
        READ  R1, 6
        CMP   R0, R1
        JZ    _esbp6
        READ  R1, 7
        CMP   R0, R1
        JZ    _esbp7
        READ  R1, 8
        CMP   R0, R1
        JZ    _esbp8
        READ  R1, 9
        CMP   R0, R1
        JZ    _esbp9
        CALL  _emit_state_bc_10
        RET
_esbp0:
        CALL  _emit_state_bc_0
        RET
_esbp1:
        CALL  _emit_state_bc_1
        RET
_esbp2:
        CALL  _emit_state_bc_2
        RET
_esbp3:
        CALL  _emit_state_bc_3
        RET
_esbp4:
        CALL  _emit_state_bc_4
        RET
_esbp5:
        CALL  _emit_state_bc_5
        RET
_esbp6:
        CALL  _emit_state_bc_6
        RET
_esbp7:
        CALL  _emit_state_bc_7
        RET
_esbp8:
        CALL  _emit_state_bc_8
        RET
_esbp9:
        CALL  _emit_state_bc_9
        RET

_step_ghost_towards_pacman:
        ; Sisaan: R0 = ghost_x_addr, R1 = ghost_y_addr
        PUSH  R2
        PUSH  R3
        PUSH  R4
        PUSH  R5
        PUSH  R6

        CPY   R6, R0
        CPY   R5, R1

        READ  R2, [R6]                ; gx
        READ  R3, [R5]                ; gy
        READ  R4, [pac_x]
        CMP   R2, R4
        JZ    _sgtp_y
        JGT   _sgtp_x_dec
        READ  R0, 1
        ADD   R2, R0
        JUMP  _sgtp_y
_sgtp_x_dec:
        READ  R0, 1
        SUB   R2, R0

_sgtp_y:
        READ  R4, [pac_y]
        CMP   R3, R4
        JZ    _sgtp_store
        JGT   _sgtp_y_dec
        READ  R0, 1
        ADD   R3, R0
        JUMP  _sgtp_store
_sgtp_y_dec:
        READ  R0, 1
        SUB   R3, R0

_sgtp_store:
        STORE [R6], R2
        STORE [R5], R3

        POP   R6
        POP   R5
        POP   R4
        POP   R3
        POP   R2
        RET

_check_sprite_overlap:
        ; Sisaan: R0=ax, R1=ay, R2=bx, R3=by
        ; Ulos:   R0=1 overlap, 0 ei overlap
        READ  R4, SPRITE_SIZE_8
        CPY   R5, R0
        ADD   R5, R4                  ; ax+8
        CPY   R6, R2
        ADD   R6, R4                  ; bx+8
        CMP   R5, R2
        JLE   _cso_no
        CMP   R6, R0
        JLE   _cso_no

        CPY   R5, R1
        ADD   R5, R4                  ; ay+8
        CPY   R6, R3
        ADD   R6, R4                  ; by+8
        CMP   R5, R3
        JLE   _cso_no
        CMP   R6, R1
        JLE   _cso_no
        READ  R0, 1
        RET
_cso_no:
        READ  R0, 0
        RET

_reset_ghost_to_corner:
        ; Sisaan: R0=idx(0..3)
        READ  R1, 0
        CMP   R0, R1
        JZ    _rgc0
        READ  R1, 1
        CMP   R0, R1
        JZ    _rgc1
        READ  R1, 2
        CMP   R0, R1
        JZ    _rgc2
        ; idx 3
        READ  R1, 72
        STORE [ghost3_x], R1
        READ  R1, 40
        STORE [ghost3_y], R1
        RET
_rgc0:
        READ  R1, 0
        STORE [ghost0_x], R1
        STORE [ghost0_y], R1
        RET
_rgc1:
        READ  R1, 72
        STORE [ghost1_x], R1
        READ  R1, 0
        STORE [ghost1_y], R1
        RET
_rgc2:
        READ  R1, 0
        STORE [ghost2_x], R1
        READ  R1, 40
        STORE [ghost2_y], R1
        RET

_emit_state_bc_0:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc0_b
        STATE 11
        RET
_esbc0_b:
        STATE 0
        RET

_emit_state_bc_1:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc1_b
        STATE 12
        RET
_esbc1_b:
        STATE 1
        RET

_emit_state_bc_2:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc2_b
        STATE 13
        RET
_esbc2_b:
        STATE 2
        RET

_emit_state_bc_3:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc3_b
        STATE 14
        RET
_esbc3_b:
        STATE 3
        RET

_emit_state_bc_4:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc4_b
        STATE 15
        RET
_esbc4_b:
        STATE 4
        RET

_emit_state_bc_5:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc5_b
        STATE 16
        RET
_esbc5_b:
        STATE 5
        RET

_emit_state_bc_6:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc6_b
        STATE 17
        RET
_esbc6_b:
        STATE 6
        RET

_emit_state_bc_7:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc7_b
        STATE 18
        RET
_esbc7_b:
        STATE 7
        RET

_emit_state_bc_8:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc8_b
        STATE 19
        RET
_esbc8_b:
        STATE 8
        RET

_emit_state_bc_9:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc9_b
        STATE 20
        RET
_esbc9_b:
        STATE 9
        RET

_emit_state_bc_10:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc10_b
        STATE 21
        RET
_esbc10_b:
        STATE 10
        RET

demo_phase1_blink:
        CALL  _set_mode_only

        READ  R0, [anim_step]
        READ  R1, 1
        AND   R0, R1
        CMP   R0, R1
        JZ    _dp1_fill
        CALL  gfx_clear
        CALL  gfx_flip
        RET
_dp1_fill:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _dp1_fill_b
        READ  R2, 0x00FF
        JUMP  _dp1_fill_do
_dp1_fill_b:
        READ  R2, 0x0003
_dp1_fill_do:
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        FILL  R0, R1, R2
        CALL  gfx_flip
        RET

demo_phase2_random_pixels:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_pixel
        CALL  _draw_random_pixel
        CALL  _draw_random_pixel
        CALL  gfx_flip
        RET

demo_phase3_random_lines:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_line
        CALL  _draw_random_line
        CALL  gfx_flip
        RET

demo_phase4_scroll_right:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_right
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_right
        CALL  gfx_flip
        RET

demo_phase5_scroll_left:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_left
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_left
        CALL  gfx_flip
        RET

demo_phase6_scroll_up:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_up
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_up
        CALL  gfx_flip
        RET

demo_phase7_scroll_down:
        CALL  _set_mode_only
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_down
        CALL  _draw_random_line
        READ  R0, 1
        CALL  gfx_scroll_down
        CALL  gfx_flip
        RET

demo_phase8_small_text:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, [anim_step]
        READ  R1, 16
        DIV   R0, R1
        MUL   R0, R1
        READ  R1, [anim_step]
        SUB   R1, R0                  ; idx = anim_step % 16

        READ  R0, small_text_all
        ADD   R0, R1
        READ  R2, [R0]
        STORE [one_char_buf], R2

        READ  R0, one_char_buf
        READ  R1, 10
        READ  R2, 10
        CALL  gfx_draw_text_small
        CALL  gfx_flip
        RET

demo_phase9_big_text:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, [anim_step]
        READ  R1, 13
        DIV   R0, R1
        MUL   R0, R1
        READ  R1, [anim_step]
        SUB   R1, R0                  ; idx = anim_step % 13

        READ  R0, big_text_all
        ADD   R0, R1
        READ  R2, [R0]
        STORE [one_char_buf], R2

        READ  R0, one_char_buf
        READ  R1, 10
        READ  R2, 10
        CALL  gfx_draw_text_big
        CALL  gfx_flip
        RET

demo_phase10_pacman:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        CALL  _update_pacman_random
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, sprite_pacman_8x8
        CALL  _draw_sprite_8x8
        CALL  gfx_flip
        RET

demo_phase11_collision:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Pacman satunnaiseen kohtaan
        CALL  _update_pacman_random

        ; Liikuta haamuja kohti pacmania
        READ  R0, ghost0_x
        READ  R1, ghost0_y
        CALL  _step_ghost_towards_pacman
        READ  R0, ghost1_x
        READ  R1, ghost1_y
        CALL  _step_ghost_towards_pacman
        READ  R0, ghost2_x
        READ  R1, ghost2_y
        CALL  _step_ghost_towards_pacman
        READ  R0, ghost3_x
        READ  R1, ghost3_y
        CALL  _step_ghost_towards_pacman

        ; Piirra pacman
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, sprite_pacman_8x8
        CALL  _draw_sprite_8x8

        ; Tormayslaskuri 0..2
        READ  R12, 0

        ; ghost0
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, [ghost0_x]
        READ  R3, [ghost0_y]
        CALL  _check_sprite_overlap
        READ  R1, 0
        CMP   R0, R1
        JZ    _dp11_g0_draw
        READ  R0, 0
        CALL  _reset_ghost_to_corner
        READ  R0, 1
        ADD   R12, R0
_dp11_g0_draw:
        READ  R0, [ghost0_x]
        READ  R1, [ghost0_y]
        READ  R2, sprite_ghost_8x8
        CALL  _draw_sprite_8x8

        ; ghost1
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, [ghost1_x]
        READ  R3, [ghost1_y]
        CALL  _check_sprite_overlap
        READ  R1, 0
        CMP   R0, R1
        JZ    _dp11_g1_draw
        READ  R0, 1
        CALL  _reset_ghost_to_corner
        READ  R0, 1
        ADD   R12, R0
_dp11_g1_draw:
        READ  R0, [ghost1_x]
        READ  R1, [ghost1_y]
        READ  R2, sprite_ghost_8x8
        CALL  _draw_sprite_8x8

        ; ghost2
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, [ghost2_x]
        READ  R3, [ghost2_y]
        CALL  _check_sprite_overlap
        READ  R1, 0
        CMP   R0, R1
        JZ    _dp11_g2_draw
        READ  R0, 2
        CALL  _reset_ghost_to_corner
        READ  R0, 1
        ADD   R12, R0
_dp11_g2_draw:
        READ  R0, [ghost2_x]
        READ  R1, [ghost2_y]
        READ  R2, sprite_ghost_8x8
        CALL  _draw_sprite_8x8

        ; ghost3
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        READ  R2, [ghost3_x]
        READ  R3, [ghost3_y]
        CALL  _check_sprite_overlap
        READ  R1, 0
        CMP   R0, R1
        JZ    _dp11_g3_draw
        READ  R0, 3
        CALL  _reset_ghost_to_corner
        READ  R0, 1
        ADD   R12, R0
_dp11_g3_draw:
        READ  R0, [ghost3_x]
        READ  R1, [ghost3_y]
        READ  R2, sprite_ghost_8x8
        CALL  _draw_sprite_8x8

        ; C0/C1/C2 status naytolle
        READ  R0, 2
        CMP   R12, R0
        JLE   _dp11_c_ok
        CPY   R12, R0
_dp11_c_ok:
        READ  R0, 0
        CMP   R12, R0
        JZ    _dp11_msg0
        READ  R0, 1
        CMP   R12, R0
        JZ    _dp11_msg1
        READ  R0, msg_col2
        JUMP  _dp11_msg_draw
_dp11_msg0:
        READ  R0, msg_col0
        JUMP  _dp11_msg_draw
_dp11_msg1:
        READ  R0, msg_col1
_dp11_msg_draw:
        READ  R1, 2
        READ  R2, 2
        CALL  gfx_draw_text_small

        CALL  gfx_flip
        RET

_dispatch_base_phase:
        READ  R1, 0
        CMP   R0, R1
        JZ    demo_phase1_blink
        READ  R1, 1
        CMP   R0, R1
        JZ    demo_phase2_random_pixels
        READ  R1, 2
        CMP   R0, R1
        JZ    demo_phase3_random_lines
        READ  R1, 3
        CMP   R0, R1
        JZ    demo_phase4_scroll_right
        READ  R1, 4
        CMP   R0, R1
        JZ    demo_phase5_scroll_left
        READ  R1, 5
        CMP   R0, R1
        JZ    demo_phase6_scroll_up
        READ  R1, 6
        CMP   R0, R1
        JZ    demo_phase7_scroll_down
        READ  R1, 7
        CMP   R0, R1
        JZ    demo_phase8_small_text
        READ  R1, 8
        CMP   R0, R1
        JZ    demo_phase9_big_text
        READ  R1, 9
        CMP   R0, R1
        JZ    demo_phase10_pacman
        CALL  demo_phase11_collision
        RET

main:
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

        READ  R0, 0
        STORE [phase], R0
        STORE [phase_subticks], R0
        STORE [anim_step], R0
        STORE [drawn_phase], 0xFFFF

        READ  R0, GFX_MODE_B
        STORE [current_mode], R0

        READ  R0, 1
        CALL  gfx_set_flip_enabled

        READ  R0, TICK_MS
        SCTMR R0
        STI

main_loop:
        READ  R4, [phase]
        READ  R1, [drawn_phase]
        CMP   R4, R1
        JZ    _draw_frame

        STORE [drawn_phase], R4
        CPY   R0, R4
        CALL  _set_mode_and_base_phase
        CPY   R5, R0
        CALL  _draw_common_mode
        CPY   R0, R5
        CALL  _emit_state_for_base_phase

_draw_frame:
        CPY   R0, R4
        CALL  _set_mode_and_base_phase ; R0 -> base phase, asettaa moodin
        CALL  _dispatch_base_phase
        JUMP  main_loop
