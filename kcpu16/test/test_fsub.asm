; =============================================================================
; test_fsub.asm — FSUB regD, regS
; Liukuluku vähennyslasku (IEEE 754 float16).
; FSUB regD, regS: regD = float16(regD) - float16(regS)
; =============================================================================
; float16-arvot:
;   3.0 = 0x4200
;   1.0 = 0x3C00
;   2.0 = 0x4000

        .origin 0x0200

        LOAD  R0, 0x4200      ; R0 = 3.0 (float16)
        LOAD  R1, 0x3C00      ; R1 = 1.0 (float16)
        FSUB  R0, R1          ; R0 = 3.0 - 1.0 = 2.0 = 0x4000

        HALT

.expect_reg   R0, 0x4000      ; 2.0 float16
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
