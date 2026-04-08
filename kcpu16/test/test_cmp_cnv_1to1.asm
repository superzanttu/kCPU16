; =============================================================================
; test_cmp_cnv_1to1.asm — CMP: C, N, V liput 1→1
; 0x7FFF vs 0xFFFF: CMP (= SUB lippujen kannalta):
;   C=1 (borrow: 0x7FFF < 0xFFFF)
;   N=1 (bitti 15: 0x8000)
;   V=1 (etumerkillinen ylivuoto: +32767 − (−1) = +32768 > +32767)
; Toistetaan → C:1→1, N:1→1, V:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1, N=1, V=1 (0→1)
        JARI  R0, 0x7FFF
        JARI  R1, 0xFFFF
        CMP   R0, R1          ; C=1, N=1, V=1, Z=0

        ; Vaihe 2: sama vertailu → C:1→1, N:1→1, V:1→1
        JARI  R0, 0x7FFF
        JARI  R1, 0xFFFF
        CMP   R0, R1          ; C=1, N=1, V=1 (1→1)

        HALT

.expect_reg   R0, 0x7FFF      ; CMP ei muuta rekisterejä
.expect_reg   R1, 0xFFFF
.expect_flag  C, 1           ; C: 1→1
.expect_flag  N, 1           ; N: 1→1
.expect_flag  V, 1           ; V: 1→1
.expect_flag  Z, 0
