; =============================================================================
; test_and.asm — AND regD, regS
; Bittitason JA: regD = regD & regS.
; C ja V nollataan aina.
; =============================================================================

        .origin 0x0200

        ; 0xFF00 & 0x0F0F = 0x0F00
        READ  R0, 0xFF00
        READ  R1, 0x0F0F
        AND   R0, R1

        ; 0xFF00 & 0x00FF = 0x0000 → Z=1
        READ  R2, 0xFF00
        READ  R3, 0x00FF
        AND   R2, R3

        HALT

.expect_reg   R0, 0x0F00
.expect_reg   R2, 0
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
