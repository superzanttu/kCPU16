; =============================================================================
; test_shl.asm — SHL regD, regS
; Looginen siirto vasemmalle: regD = regD << regS.
; =============================================================================

        .origin 0x0200

        ; 1 << 3 = 8
        LOAD  R0, 1
        LOAD  R1, 3
        SHL   R0, R1

        ; 1 << 8 = 256 = 0x0100
        LOAD  R2, 1
        LOAD  R3, 8
        SHL   R2, R3

        HALT

.expect_reg   R0, 8
.expect_reg   R2, 256
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
