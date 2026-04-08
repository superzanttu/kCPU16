; =============================================================================
; test_shl_z_1to1.asm — SHL: Z-lippu 1→1 (eksplisiittinen loppuarvo)
; 0x8000 << 1 = 0x0000: Z=1, C=1
; Toistetaan → Z:1→1, C:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta Z=1, C=1 (0→1)
        JARI  R0, 0x8000
        JARI  R1, 1
        SHL   R0, R1          ; 0x8000 << 1 = 0: Z=1, C=1

        ; Vaihe 2: SHL tuottaa Z=1, C=1 uudelleen → Z:1→1, C:1→1
        JARI  R0, 0x8000
        JARI  R1, 1
        SHL   R0, R1          ; Z=1 (1→1), C=1 (1→1)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  C, 1           ; C: 1→1
.expect_flag  N, 0
.expect_flag  V, 0           ; SHL nollaa V aina
