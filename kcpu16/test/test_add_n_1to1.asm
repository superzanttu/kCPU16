; =============================================================================
; test_add_n_1to1.asm — ADD: N, V liput 1→1
; Varmistaa, että kun N=1 ja V=1 ovat jo 1, ADD pitää ne 1:nä
; jos tulos on jälleen negatiivinen etumerkillisesti.
; 0x4001 + 0x4001 = 0x8002 → N=1, V=1 (positiivinen+positiivinen=negatiivinen)
; Toistetaan → N:1→1, V:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta N=1, V=1 (0→1)
        JARI  R0, 0x4001
        JARI  R1, 0x4001
        ADD   R0, R1          ; 0x4001+0x4001=0x8002: N=1, V=1, C=0, Z=0

        ; Vaihe 2: sama rakenne uudelleen → N:1→1, V:1→1
        JARI  R0, 0x4002
        JARI  R1, 0x4002
        ADD   R0, R1          ; 0x4002+0x4002=0x8004: N=1, V=1 (1→1)

        HALT

.expect_reg   R0, 0x8004
.expect_flag  N, 1           ; N: 1→1
.expect_flag  V, 1           ; V: 1→1
.expect_flag  Z, 0           ; tulos != 0
.expect_flag  C, 0           ; ei ylivuotoa unsigned
