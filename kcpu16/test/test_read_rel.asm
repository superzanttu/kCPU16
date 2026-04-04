; =============================================================================
; test_read_rel.asm — READ_REL reg, imm / STORE_REL reg, imm
; FP-suhteellinen osoitus: muistiosoite = FP + vakiosiirtymä.
; STORE_REL R0, 0   → muisti[FP+0] = R0
; READ_REL  R1, 0   → R1 = muisti[FP+0]
; =============================================================================

        .origin 0x0200

        LOAD      FP, 0x0300     ; aseta Frame Pointer

        LOAD      R0, 77
        STORE_REL R0, 0          ; muisti[FP+0] = muisti[0x0300] = 77

        LOAD      R0, 88
        STORE_REL R0, 2          ; muisti[FP+2] = muisti[0x0302] = 88

        LOAD      R0, 255
        STORE_REL R0, 5          ; muisti[FP+5] = muisti[0x0305] = 255

        READ_REL  R1, 0          ; R1 = muisti[0x0300] = 77
        READ_REL  R2, 2          ; R2 = muisti[0x0302] = 88
        READ_REL  R3, 5          ; R3 = muisti[0x0305] = 255

        HALT

.expect_reg   FP, 0x0300
.expect_reg   R1, 77
.expect_reg   R2, 88
.expect_reg   R3, 255
.expect_mem   0x0300, 77
.expect_mem   0x0302, 88
.expect_mem   0x0305, 255
