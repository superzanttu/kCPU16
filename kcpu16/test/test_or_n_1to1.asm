; =============================================================================
; test_or_n_1to1.asm — OR: N-lippu 1→1 (eksplisiittinen loppuarvo)
; Kun N=1 ennen OR:ia ja OR:n tulos on myös negatiivinen → N:1→1.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta N=1 (0→1)
        LOAD  R0, 0x8001
        LOAD  R1, 0x0001
        OR    R0, R1          ; 0x8001 | 0x0001 = 0x8001: N=1

        ; Vaihe 2: OR tuottaa N=1 uudelleen → N:1→1
        LOAD  R0, 0x8002
        LOAD  R1, 0x0002
        OR    R0, R1          ; 0x8002 | 0x0002 = 0x8002: N=1 (1→1)

        HALT

.expect_reg   R0, 0x8002
.expect_flag  N, 1           ; N: 1→1
.expect_flag  Z, 0
.expect_flag  C, 0
.expect_flag  V, 0
