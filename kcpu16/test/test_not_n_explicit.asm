; =============================================================================
; test_not_n_explicit.asm — NOT: N-lippu 0→1 (eksplisiittinen loppuarvo)
; ~0x0000 = 0xFFFF → N=1 (bitti 15 asetettu)
; Varmistaa, että NOT asettaa N-lipun 0→1.
; =============================================================================

        .origin 0x0200

        JARI  R0, 0x0000
        NOT   R0              ; R0 = ~0x0000 = 0xFFFF: N=1 (0→1)

        HALT

.expect_reg   R0, 0xFFFF
.expect_flag  N, 1           ; N: 0→1 (bitti 15 asetettu)
.expect_flag  Z, 0
.expect_flag  C, 0
.expect_flag  V, 0
