; =============================================================================
; test_or.asm — OR regD, regS
; Bittitason TAI: regD = regD | regS.
; C ja V nollataan aina.
; =============================================================================

        .origin 0x0200

        ; 0xFF00 | 0x00FF = 0xFFFF → N=1 (bitti 15 asetettu)
        LOAD  R0, 0xFF00
        LOAD  R1, 0x00FF
        OR    R0, R1

        HALT

.expect_reg   R0, 0xFFFF
.expect_flag  N, 1
.expect_flag  Z, 0
.expect_flag  C, 0
.expect_flag  V, 0
