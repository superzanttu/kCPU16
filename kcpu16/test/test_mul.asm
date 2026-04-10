; =============================================================================
; test_mul.asm — MUL regD, regS
; Kertolasku: regD = regD × regS.
; Testaa normaalin tuloksen sekä kertolaskun nollalla (Z=1).
; =============================================================================

        .origin 0x0200

        READ  R0, 6
        READ  R1, 7
        MUL   R0, R1          ; R0 = 6 × 7 = 42

        READ  R2, 0
        READ  R3, 100
        MUL   R2, R3          ; R2 = 0 × 100 = 0 → Z=1

        HALT

.expect_reg   R0, 42
.expect_reg   R2, 0
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
