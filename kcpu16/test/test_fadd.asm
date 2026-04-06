; =============================================================================
; test_fadd.asm — FADD regD, regS
; Liukuluku yhteenlasku (IEEE 754 float16).
; FADD regD, regS: regD = float16(regD) + float16(regS)
; =============================================================================
; float16-arvot:
;   1.0 = 0x3C00
;   2.0 = 0x4000
;   3.0 = 0x4200

        .origin 0x0200

        LOAD  R0, 0x3C00      ; R0 = 1.0 (float16)
        LOAD  R1, 0x4000      ; R1 = 2.0 (float16)
        FADD  R0, R1          ; R0 = 1.0 + 2.0 = 3.0 = 0x4200

        HALT

.expect_reg   R0, 0x4200      ; 3.0 float16
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
