; =============================================================================
; test_shl_flags_1to1.asm — SHL: Z, C, N liput 1→1
; SHL asettaa Z, N, C tulosteen mukaan; V nollataan aina.
; =============================================================================

        .origin 0x0200

        ; --- Z 1→1: SHL tuottaa nollan kun Z oli jo 1 ---
        ; Vaihe 1: 0x8000 << 1 = 0x0000: Z=1 (0→1)
        JARI  R0, 0x8000
        JARI  R1, 1
        SHL   R0, R1          ; Z=1, C=1 (bitti 15 ulos)

        ; Vaihe 2: 0x8000 << 1 uudelleen → Z=1 (1→1), C=1 (1→1)
        JARI  R0, 0x8000
        JARI  R1, 1
        SHL   R0, R1          ; Z=1 (1→1), C=1 (1→1)
        CPY   R2, R0          ; tallenna R2=0

        ; --- C 1→1: SHL tuottaa carryn kun C oli jo 1 (jatkuu yllä) ---
        ; C on 1 nyt (Z=1, C=1 vaiheesta 2). Tehdään uusi SHL joka antaa C=1:
        JARI  R0, 0x8001
        JARI  R1, 1
        SHL   R0, R1          ; 0x8001 << 1 = 0x0002: C=1 (1→1), Z=0, N=0

        ; --- N 1→1: SHL tuottaa negatiivisen kun N oli jo 1 ---
        ; Vaihe 1: 0x0001 << 15 = 0x8000: N=1, C=0 (0→1)
        JARI  R0, 0x0001
        JARI  R1, 15
        SHL   R0, R1          ; 0x8000: N=1 (0→1), C=0, Z=0

        ; Vaihe 2: 0x0002 << 14 = 0x8000: N=1 (1→1), C=0
        JARI  R0, 0x0002
        JARI  R1, 14
        SHL   R0, R1          ; 0x8000: N=1 (1→1)

        HALT

.expect_reg   R2, 0           ; Z 1→1 tarkistus
.expect_reg   R0, 0x8000      ; N 1→1 tarkistus
.expect_flag  N, 1           ; N: 1→1
.expect_flag  Z, 0           ; viimeinen SHL ei-nolla
.expect_flag  C, 0           ; 0x0002 << 14: bitti 1 siirtyy kohtaan 15 (bitti 15 ei läähde ulos)
.expect_flag  V, 0           ; SHL nollaa V aina
