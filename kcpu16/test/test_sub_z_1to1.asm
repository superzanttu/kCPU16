; =============================================================================
; test_sub_z_1to1.asm — SUB: Z-lippu 1→1
; Varmistaa, että kun Z=1 jo ennen SUB:ia, SUB pitää sen 1:nä
; jos tulos on jälleen nolla (a - a = 0).
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta Z=1 (0→1)
        READ  R0, 42
        READ  R1, 42
        SUB   R0, R1          ; 42-42=0: Z=1, N=0, C=0, V=0

        ; Vaihe 2: uusi nollatulos → Z:1→1
        READ  R0, 99
        READ  R1, 99
        SUB   R0, R1          ; 99-99=0: Z=1 (1→1)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
