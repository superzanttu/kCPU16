; =============================================================================
; test_shl_carry.asm — SHL carry-lippu (C)
; Carry = viimeisin ulos vasemmalta siirtynyt bitti.
; 0x8001 << 1: bitti 15 (=1) siirtyy ulos → C=1, tulos = 0x0002
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0x8001      ; bitti 15 ja bitti 0 asetettu
        LOAD  R1, 1
        SHL   R0, R1          ; 0x8001 << 1 = 0x0002, C=1

        HALT

.expect_reg   R0, 2
.expect_flag  C, 1
.expect_flag  Z, 0
.expect_flag  N, 0
