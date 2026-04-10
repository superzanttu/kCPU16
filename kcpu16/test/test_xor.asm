; =============================================================================
; test_xor.asm — XOR regD, regS
; Bittitason XOR: regD = regD ^ regS.
; C ja V nollataan aina.
; =============================================================================

        .origin 0x0200

        ; 0xAAAA ^ 0x5555 = 0xFFFF (kaikki bitit vaihdettu)
        READ  R0, 0xAAAA
        READ  R1, 0x5555
        XOR   R0, R1

        ; X ^ X = 0 aina — Z=1
        READ  R2, 0xFFFF
        XOR   R2, R2

        HALT

.expect_reg   R0, 0xFFFF
.expect_reg   R2, 0
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
