; =============================================================================
; test_mul_nv_1to1.asm — MUL: N, V liput 1→1
; 2 × 0x4000 = 0x8000: V=1, N=1, C=0, Z=0
; Toistetaan sama → N:1→1, V:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta N=1, V=1 (0→1)
        JARI  R0, 2
        JARI  R1, 0x4000
        MUL   R0, R1          ; 2×16384=0x8000: N=1, V=1, C=0, Z=0

        ; Vaihe 2: sama operaatio → N:1→1, V:1→1
        JARI  R0, 2
        JARI  R1, 0x4000
        MUL   R0, R1          ; 0x8000: N=1, V=1 (1→1)

        HALT

.expect_reg   R0, 0x8000
.expect_flag  N, 1           ; N: 1→1
.expect_flag  V, 1           ; V: 1→1
.expect_flag  Z, 0
.expect_flag  C, 0
