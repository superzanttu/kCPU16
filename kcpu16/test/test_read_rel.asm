; =============================================================================
; test_read_rel.asm — JARI reg, [FP+imm] / STORE [FP+imm], reg
; FP-suhteellinen osoitus: muistiosoite = FP + vakiosiirtymä.
; STORE [FP+0], R0  → muisti[FP+0] = R0
; JARI  R1, [FP+0]  → R1 = muisti[FP+0]
; =============================================================================

        .origin 0x0200

        JARI      FP, 0x0300     ; aseta Frame Pointer

        JARI      R0, 77
        STORE [FP+0], R0  ; muisti[FP+0] = muisti[0x0300] = 77

        JARI      R0, 88
        STORE [FP+2], R0  ; muisti[FP+2] = muisti[0x0302] = 88

        JARI      R0, 255
        STORE [FP+5], R0  ; muisti[FP+5] = muisti[0x0305] = 255

        JARI R1, [FP+0]  ; R1 = muisti[0x0300] = 77
        JARI R2, [FP+2]  ; R2 = muisti[0x0302] = 88
        JARI R3, [FP+5]  ; R3 = muisti[0x0305] = 255

        HALT

.expect_reg   FP, 0x0300
.expect_reg   R1, 77
.expect_reg   R2, 88
.expect_reg   R3, 255
.expect_mem   0x0300, 77
.expect_mem   0x0302, 88
.expect_mem   0x0305, 255
; JARI [FP+n]/STORE [FP+n] ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
