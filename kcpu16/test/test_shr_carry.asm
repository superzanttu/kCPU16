; =============================================================================
; test_shr_carry.asm — SHR carry-lippu (C)
; Carry = viimeisin oikealle siirtynyt bitti (LSB ennen siirtoa).
; 0x0007 >> 1: LSB (=1) siirtyy ulos → C=1, tulos = 3
; =============================================================================

        .origin 0x0200

        JARI  R0, 0x0007      ; ...0111 — LSB on 1
        JARI  R1, 1
        SHR   R0, R1          ; 7 >> 1 = 3, C=1

        HALT

.expect_reg   R0, 3
.expect_flag  C, 1
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  V, 0
