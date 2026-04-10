; =============================================================================
; test_add.asm — ADD regD, regS
; Perusyhteenlasku: regD = regD + regS.
; Tarkistaa tuloksen ja peruslippujen arvot (ei carry/overflow).
; =============================================================================

        .origin 0x0200

        READ  R0, 15
        READ  R1, 27
        ADD   R0, R1          ; R0 = 15 + 27 = 42

        HALT

.expect_reg   R0, 42
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
