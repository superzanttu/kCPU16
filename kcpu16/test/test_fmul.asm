; =============================================================================
; test_fmul.asm — FMUL regD, regS
; Liukuluku kertolasku (IEEE 754 float16).
; FMUL regD, regS: regD = float16(regD) * float16(regS)
; =============================================================================
; float16-arvot:
;   2.0 = 0x4000
;   3.0 = 0x4200
;   6.0 = 0x4600

        .origin 0x0200

        LOAD  R0, 0x4000      ; R0 = 2.0 (float16)
        LOAD  R1, 0x4200      ; R1 = 3.0 (float16)
        FMUL  R0, R1          ; R0 = 2.0 * 3.0 = 6.0 = 0x4600

        HALT

.expect_reg   R0, 0x4600      ; 6.0 float16
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
