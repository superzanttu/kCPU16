; =============================================================================
; test_add_flags_1to1.asm — ADD: Z, C, V liput 1→1
; Varmistaa, että kun Z=1, C=1 ja V=1 ovat jo 1, ADD pitää ne 1:nä
; jos tulos aiheuttaa samat liput uudelleen.
; 0x8000 + 0x8000 = 0x10000 → R0=0: Z=1, C=1, V=1, N=0
; Toistetaan sama operaatio → Z:1→1, C:1→1, V:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta Z=1, C=1, V=1 (0→1)
        READ  R0, 0x8000
        READ  R1, 0x8000
        ADD   R0, R1          ; 0x8000+0x8000=0x10000→0: Z=1, C=1, V=1, N=0

        ; Vaihe 2: sama operaatio uudelleen → Z:1→1, C:1→1, V:1→1
        READ  R0, 0x8000
        READ  R1, 0x8000
        ADD   R0, R1          ; Z=1, C=1, V=1 (1→1 kaikille)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  C, 1           ; C: 1→1
.expect_flag  V, 1           ; V: 1→1
.expect_flag  N, 0           ; N: 0→0 (tulos=0, bitti 15=0)
