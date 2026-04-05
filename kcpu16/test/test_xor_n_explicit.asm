; =============================================================================
; test_xor_n_explicit.asm — XOR: N-lippu 0→1 (eksplisiittinen loppuarvo)
; 0x0000 ^ 0xFFFF = 0xFFFF → N=1 (bitti 15 asetettu)
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0x0000
        LOAD  R1, 0xFFFF
        XOR   R0, R1          ; R0 = 0xFFFF: N=1 (0→1)

        HALT

.expect_reg   R0, 0xFFFF
.expect_flag  N, 1           ; N: 0→1
.expect_flag  Z, 0
.expect_flag  C, 0
.expect_flag  V, 0
