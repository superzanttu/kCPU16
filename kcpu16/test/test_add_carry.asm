; =============================================================================
; test_add_carry.asm — ADD carry-lippu (C)
; Etumerkitön ylivuoto: tulos ei mahdu 16 bittiin → C=1.
; 0xFFFE + 3 = 65537 → katkaistu 0x0001, C=1
; =============================================================================

        .origin 0x0200

        READ  R0, 0xFFFE
        READ  R1, 3
        ADD   R0, R1          ; 65534 + 3 = 65537 → R0=1, C=1

        HALT

.expect_reg   R0, 1
.expect_flag  C, 1
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  V, 0
