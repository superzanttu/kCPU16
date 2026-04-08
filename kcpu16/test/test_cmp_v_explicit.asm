; =============================================================================
; test_cmp_v_explicit.asm — CMP: V-lippu 0→1 (eksplisiittinen loppuarvo)
; 0x7FFF vs 0xFFFF → V=1 (signed overflow: +32767 − (−1) = +32768 > +32767)
; CMP ei muuta operandeja.
; =============================================================================

        .origin 0x0200

        JARI  R0, 0x7FFF
        JARI  R1, 0xFFFF
        CMP   R0, R1          ; 0x7FFF-0xFFFF: V=1, C=1, N=1, Z=0

        HALT

.expect_reg   R0, 0x7FFF      ; CMP ei muuta R0
.expect_reg   R1, 0xFFFF      ; CMP ei muuta R1
.expect_flag  V, 1           ; V: 0→1 (etumerkillinen ylivuoto)
.expect_flag  C, 1           ; C: 0→1 (borrow: 0x7FFF < 0xFFFF)
.expect_flag  N, 1           ; N: 0→1 (0x8000 bitti 15)
.expect_flag  Z, 0
