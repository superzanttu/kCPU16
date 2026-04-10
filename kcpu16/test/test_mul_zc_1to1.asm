; =============================================================================
; test_mul_zc_1to1.asm — MUL: Z, C liput 1→1
; 0x100 × 0x100 = 0x10000 → R0=0: Z=1, C=1, V=0, N=0
; Toistetaan sama → Z:1→1, C:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta Z=1, C=1 (0→1)
        READ  R0, 0x100
        READ  R1, 0x100
        MUL   R0, R1          ; 256×256=65536→0: Z=1, C=1, V=0, N=0

        ; Vaihe 2: sama operaatio → Z:1→1, C:1→1
        READ  R0, 0x100
        READ  R1, 0x100
        MUL   R0, R1          ; Z=1, C=1 (1→1)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  C, 1           ; C: 1→1
.expect_flag  N, 0
.expect_flag  V, 0
