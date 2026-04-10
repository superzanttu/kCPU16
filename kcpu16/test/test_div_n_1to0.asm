; =============================================================================
; test_div_n_1to0.asm — DIV: N-lippu 1→0
; Asetetaan N=1 DIV:llä (0xFFFF/1=0xFFFF: N=1),
; sitten DIV tuottaa pienen positiivisen tuloksen → N:1→0.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta N=1 (0→1)
        READ  R0, 0xFFFF
        READ  R1, 1
        DIV   R0, R1          ; 0xFFFF / 1 = 0xFFFF: N=1

        ; Vaihe 2: DIV pienellä positiivisella tuloksella → N:1→0
        READ  R0, 10
        READ  R1, 2
        DIV   R0, R1          ; 10 / 2 = 5: N=0 (N:1→0), Z=0

        HALT

.expect_reg   R0, 5
.expect_flag  N, 0           ; N: 1→0
.expect_flag  Z, 0
.expect_flag  C, 0           ; DIV ei kosketa C:tä
.expect_flag  V, 0           ; DIV ei kosketa V:tä
