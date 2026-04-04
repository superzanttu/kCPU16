; =============================================================================
; test_sub_borrow.asm — SUB borrow-lippu (C)
; Kun vähennetään suuremmasta pienempää → aliuirtuu → C=1.
; 5 − 10 = −5 → 16-bittisenä: 0xFFFB, C=1, N=1
; =============================================================================

        .origin 0x0200

        LOAD  R0, 5
        LOAD  R1, 10
        SUB   R0, R1          ; 5 − 10 = −5 → R0=0xFFFB, C=1

        HALT

.expect_reg   R0, 0xFFFB
.expect_flag  C, 1            ; a < b → borrow
.expect_flag  N, 1            ; bitti 15 asetettu
.expect_flag  Z, 0
.expect_flag  V, 0
