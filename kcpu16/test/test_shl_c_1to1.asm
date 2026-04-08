; =============================================================================
; test_shl_c_1to1.asm — SHL: C-lippu 1→1
; SHL asettaa C:n viimeisen ulos siirtyneen bitin mukaan.
; 0x8001 << 1 = 0x0002: C=1 (bitti 15 siirtyi ulos)
; Toistetaan → C:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1 (0→1)
        JARI  R0, 0x8001
        JARI  R1, 1
        SHL   R0, R1          ; 0x8001 << 1 = 0x0002: C=1, Z=0, N=0

        ; Vaihe 2: SHL tuottaa C=1 uudelleen → C:1→1
        JARI  R0, 0x8002
        JARI  R1, 1
        SHL   R0, R1          ; 0x8002 << 1 = 0x0004: C=1 (1→1), Z=0, N=0

        HALT

.expect_reg   R0, 0x0004
.expect_flag  C, 1           ; C: 1→1 (bitti 15 siirtyi ulos)
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  V, 0           ; SHL nollaa V aina
