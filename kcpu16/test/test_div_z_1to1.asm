; =============================================================================
; test_div_z_1to1.asm — DIV: Z-lippu 1→1
; 0 / n = 0 → Z=1
; Toistetaan → Z:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: DIV tuottaa Z=1 (0→1)
        JARI  R0, 0
        JARI  R1, 5
        DIV   R0, R1          ; 0/5=0: Z=1, N=0

        ; Vaihe 2: DIV tuottaa Z=1 uudelleen → Z:1→1
        JARI  R0, 0
        JARI  R1, 3
        DIV   R0, R1          ; 0/3=0: Z=1 (1→1)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  N, 0
.expect_flag  C, 0           ; DIV ei kosketa C:tä (oli 0)
.expect_flag  V, 0           ; DIV ei kosketa V:tä (oli 0)
