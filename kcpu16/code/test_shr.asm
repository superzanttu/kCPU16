; =============================================================================
; test_shr.asm — SHR regD, regS
; Looginen siirto oikealle: regD = regD >> regS (ylä-bitit täytetään nollilla).
; =============================================================================

        .origin 0x0200

        ; 32 >> 3 = 4
        LOAD  R0, 32
        LOAD  R1, 3
        SHR   R0, R1

        ; 0x0100 >> 4 = 0x0010 = 16
        LOAD  R2, 0x0100
        LOAD  R3, 4
        SHR   R2, R3

        HALT

.expect_reg   R0, 4
.expect_reg   R2, 16
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
