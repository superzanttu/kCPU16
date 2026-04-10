; =============================================================================
; test_not.asm — NOT reg
; Bittitason komplementti: reg = ~reg (kaikki bitit käännetään).
; =============================================================================

        .origin 0x0200

        ; ~0x0000 = 0xFFFF → N=1
        READ  R0, 0x0000
        NOT   R0

        ; ~0xFFFF = 0x0000 → Z=1
        READ  R1, 0xFFFF
        NOT   R1

        HALT

.expect_reg   R0, 0xFFFF
.expect_reg   R1, 0
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
