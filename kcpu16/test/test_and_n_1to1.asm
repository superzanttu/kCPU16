; =============================================================================
; test_and_n_1to1.asm — AND: N-lippu 1→1 (eksplisiittinen loppuarvo)
; Kun N=1 ennen AND:ia ja AND:n tulos on myös negatiivinen → N:1→1.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta N=1 (0→1)
        READ  R0, 0x8001
        READ  R1, 0xFFFF
        AND   R0, R1          ; 0x8001 & 0xFFFF = 0x8001: N=1

        ; Vaihe 2: AND tuottaa N=1 uudelleen → N:1→1
        READ  R0, 0x8002
        READ  R1, 0xFFFF
        AND   R0, R1          ; 0x8002 & 0xFFFF = 0x8002: N=1 (1→1)

        HALT

.expect_reg   R0, 0x8002
.expect_flag  N, 1           ; N: 1→1
.expect_flag  Z, 0
.expect_flag  C, 0
.expect_flag  V, 0
