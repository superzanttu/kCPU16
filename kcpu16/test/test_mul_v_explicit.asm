; =============================================================================
; test_mul_v_explicit.asm — MUL: V-lippu 0→1 (eksplisiittinen tarkistus)
; 2 × 0x4000 = 0x8000:
;   V=1 (etumerkillinen ylivuoto: +2 × +16384 = +32768 > +32767)
;   N=1 (bitti 15 asetettu: 0x8000)
;   C=0 (0x8000 ≤ 0xFFFF)
; Varmistaa, että MUL asettaa V-lipun 0→1.
; =============================================================================

        .origin 0x0200

        READ  R0, 2
        READ  R1, 0x4000
        MUL   R0, R1          ; 2 × 16384 = 32768 = 0x8000: V=1, N=1, C=0, Z=0

        HALT

.expect_reg   R0, 0x8000
.expect_flag  V, 1           ; V: 0→1 (etumerkillinen ylivuoto)
.expect_flag  N, 1           ; N: bitti 15 asetettu
.expect_flag  C, 0           ; ei unsigned ylivuotoa
.expect_flag  Z, 0
