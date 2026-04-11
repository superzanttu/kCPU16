; =============================================================================
; chip-8.asm — CHIP-8-emulaattori kCPU16:lle
; =============================================================================
;
; Toteuttaa CHIP-8:n perustoiminnallisuuden:
; - 4 KB CHIP-8-muisti (1 tavu / 1 sana)
; - V0..VF, I, PC, SP, DT, ST, 16-tason stack
; - fetch/decode/dispatch-silmukka
; - keskeinen opcode-joukko (00E0, 00EE, 1..F-ryhmät)
; - 64x32 framebuffer + XOR-piirto + VF-collision
; - näppäimistö (INT 6) + FX0A-odotus
; - ajastimet DT/ST (INT 9)
; - ROM-moduulin lataus chip2asm.py-tuotoksesta
;
; Aja esim:
;   python main.py run kcpu16/code/chip-8.asm
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; -----------------------------------------------------------------------------
; Vakiot
; -----------------------------------------------------------------------------
.const CH8_MEM,      0x6000
.const CH8_MEM_END,  0x6FFF
.const CH8_FB,       0x5000
.const CH8_FB_END,   0x57FF
.const CH8_FB_W,     64
.const CH8_FB_H,     32
.const KEYMAP,       0x4000
.const KEYMAP_END,   0x407F
.const TICK_MS,      17
.const SCR_OFS_X,    8
.const SCR_OFS_Y,    8

; -----------------------------------------------------------------------------
; Emulaattorin tila
; -----------------------------------------------------------------------------
chip8_v:
        .db 0, 0, 0, 0, 0, 0, 0, 0
        .db 0, 0, 0, 0, 0, 0, 0, 0
chip8_i:
        .db 0
chip8_pc:
        .db 0x0200
chip8_sp:
        .db 0
chip8_dt:
        .db 0
chip8_st:
        .db 0
chip8_keymask:
        .db 0
chip8_wait_vx:
        .db 0xFFFF      ; 0..15 = odottaa tähän VX:ään, 0xFFFF = ei odotusta
chip8_last_key:
        .db 0

chip8_stack:
        .db 0, 0, 0, 0, 0, 0, 0, 0
        .db 0, 0, 0, 0, 0, 0, 0, 0

chip8_font:
        .db 0xF0, 0x90, 0x90, 0x90, 0xF0
        .db 0x20, 0x60, 0x20, 0x20, 0x70
        .db 0xF0, 0x10, 0xF0, 0x80, 0xF0
        .db 0xF0, 0x10, 0xF0, 0x10, 0xF0
        .db 0x90, 0x90, 0xF0, 0x10, 0x10
        .db 0xF0, 0x80, 0xF0, 0x10, 0xF0
        .db 0xF0, 0x80, 0xF0, 0x90, 0xF0
        .db 0xF0, 0x10, 0x20, 0x40, 0x40
        .db 0xF0, 0x90, 0xF0, 0x90, 0xF0
        .db 0xF0, 0x90, 0xF0, 0x10, 0xF0
        .db 0xF0, 0x90, 0xF0, 0x90, 0x90
        .db 0xE0, 0x90, 0xE0, 0x90, 0xE0
        .db 0xF0, 0x80, 0x80, 0x80, 0xF0
        .db 0xE0, 0x90, 0x90, 0x90, 0xE0
        .db 0xF0, 0x80, 0xF0, 0x80, 0xF0
        .db 0xF0, 0x80, 0xF0, 0x80, 0x80

; -----------------------------------------------------------------------------
; Apualiohjelmat
; -----------------------------------------------------------------------------

; get_v_ptr: R10 = X, palauttaa R0 = &V[X]
get_v_ptr:
        READ  R0, chip8_v
        ADD   R0, R10
        RET

; get_vy_ptr: R11 = Y, palauttaa R1 = &V[Y]
get_vy_ptr:
        READ  R1, chip8_v
        ADD   R1, R11
        RET

; set_vf: R0 = 0/1
set_vf:
        READ  R1, chip8_v
        ADD   R1, 15
        STORE [R1], R0
        RET

; skip_next: PC += 2 (12-bit wrap)
skip_next:
        READ  R0, [chip8_pc]
        ADD   R0, 2
        READ  R1, 0x0FFF
        AND   R0, R1
        STORE [chip8_pc], R0
        RET

; stack_push: R0 = arvo
stack_push:
        READ  R1, [chip8_sp]
        CMP   R1, 16
        JGE   stack_push_done
        READ  R2, chip8_stack
        ADD   R2, R1
        STORE [R2], R0
        ADD   R1, 1
        STORE [chip8_sp], R1
stack_push_done:
        RET

; stack_pop: R0 = arvo
stack_pop:
        READ  R1, [chip8_sp]
        CMP   R1, 0
        JZ    stack_pop_empty
        SUB   R1, 1
        STORE [chip8_sp], R1
        READ  R2, chip8_stack
        ADD   R2, R1
        READ  R0, [R2]
        RET
stack_pop_empty:
        READ  R0, 0
        RET

; draw_screen: piirtää 64x32 CH8_FB -> tila B (80x48)
draw_screen:
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R8, 0
draw_y:
        CMP   R8, CH8_FB_H
        JGE   draw_done
        READ  R7, 0
draw_x:
        CMP   R7, CH8_FB_W
        JGE   draw_row_done

        CPY   R9, R8
        READ  R0, 6
        SHL   R9, R0
        ADD   R9, R7
        READ  R0, CH8_FB
        ADD   R9, R0
        READ  R0, [R9]
        CMP   R0, 0
        JZ    draw_next

        CPY   R3, R8
        ADD   R3, SCR_OFS_Y
        CPY   R4, R7
        ADD   R4, SCR_OFS_X

        CPY   R5, R3
        READ  R0, 1
        SHR   R5, R0
        READ  R0, 80
        MUL   R5, R0
        ADD   R5, R4
        READ  R0, VRAM_START
        ADD   R5, R0

        READ  R6, 1
        AND   R6, R3
        CMP   R6, 0
        JNZ   draw_lower
        READ  R6, 2
        JUMP  draw_plot

draw_lower:
        READ  R6, 1

draw_plot:
        READ  R0, [R5]
        OR    R0, R6
        STORE [R5], R0

draw_next:
        ADD   R7, 1
        JUMP  draw_x

draw_row_done:
        ADD   R8, 1
        JUMP  draw_y

draw_done:
        STORE [GFX_FLIP_REG], 1
        RET

; -----------------------------------------------------------------------------
; Keskeytykset
; -----------------------------------------------------------------------------

; INT 6: keyboard
kbd_handler:
        PUSH  R0
        PUSH  R1
        PUSH  R2
        PUSH  R3

        READ  R0, [KBD_DATA]
        CMP   R0, 0
        JZ    kbd_done

        READ  R1, KBD_RELEASE_BIT
        AND   R1, R0                     ; R1 = 0 tai 0x80
        READ  R2, KBD_KEY_CODE_MASK
        AND   R2, R0                     ; R2 = ASCII 0..127

        READ  R3, KEYMAP
        ADD   R3, R2
        READ  R3, [R3]                   ; R3 = key 0..15 tai 0xFF
        CMP   R3, 0xFF
        JZ    kbd_done

        READ  R2, 1
        SHL   R2, R3                     ; R2 = 1 << key

        READ  R0, [chip8_keymask]
        CMP   R1, 0
        JNZ   kbd_release

        OR    R0, R2                     ; press
        STORE [chip8_keymask], R0
        STORE [chip8_last_key], R3

        READ  R0, [chip8_wait_vx]
        CMP   R0, 0xFFFF
        JZ    kbd_done

        READ  R1, chip8_v
        ADD   R1, R0                     ; &V[wait_vx]
        STORE [R1], R3
        STORE [chip8_wait_vx], 0xFFFF
        JUMP  kbd_done

kbd_release:
        NOT   R2
        AND   R0, R2                     ; clear bit
        STORE [chip8_keymask], R0

kbd_done:
        POP   R3
        POP   R2
        POP   R1
        POP   R0
        IRET

; INT 9: 60 Hz clock
clk_handler:
        PUSH  R0
        PUSH  R1

        READ  R0, [chip8_dt]
        CMP   R0, 0
        JZ    clk_st
        SUB   R0, 1
        STORE [chip8_dt], R0

clk_st:
        READ  R0, [chip8_st]
        CMP   R0, 0
        JZ    clk_rearm
        SUB   R0, 1
        STORE [chip8_st], R0

clk_rearm:
        READ  R0, TICK_MS
        SCTMR R0

        POP   R1
        POP   R0
        IRET

; -----------------------------------------------------------------------------
; Opkoodikäsittelijät
; Konventio decode-vaiheen jälkeen:
;   R2 = opcode
;   R10 = X
;   R11 = Y
;   R12 = N
;   R13 = NN
;   R14 = NNN
;   R15 = type
; -----------------------------------------------------------------------------

op_0xxx:
        CMP   R13, 0xE0
        JNZ   op0_check_ret
        READ  R0, CH8_FB
        READ  R1, CH8_FB_END
        READ  R2, 0
        FILL  R0, R1, R2
        CALL  draw_screen
        RET

op0_check_ret:
        CMP   R13, 0xEE
        JNZ   op0_done
        CALL  stack_pop
        STORE [chip8_pc], R0
op0_done:
        RET

op_1nnn:
        STORE [chip8_pc], R14
        RET

op_2nnn:
        READ  R0, [chip8_pc]
        CALL  stack_push
        STORE [chip8_pc], R14
        RET

op_3xnn:
        CALL  get_v_ptr
        READ  R1, [R0]
        READ  R2, 0x00FF
        AND   R1, R2
        CMP   R1, R13
        JNZ   op3_done
        CALL  skip_next
op3_done:
        RET

op_4xnn:
        CALL  get_v_ptr
        READ  R1, [R0]
        READ  R2, 0x00FF
        AND   R1, R2
        CMP   R1, R13
        JZ    op4_done
        CALL  skip_next
op4_done:
        RET

op_5xy0:
        CMP   R12, 0
        JNZ   op5_done
        CALL  get_v_ptr
        READ  R2, [R0]
        CALL  get_vy_ptr
        READ  R3, [R1]
        READ  R4, 0x00FF
        AND   R2, R4
        AND   R3, R4
        CMP   R2, R3
        JNZ   op5_done
        CALL  skip_next
op5_done:
        RET

op_6xnn:
        CALL  get_v_ptr
        STORE [R0], R13
        RET

op_7xnn:
        CALL  get_v_ptr
        READ  R1, [R0]
        ADD   R1, R13
        READ  R2, 0x00FF
        AND   R1, R2
        STORE [R0], R1
        RET

op_8xyn:
        CALL  get_v_ptr
        READ  R3, [R0]                   ; VX
        CALL  get_vy_ptr
        READ  R4, [R1]                   ; VY
        READ  R5, 0x00FF
        AND   R3, R5
        AND   R4, R5

        CALLI R12, alu_0, alu_1, alu_2, alu_3, alu_4, alu_5, alu_6, alu_7, alu_nop, alu_nop, alu_nop, alu_nop, alu_nop, alu_nop, alu_E, alu_nop
        RET

alu_0:
        STORE [R0], R4
        RET

alu_1:
        OR    R3, R4
        STORE [R0], R3
        RET

alu_2:
        AND   R3, R4
        STORE [R0], R3
        RET

alu_3:
        XOR   R3, R4
        STORE [R0], R3
        RET

alu_4:
        ADD   R3, R4
        READ  R5, 0x0100
        CMP   R3, R5
        JLT   alu4_nocarry
        READ  R6, 1
        CPY   R0, R6
        CALL  set_vf
        READ  R5, 0x00FF
        AND   R3, R5
        CALL  get_v_ptr
        STORE [R0], R3
        RET
alu4_nocarry:
        READ  R6, 0
        CPY   R0, R6
        CALL  set_vf
        CALL  get_v_ptr
        STORE [R0], R3
        RET

alu_5:
        CMP   R3, R4
        JLT   alu5_borrow
        READ  R6, 1
        CPY   R0, R6
        CALL  set_vf
        CALL  get_v_ptr
        SUB   R3, R4
        STORE [R0], R3
        RET
alu5_borrow:
        READ  R6, 0
        CPY   R0, R6
        CALL  set_vf
        CALL  get_v_ptr
        SUB   R3, R4
        READ  R5, 0x00FF
        AND   R3, R5
        STORE [R0], R3
        RET

alu_6:
        CPY   R5, R3
        READ  R6, 1
        AND   R5, R6
        CPY   R0, R5
        CALL  set_vf
        CALL  get_v_ptr
        READ  R6, 1
        SHR   R3, R6
        STORE [R0], R3
        RET

alu_7:
        CMP   R4, R3
        JLT   alu7_borrow
        READ  R6, 1
        CPY   R0, R6
        CALL  set_vf
        CALL  get_v_ptr
        SUB   R4, R3
        STORE [R0], R4
        RET
alu7_borrow:
        READ  R6, 0
        CPY   R0, R6
        CALL  set_vf
        CALL  get_v_ptr
        SUB   R4, R3
        READ  R5, 0x00FF
        AND   R4, R5
        STORE [R0], R4
        RET

alu_E:
        CPY   R5, R3
        READ  R6, 7
        SHR   R5, R6
        READ  R6, 1
        AND   R5, R6
        CPY   R0, R5
        CALL  set_vf
        CALL  get_v_ptr
        READ  R6, 1
        SHL   R3, R6
        READ  R6, 0x00FF
        AND   R3, R6
        STORE [R0], R3
        RET

alu_nop:
        RET

op_9xy0:
        CMP   R12, 0
        JNZ   op9_done
        CALL  get_v_ptr
        READ  R2, [R0]
        CALL  get_vy_ptr
        READ  R3, [R1]
        READ  R4, 0x00FF
        AND   R2, R4
        AND   R3, R4
        CMP   R2, R3
        JZ    op9_done
        CALL  skip_next
op9_done:
        RET

op_annn:
        STORE [chip8_i], R14
        RET

op_bnnn:
        READ  R0, [chip8_v]
        READ  R1, 0x00FF
        AND   R0, R1
        ADD   R0, R14
        READ  R1, 0x0FFF
        AND   R0, R1
        STORE [chip8_pc], R0
        RET

op_cxnn:
        READ  R1, [RAND_MMIO]
        AND   R1, R13
        CALL  get_v_ptr
        STORE [R0], R1
        RET

op_dxyn:
        CALL  get_v_ptr
        READ  R4, [R0]
        READ  R1, 0x003F
        AND   R4, R1

        CALL  get_vy_ptr
        READ  R5, [R1]
        READ  R1, 0x001F
        AND   R5, R1

        READ  R0, 0
        CALL  set_vf

        READ  R6, [chip8_i]
        READ  R1, CH8_MEM
        ADD   R6, R1                     ; R6 = sprite ptr

        READ  R9, 0                      ; row
opd_row:
        CMP   R9, R12
        JGE   opd_done

        READ  R3, [R6]
        ADD   R6, 1

        CPY   R8, R5
        ADD   R8, R9
        READ  R1, 0x001F
        AND   R8, R1

        READ  R7, 0                      ; bit 0..7
opd_bit:
        CMP   R7, 8
        JGE   opd_next_row

        READ  R0, 0x0080
        SHR   R0, R7
        CPY   R1, R3
        AND   R1, R0
        CMP   R1, 0
        JZ    opd_skip

        CPY   R1, R4
        ADD   R1, R7
        READ  R2, 0x003F
        AND   R1, R2

        CPY   R2, R8
        READ  R0, 6
        SHL   R2, R0
        ADD   R2, R1
        READ  R0, CH8_FB
        ADD   R2, R0

        READ  R0, [R2]
        CMP   R0, 1
        JNZ   opd_xor
        READ  R0, 1
        CALL  set_vf
        ; set_vf käyttää R0 palautusarvona, joten hae pikseli uudestaan
        READ  R0, [R2]

opd_xor:
        READ  R1, 1
        XOR   R0, R1
        STORE [R2], R0

opd_skip:
        ADD   R7, 1
        JUMP  opd_bit

opd_next_row:
        ADD   R9, 1
        JUMP  opd_row

opd_done:
        CALL  draw_screen
        RET

op_exxx:
        CALL  get_v_ptr
        READ  R0, [R0]
        READ  R1, 0x000F
        AND   R0, R1                     ; key index 0..15
        READ  R1, 1
        SHL   R1, R0

        READ  R2, [chip8_keymask]
        AND   R2, R1                     ; 0 if not pressed

        CMP   R13, 0x9E
        JNZ   opex_a1
        CMP   R2, 0
        JZ    opex_done
        CALL  skip_next
        RET

opex_a1:
        CMP   R13, 0xA1
        JNZ   opex_done
        CMP   R2, 0
        JNZ   opex_done
        CALL  skip_next

opex_done:
        RET

op_fxxx:
        CMP   R13, 0x07
        JZ    fx_07
        CMP   R13, 0x0A
        JZ    fx_0A
        CMP   R13, 0x15
        JZ    fx_15
        CMP   R13, 0x18
        JZ    fx_18
        CMP   R13, 0x1E
        JZ    fx_1E
        CMP   R13, 0x29
        JZ    fx_29
        CMP   R13, 0x33
        JZ    fx_33
        CMP   R13, 0x55
        JZ    fx_55
        CMP   R13, 0x65
        JZ    fx_65
        RET

fx_07:
        READ  R1, [chip8_dt]
        CALL  get_v_ptr
        STORE [R0], R1
        RET

fx_0A:
        STORE [chip8_wait_vx], R10
        RET

fx_15:
        CALL  get_v_ptr
        READ  R1, [R0]
        STORE [chip8_dt], R1
        RET

fx_18:
        CALL  get_v_ptr
        READ  R1, [R0]
        STORE [chip8_st], R1
        RET

fx_1E:
        READ  R2, [chip8_i]
        CALL  get_v_ptr
        READ  R1, [R0]
        ADD   R2, R1
        READ  R1, 0x0FFF
        AND   R2, R1
        STORE [chip8_i], R2
        RET

fx_29:
        CALL  get_v_ptr
        READ  R0, [R0]
        READ  R1, 0x000F
        AND   R0, R1
        READ  R1, 5
        MUL   R0, R1
        STORE [chip8_i], R0
        RET

fx_33:
        CALL  get_v_ptr
        READ  R0, [R0]

        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1

        CPY   R3, R0
        READ  R1, 100
        DIV   R3, R1
        STORE [R2], R3
        ADD   R2, 1

        MUL   R3, R1
        SUB   R0, R3
        CPY   R3, R0
        READ  R1, 10
        DIV   R3, R1
        STORE [R2], R3
        ADD   R2, 1

        MUL   R3, R1
        SUB   R0, R3
        STORE [R2], R0
        RET

fx_55:
        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1
        READ  R3, chip8_v
        READ  R4, 0
fx55_loop:
        CMP   R4, R10
        JGT   fx55_done
        READ  R1, [R3]
        STORE [R2], R1
        ADD   R2, 1
        ADD   R3, 1
        ADD   R4, 1
        JUMP  fx55_loop
fx55_done:
        RET

fx_65:
        READ  R1, [chip8_i]
        READ  R2, CH8_MEM
        ADD   R2, R1
        READ  R3, chip8_v
        READ  R4, 0
fx65_loop:
        CMP   R4, R10
        JGT   fx65_done
        READ  R1, [R2]
        STORE [R3], R1
        ADD   R2, 1
        ADD   R3, 1
        ADD   R4, 1
        JUMP  fx65_loop
fx65_done:
        RET

; -----------------------------------------------------------------------------
; Main
; -----------------------------------------------------------------------------
main:
        STORE [INT_KEYBOARD], kbd_handler
        STORE [INT_CLOCK], clk_handler

        ; Nollaa emulaattorin tila
        READ  R0, chip8_v
        READ  R1, chip8_v
        ADD   R1, 15
        READ  R2, 0
        FILL  R0, R1, R2

        STORE [chip8_i], 0
        STORE [chip8_pc], 0x0200
        STORE [chip8_sp], 0
        STORE [chip8_dt], 0
        STORE [chip8_st], 0
        STORE [chip8_keymask], 0
        STORE [chip8_wait_vx], 0xFFFF
        STORE [chip8_last_key], 0

        ; Nollaa framebuffer ja CHIP-8-muisti
        READ  R0, CH8_FB
        READ  R1, CH8_FB_END
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R0, CH8_MEM
        READ  R1, CH8_MEM_END
        READ  R2, 0
        FILL  R0, R1, R2

        ; Kopioi fontti CH8_MEM[0..79]
        READ  R0, chip8_font
        READ  R1, CH8_MEM
        READ  R2, 80
font_copy_loop:
        CMP   R2, 0
        JZ    font_copy_done
        READ  R3, [R0]
        STORE [R1], R3
        ADD   R0, 1
        ADD   R1, 1
        SUB   R2, 1
        JUMP  font_copy_loop
font_copy_done:

        ; Alusta keymap (oletus 0xFF = ei mappausta)
        READ  R0, KEYMAP
        READ  R1, KEYMAP_END
        READ  R2, 0x00FF
        FILL  R0, R1, R2

        ; CHIP-8 keypad mapping (sekä isot että pienet kirjaimet)
        STORE [0x4031], 1    ; 1
        STORE [0x4032], 2    ; 2
        STORE [0x4033], 3    ; 3
        STORE [0x4034], 12   ; 4
        STORE [0x4071], 4    ; q
        STORE [0x4077], 5    ; w
        STORE [0x4065], 6    ; e
        STORE [0x4072], 13   ; r
        STORE [0x4061], 7    ; a
        STORE [0x4073], 8    ; s
        STORE [0x4064], 9    ; d
        STORE [0x4066], 14   ; f
        STORE [0x407A], 10   ; z
        STORE [0x4078], 0    ; x
        STORE [0x4063], 11   ; c
        STORE [0x4076], 15   ; v

        STORE [0x4051], 4    ; Q
        STORE [0x4057], 5    ; W
        STORE [0x4045], 6    ; E
        STORE [0x4052], 13   ; R
        STORE [0x4041], 7    ; A
        STORE [0x4053], 8    ; S
        STORE [0x4044], 9    ; D
        STORE [0x4046], 14   ; F
        STORE [0x405A], 10   ; Z
        STORE [0x4058], 0    ; X
        STORE [0x4043], 11   ; C
        STORE [0x4056], 15   ; V

        ; Lataa chip2asm-moduuli CH8_MEM + module_load_addr
        READ  R0, [chip8_mod_snake_load_addr]
        READ  R1, CH8_MEM
        ADD   R1, R0
        READ  R2, chip8_mod_snake_data
        READ  R3, [chip8_mod_snake_size]

module_copy_loop:
        CMP   R3, 0
        JZ    module_copy_done
        READ  R4, [R2]
        STORE [R1], R4
        ADD   R1, 1
        ADD   R2, 1
        SUB   R3, 1
        JUMP  module_copy_loop

module_copy_done:
        ; Käynnistä PC moduulin entryyn
        READ  R0, [chip8_mod_snake_entry_addr]
        STORE [chip8_pc], R0

        ; Aseta grafiikkatila B
        STORE [GFX_MODE_REG], GFX_MODE_B
        CALL  draw_screen

        ; Käynnistä 60 Hz ajastin + keskeytykset
        READ  R0, TICK_MS
        SCTMR R0
        STI

; -----------------------------------------------------------------------------
; Emulointisilmukka
; -----------------------------------------------------------------------------
emu_loop:
        ; FX0A-odotuksessa jäädään odottamaan key interruptia
        READ  R0, [chip8_wait_vx]
        CMP   R0, 0xFFFF
        JNZ   emu_loop

        ; Fetch opcode
        READ  R0, [chip8_pc]
        READ  R1, CH8_MEM
        ADD   R1, R0
        READ  R2, [R1]
        ADD   R1, 1
        READ  R3, [R1]
        READ  R4, 8
        SHL   R2, R4
        OR    R2, R3

        ; PC += 2
        READ  R0, [chip8_pc]
        ADD   R0, 2
        READ  R1, 0x0FFF
        AND   R0, R1
        STORE [chip8_pc], R0

        ; Decode
        CPY   R15, R2
        READ  R0, 12
        SHR   R15, R0
        READ  R0, 0x000F
        AND   R15, R0

        CPY   R10, R2
        READ  R0, 8
        SHR   R10, R0
        READ  R0, 0x000F
        AND   R10, R0

        CPY   R11, R2
        READ  R0, 4
        SHR   R11, R0
        READ  R0, 0x000F
        AND   R11, R0

        CPY   R12, R2
        READ  R0, 0x000F
        AND   R12, R0

        CPY   R13, R2
        READ  R0, 0x00FF
        AND   R13, R0

        CPY   R14, R2
        READ  R0, 0x0FFF
        AND   R14, R0

        CALLI R15, op_0xxx, op_1nnn, op_2nnn, op_3xnn, op_4xnn, op_5xy0, op_6xnn, op_7xnn, op_8xyn, op_9xy0, op_annn, op_bnnn, op_cxnn, op_dxyn, op_exxx, op_fxxx
        JUMP  emu_loop

; -----------------------------------------------------------------------------
; CHIP-8 ROM-moduuli (tuotettu chip2asm.py:llä)
; -----------------------------------------------------------------------------
        .include "chip8-snake.asm"
