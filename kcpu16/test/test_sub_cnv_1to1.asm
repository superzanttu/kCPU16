; =============================================================================
; test_sub_cnv_1to1.asm — SUB: C, N, V liput 1→1
; 0x7FFF - 0xFFFF = 0x8000:
;   C=1 (borrow: 0x7FFF < 0xFFFF unsigned)
;   N=1 (bitti 15 asetettu: 0x8000)
;   V=1 (etumerkillinen ylivuoto: +32767 − (−1) = +32768 > +32767)
; Toistetaan sama → C:1→1, N:1→1, V:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1, N=1, V=1 (0→1)
        JARI  R0, 0x7FFF
        JARI  R1, 0xFFFF
        SUB   R0, R1          ; 0x7FFF-0xFFFF=0x8000: C=1, N=1, V=1, Z=0

        ; Vaihe 2: sama operaatio → C:1→1, N:1→1, V:1→1
        JARI  R0, 0x7FFF
        JARI  R1, 0xFFFF
        SUB   R0, R1          ; 0x8000: C=1, N=1, V=1 (1→1)

        HALT

.expect_reg   R0, 0x8000
.expect_flag  C, 1           ; C: 1→1 (borrow)
.expect_flag  N, 1           ; N: 1→1 (negatiivinen tulos)
.expect_flag  V, 1           ; V: 1→1 (etumerkillinen ylivuoto)
.expect_flag  Z, 0
