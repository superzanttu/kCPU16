; =============================================================================
; test_mul_v_1to0.asm — MUL: V-lippu 1→0 (eksplisiittinen loppuarvo)
; Asetetaan V=1 ADD:lla, sitten MUL tuottaa ei-ylivuotoavan tuloksen → V:1→0.
; MUL asettaa V:n uudelleen (ylikirjoittaa).
; =============================================================================

        .origin 0x0200

        ; Aseta V=1 ADD:lla (0x7FFF + 1 = 0x8000: signed overflow → V=1)
        LOAD  R0, 0x7FFF
        LOAD  R1, 1
        ADD   R0, R1          ; V=1, N=1, C=0, Z=0

        ; MUL pienillä arvoilla → V=0 (V:1→0)
        LOAD  R0, 2
        LOAD  R1, 4
        MUL   R0, R1          ; 2 × 4 = 8: V=0 (1→0), C=0, Z=0, N=0

        HALT

.expect_reg   R0, 8
.expect_flag  V, 0           ; V: 1→0 (MUL ylikirjoittaa V:n)
.expect_flag  C, 0
.expect_flag  Z, 0
.expect_flag  N, 0
