; =============================================================================
; test_itof.asm — ITOF regD, regS
; Kokonaisluku -> float16 muunnos (IEEE 754 half-precision).
; ITOF regD, regS: regD = float16(regS)
; =============================================================================
; float16-arvot:
;   42.0 = 0x5140
;    0.0 = 0x0000
;    1.0 = 0x3C00

        .origin 0x0200

        LOAD  R1, 42
        ITOF  R0, R1          ; R0 = float16(42) = 0x5140

        LOAD  R3, 1
        ITOF  R2, R3          ; R2 = float16(1) = 0x3C00

        HALT

.expect_reg   R0, 0x5140      ; 42.0 float16
.expect_reg   R2, 0x3C00      ; 1.0 float16
