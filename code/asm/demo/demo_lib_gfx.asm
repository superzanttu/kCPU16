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
;   1) Satunnaiset pikselit (10 s)
;   2) Satunnaiset viivat (5 s)
;   3) Skrollaus oikealle (5 s)
;   4) Skrollaus vasemmalle (5 s)
;   5) Skrollaus ylos (5 s)
;   6) Skrollaus alas (5 s)
;   7) Pienta tekstia (5 s)
;   8) Isoa tekstia (5 s)
;   9) Pacman sprite (10 s)
;  10) Sprite tormays (30 s)
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../lib/lib-gfx.asm"

.const BASE_PHASE_COUNT, 10
.const PHASE_COUNT, 20
.const ANIM_TICK_MS, 100
.const SPRITE_SIZE_8, 8
.const SCROLL_BOX_SIZE, 10
.const RANDOM_PIXEL_BATCH, 64
.const RANDOM_LINE_BATCH, 4
.const SMALL_CHAR_CYCLE_LEN, 6
.const BIG_TEXT_BYTE_COUNT, 256

; Vaiheiden kestot millisekunteina (B- ja C-kierros jakavat samat kestot)
phase_ticks_table:
        .dw 10000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 10000, 30000

.state_text 0, 0,  "B1: satunnaiset pikselit"
.state_text 1, 0,  "B2: satunnaiset viivat"
.state_text 2, 0,  "B3: skrollaus oikealle"
.state_text 3, 0,  "B4: skrollaus vasemmalle"
.state_text 4, 0,  "B5: skrollaus ylos"
.state_text 5, 0,  "B6: skrollaus alas"
.state_text 6, 0,  "B7: pienta tekstia"
.state_text 7, 0,  "B8: isoa tekstia"
.state_text 8, 0,  "B9: pacman sprite"
.state_text 9, 0,  "B10: sprite tormays"
.state_text 10, 0, "C1: satunnaiset pikselit"
.state_text 11, 0, "C2: satunnaiset viivat"
.state_text 12, 0, "C3: skrollaus oikealle"
.state_text 13, 0, "C4: skrollaus vasemmalle"
.state_text 14, 0, "C5: skrollaus ylos"
.state_text 15, 0, "C6: skrollaus alas"
.state_text 16, 0, "C7: pienta tekstia"
.state_text 17, 0, "C8: isoa tekstia"
.state_text 18, 0, "C9: pacman sprite"
.state_text 19, 0, "C10: sprite tormays"

phase:
        .dw 0
drawn_phase:
        .dw 0xFFFF
drawn_anim_step:
        .dw 0xFFFF
phase_subticks:
        .dw 0
anim_step:
        .dw 0
anim_ms_accum:
        .dw 0
current_mode:
        .dw 0
last_clock_ms:
        .dw 0xFFFF
seeded_phase:
        .dw 0xFFFF

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

fill_small_chars:
        .dstr "ABCDEF"
one_char_buf:
        .db 0, 0
msg_col0:
        .dstr "C0"
msg_col1:
        .dstr "C1"
msg_col2:
        .dstr "C2"

sprite_pacman_open_8x8:
        .db 0x3C, 0x7E, 0xEC, 0xF8, 0xF8, 0xEC, 0x7E, 0x3C
sprite_pacman_closed_8x8:
        .db 0x3C, 0x7E, 0xEE, 0xFF, 0xFF, 0xEE, 0x7E, 0x3C
sprite_ghost_8x8:
        .db 0x3C, 0x7E, 0xDB, 0xFF, 0xFF, 0xE7, 0xA5, 0x00

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

_read_clock_minute_ms:
_rcmm_retry:
        READ  R0, [CLOCK_SECOND]
        READ  R1, [CLOCK_MILLIS]
        READ  R2, [CLOCK_SECOND]
        CMP   R0, R2
        JNZ   _rcmm_retry
        READ  R3, 1000
        MUL   R2, R3
        ADD   R2, R1
        CPY   R0, R2
        RET

_update_clock_state:
        CALL  _read_clock_minute_ms   ; R0 = second*1000 + millis (0..59999)
        READ  R1, [last_clock_ms]
        READ  R2, 0xFFFF
        CMP   R1, R2
        JNZ   _ucs_have_prev
        STORE [last_clock_ms], R0
        RET

_ucs_have_prev:
        CPY   R2, R0
        SUB   R2, R1                  ; delta_ms = now - prev
        READ  R3, 0
        CMP   R2, R3
        JGE   _ucs_delta_ok
        READ  R3, 60000               ; minuutin sisainen wrap
        ADD   R2, R3
_ucs_delta_ok:
        STORE [last_clock_ms], R0

        READ  R3, 0
        CMP   R2, R3
        JLE   _ucs_phase_check

        READ  R0, [phase_subticks]
        ADD   R0, R2
        STORE [phase_subticks], R0

        READ  R0, [anim_ms_accum]
        ADD   R0, R2
_ucs_anim_loop:
        READ  R1, ANIM_TICK_MS
        CMP   R0, R1
        JLT   _ucs_anim_store
        SUB   R0, R1
        READ  R1, [anim_step]
        READ  R3, 1
        ADD   R1, R3
        STORE [anim_step], R1
        JUMP  _ucs_anim_loop
_ucs_anim_store:
        STORE [anim_ms_accum], R0

_ucs_phase_check:
        READ  R0, [phase]
        CALL  _get_phase_tick_limit   ; R2 = vaiheen kesto ms
        READ  R0, [phase_subticks]
        CMP   R0, R2
        JLT   _ucs_done
        SUB   R0, R2
        STORE [phase_subticks], R0

        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, PHASE_COUNT
        CMP   R0, R1
        JLT   _ucs_store_phase
        READ  R0, 0
_ucs_store_phase:
        STORE [phase], R0
        JUMP  _ucs_phase_check

_ucs_done:
        RET

_rand_u16:
        READ  R0, [RAND_MMIO]
        RET

_rand_range:
        ; Sisaan R0=max_inclusive, ulos R0=0..max
        ; Clobbers: R1-R5
        CPY   R3, R0
        READ  R1, 1
        ADD   R1, R3                  ; n = max + 1
        CPY   R5, R1                  ; _rand_u16 clobberoi R1/R2, talleta n
        READ  R4, 0
        CMP   R1, R4
        JNZ   _rr_div_ok
        ; Reuna-arvo: jos n wrapataan nollaksi (max=0xFFFF), palaa 0
        READ  R0, 0
        RET
_rr_div_ok:
        CALL  _rand_u16               ; R0 = rand
        CPY   R1, R5                  ; palauta n jakajaksi
        CPY   R2, R0                  ; R2 = rand
        CPY   R3, R2
        DIV   R3, R1                  ; q
        MUL   R3, R1                  ; q*n
        SUB   R2, R3                  ; rand % n
        CPY   R0, R2
        RET

_draw_random_pixel:
        CALL  _get_demo_bounds
        CPY   R8, R2                  ; xmax
        CPY   R9, R3                  ; ymax
        CPY   R0, R8
        CALL  _rand_range
        CPY   R10, R0                 ; x
        CPY   R0, R9
        CALL  _rand_range
        CPY   R1, R0
        CPY   R0, R10
        CALL  gfx_pixel
        RET

_draw_random_line:
        CALL  _get_demo_bounds
        CPY   R8, R2                  ; xmax
        CPY   R9, R3                  ; ymax

        CPY   R0, R8
        CALL  _rand_range
        CPY   R10, R0                 ; x0
        CPY   R0, R9
        CALL  _rand_range
        CPY   R11, R0                 ; y0

        CPY   R0, R8
        CALL  _rand_range
        CPY   R2, R0                  ; x1
        CPY   R0, R9
        CALL  _rand_range
        CPY   R3, R0                  ; y1

        CPY   R0, R10
        CPY   R1, R11
        CALL  gfx_line
        RET

_draw_random_pixels_batch:
        CALL  _get_demo_bounds
        CPY   R8, R2                  ; xmax
        CPY   R9, R3                  ; ymax
        READ  R12, RANDOM_PIXEL_BATCH
_drpb_loop:
        READ  R0, 0
        CMP   R12, R0
        JLE   _drpb_done

        CPY   R0, R8
        CALL  _rand_range
        CPY   R10, R0                 ; x
        CPY   R0, R9
        CALL  _rand_range
        CPY   R1, R0
        CPY   R0, R10
        CALL  gfx_pixel

        READ  R0, 1
        SUB   R12, R0
        JUMP  _drpb_loop
_drpb_done:
        RET

_draw_random_lines_batch:
        CALL  _get_demo_bounds
        CPY   R14, R2                 ; xmax
        CPY   R15, R3                 ; ymax
        READ  R13, RANDOM_LINE_BATCH
_drlb_loop:
        READ  R0, 0
        CMP   R13, R0
        JLE   _drlb_done

        CPY   R0, R14
        CALL  _rand_range
        CPY   R10, R0                 ; x0
        CPY   R0, R15
        CALL  _rand_range
        CPY   R11, R0                 ; y0

        CPY   R0, R14
        CALL  _rand_range
        CPY   R2, R0
        CPY   R0, R15
        CALL  _rand_range
        CPY   R3, R0

        CPY   R0, R10
        CPY   R1, R11
        CALL  gfx_line

        READ  R0, 1
        SUB   R13, R0
        JUMP  _drlb_loop
_drlb_done:
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
        CALL  _emit_state_bc_9
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
        STATE 10
        RET
_esbc0_b:
        STATE 0
        RET

_emit_state_bc_1:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc1_b
        STATE 11
        RET
_esbc1_b:
        STATE 1
        RET

_emit_state_bc_2:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc2_b
        STATE 12
        RET
_esbc2_b:
        STATE 2
        RET

_emit_state_bc_3:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc3_b
        STATE 13
        RET
_esbc3_b:
        STATE 3
        RET

_emit_state_bc_4:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc4_b
        STATE 14
        RET
_esbc4_b:
        STATE 4
        RET

_emit_state_bc_5:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc5_b
        STATE 15
        RET
_esbc5_b:
        STATE 5
        RET

_emit_state_bc_6:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc6_b
        STATE 16
        RET
_esbc6_b:
        STATE 6
        RET

_emit_state_bc_7:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc7_b
        STATE 17
        RET
_esbc7_b:
        STATE 7
        RET

_emit_state_bc_8:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc8_b
        STATE 18
        RET
_esbc8_b:
        STATE 8
        RET

_emit_state_bc_9:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_B
        CMP   R0, R1
        JZ    _esbc9_b
        STATE 19
        RET
_esbc9_b:
        STATE 9
        RET

_begin_seeded_phase:
        READ  R0, [phase]
        READ  R1, [seeded_phase]
        CMP   R0, R1
        JZ    _bsp_no
        STORE [seeded_phase], R0
        READ  R0, 1
        RET
_bsp_no:
        READ  R0, 0
        RET

_draw_center_scroll_square:
        CALL  _get_demo_bounds
        READ  R4, 1
        ADD   R2, R4                  ; width
        ADD   R3, R4                  ; height
        READ  R4, SCROLL_BOX_SIZE
        SUB   R2, R4
        SUB   R3, R4
        READ  R4, 2
        DIV   R2, R4
        DIV   R3, R4

        CPY   R0, R2
        CPY   R1, R3
        READ  R2, SCROLL_BOX_SIZE
        READ  R3, SCROLL_BOX_SIZE
        READ  R4, 1
        READ  R5, GFX_DRAW_FG
        CALL  gfx_rect
        RET

_init_scroll_phase_frame:
        CALL  _begin_seeded_phase
        READ  R1, 1
        CMP   R0, R1
        JNZ   _ispf_no
        CALL  _draw_center_scroll_square
        CALL  gfx_flip
        READ  R0, 1
_ispf_no:
        RET

_draw_letter_grid_small:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_C
        CMP   R0, R1
        JZ    _dlgs_mode_c
        READ  R6, 9
        READ  R7, 16
        JUMP  _dlgs_setup
_dlgs_mode_c:
        READ  R6, 19
        READ  R7, 32
_dlgs_setup:
        READ  R8, 0                   ; y
        READ  R15, 0                  ; pattern idx
_dlgs_row:
        READ  R0, 0
        CMP   R6, R0
        JLE   _dlgs_done

        READ  R5, 0                   ; x
        CPY   R4, R7                  ; cols remaining
_dlgs_col:
        READ  R0, 0
        CMP   R4, R0
        JLE   _dlgs_next_row

        READ  R0, fill_small_chars
        ADD   R0, R15
        READ  R1, [R0]
        STORE [one_char_buf], R1

        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R15
        READ  R0, one_char_buf
        CPY   R1, R5
        CPY   R2, R8
        CALL  gfx_draw_text_small
        POP   R15
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4

        READ  R0, 5
        ADD   R5, R0
        READ  R0, 1
        ADD   R15, R0
        READ  R0, SMALL_CHAR_CYCLE_LEN
        CMP   R15, R0
        JLT   _dlgs_pat_ok
        READ  R15, 0
_dlgs_pat_ok:
        READ  R0, 1
        SUB   R4, R0
        JUMP  _dlgs_col

_dlgs_next_row:
        READ  R0, 5
        ADD   R8, R0
        READ  R0, 1
        SUB   R6, R0
        JUMP  _dlgs_row
_dlgs_done:
        RET

_draw_letter_grid_big:
        READ  R0, [current_mode]
        READ  R1, GFX_MODE_C
        CMP   R0, R1
        JZ    _dlgb_mode_c
        READ  R6, 6
        READ  R7, 11
        READ  R15, 0x20              ; B-tilassa näytä luettavat printable-merkit ensin
        JUMP  _dlgb_setup
_dlgb_mode_c:
        READ  R6, 12
        READ  R7, 23
        READ  R15, 0x00              ; C-tilassa näytä koko 0x00..0xFF-alue
_dlgb_setup:
        READ  R8, 0                   ; y
_dlgb_row:
        READ  R0, 0
        CMP   R6, R0
        JLE   _dlgb_done

        READ  R5, 0                   ; x
        CPY   R4, R7                  ; cols remaining
_dlgb_col:
        READ  R0, 0
        CMP   R4, R0
        JLE   _dlgb_next_row

        PUSH  R4
        PUSH  R5
        PUSH  R6
        PUSH  R7
        PUSH  R8
        PUSH  R15
        CPY   R0, R15
        CPY   R1, R5
        CPY   R2, R8
        CALL  gfx_draw_char_big
        POP   R15
        POP   R8
        POP   R7
        POP   R6
        POP   R5
        POP   R4

        READ  R0, 7
        ADD   R5, R0
        READ  R0, 1
        ADD   R15, R0
        READ  R0, BIG_TEXT_BYTE_COUNT
        CMP   R15, R0
        JLT   _dlgb_pat_ok
        READ  R15, 0
_dlgb_pat_ok:
        READ  R0, 1
        SUB   R4, R0
        JUMP  _dlgb_col

_dlgb_next_row:
        READ  R0, 8
        ADD   R8, R0
        READ  R0, 1
        SUB   R6, R0
        JUMP  _dlgb_row
_dlgb_done:
        RET

demo_phase1_random_pixels:
        CALL  _set_mode_only

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        CALL  _draw_random_pixels_batch
        CALL  gfx_flip
        RET

demo_phase2_random_lines:
        CALL  _set_mode_only

        READ  R0, GFX_DRAW_XOR
        CALL  gfx_set_draw_mode
        CALL  _draw_random_lines_batch
        CALL  gfx_flip
        RET

demo_phase3_scroll_right:
        CALL  _set_mode_only
        CALL  _init_scroll_phase_frame
        READ  R1, 1
        CMP   R0, R1
        JZ    _dp3_done
        READ  R0, 1
        CALL  gfx_scroll_right
        CALL  gfx_flip
_dp3_done:
        RET

demo_phase4_scroll_left:
        CALL  _set_mode_only
        CALL  _init_scroll_phase_frame
        READ  R1, 1
        CMP   R0, R1
        JZ    _dp4_done
        READ  R0, 1
        CALL  gfx_scroll_left
        CALL  gfx_flip
_dp4_done:
        RET

demo_phase5_scroll_up:
        CALL  _set_mode_only
        CALL  _init_scroll_phase_frame
        READ  R1, 1
        CMP   R0, R1
        JZ    _dp5_done
        READ  R0, 1
        CALL  gfx_scroll_up
        CALL  gfx_flip
_dp5_done:
        RET

demo_phase6_scroll_down:
        CALL  _set_mode_only
        CALL  _init_scroll_phase_frame
        READ  R1, 1
        CMP   R0, R1
        JZ    _dp6_done
        READ  R0, 1
        CALL  gfx_scroll_down
        CALL  gfx_flip
_dp6_done:
        RET

demo_phase7_small_text:
        CALL  _begin_seeded_phase
        READ  R1, 1
        CMP   R0, R1
        JNZ   _dp7_done

        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_letter_grid_small
        CALL  gfx_flip
_dp7_done:
        RET

demo_phase8_big_text:
        CALL  _begin_seeded_phase
        READ  R1, 1
        CMP   R0, R1
        JNZ   _dp8_done

        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode
        CALL  _draw_letter_grid_big
        CALL  gfx_flip
_dp8_done:
        RET

demo_phase9_pacman:
        CALL  _draw_common_mode
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        READ  R0, [anim_step]
        READ  R1, 1
        AND   R0, R1
        CMP   R0, R1
        JZ    _dp9_closed
        READ  R14, sprite_pacman_open_8x8
        JUMP  _dp9_have_sprite
_dp9_closed:
        READ  R14, sprite_pacman_closed_8x8
_dp9_have_sprite:

        CALL  _update_pacman_random
        READ  R0, [pac_x]
        READ  R1, [pac_y]
        CPY   R2, R14
        CALL  _draw_sprite_8x8
        CALL  gfx_flip
        RET

demo_phase10_collision:
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
        READ  R2, sprite_pacman_open_8x8
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
        JZ    demo_phase1_random_pixels
        READ  R1, 1
        CMP   R0, R1
        JZ    demo_phase2_random_lines
        READ  R1, 2
        CMP   R0, R1
        JZ    demo_phase3_scroll_right
        READ  R1, 3
        CMP   R0, R1
        JZ    demo_phase4_scroll_left
        READ  R1, 4
        CMP   R0, R1
        JZ    demo_phase5_scroll_up
        READ  R1, 5
        CMP   R0, R1
        JZ    demo_phase6_scroll_down
        READ  R1, 6
        CMP   R0, R1
        JZ    demo_phase7_small_text
        READ  R1, 7
        CMP   R0, R1
        JZ    demo_phase8_big_text
        READ  R1, 8
        CMP   R0, R1
        JZ    demo_phase9_pacman
        CALL  demo_phase10_collision
        RET

main:
        READ  R0, 0
        STORE [phase], R0
        STORE [phase_subticks], R0
        STORE [anim_step], R0
        STORE [anim_ms_accum], R0
        STORE [drawn_phase], 0xFFFF
        STORE [drawn_anim_step], 0xFFFF
        STORE [last_clock_ms], 0xFFFF
        STORE [seeded_phase], 0xFFFF

        READ  R0, GFX_MODE_B
        STORE [current_mode], R0

        READ  R0, 1
        CALL  gfx_set_flip_enabled

main_loop:
        CALL  _update_clock_state
        READ  R4, [phase]
        READ  R1, [drawn_phase]
        CMP   R4, R1
        JZ    _frame_gate

        STORE [drawn_phase], R4
        READ  R0, 0xFFFF
        STORE [drawn_anim_step], R0
        STORE [seeded_phase], R0
        CPY   R0, R4
        CALL  _set_mode_and_base_phase
        CPY   R5, R0
        CALL  _draw_common_mode
        CPY   R0, R5
        CALL  _emit_state_for_base_phase

_frame_gate:
        READ  R6, [anim_step]
        READ  R1, [drawn_anim_step]
        CMP   R6, R1
        JZ    main_loop
        STORE [drawn_anim_step], R6

_draw_frame:
        CPY   R0, R4
        CALL  _set_mode_and_base_phase ; R0 -> base phase, asettaa moodin
        CALL  _dispatch_base_phase
        JUMP  main_loop
