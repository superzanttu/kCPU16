; =============================================================================
; test_sub.asm — SUB regD, regS
; Perusvähennyslasku: regD = regD − regS.
; Tarkistaa tuloksen ja peruslippujen arvot.
; =============================================================================

        .origin 0x0200

        READ  R0, 50
        READ  R1, 30
        SUB   R0, R1          ; R0 = 50 − 30 = 20

        HALT

.expect_reg   R0, 20
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
