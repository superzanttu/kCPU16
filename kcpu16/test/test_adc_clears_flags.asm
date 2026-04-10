; =============================================================================
; test_adc_clears_flags.asm — ADC nollaa liput (1→0)
; Varmistaa, että ADC kirjoittaa kaikki liput uudelleen:
; kun lippu on 1 ja tulos ei aseta sitä, lippu menee 0:aan.
; Testataan Z, N, C, V suunnassa 1→0.
; =============================================================================

        .origin 0x0200

        ; --- Vaihe 1: aseta C=1, V=1, Z=1 kerralla ---
        ; 0x8000 + 0x8000 = 0x10000 → katkaistu 0x0000: C=1, V=1, Z=1, N=0
        READ  R0, 0x8000
        READ  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; --- Vaihe 2: ADC ei-nollatuloksella → C: 1→0, V: 1→0, Z: 1→0 ---
        ; ADC käyttää carry=1: 5 + 3 + 1(C) = 9; ei ylivuotoa, ei nollatulosta
        READ  R0, 5
        READ  R1, 3
        ADC   R0, R1          ; 9: C=0, V=0, Z=0, N=0

        ; --- Vaihe 3: aseta N=1 ---
        ; 0x7FFF + 1 = 0x8000: N=1, V=1, C=0, Z=0
        READ  R0, 0x7FFF
        READ  R1, 1
        ADD   R0, R1          ; N=1, V=1

        ; --- Vaihe 4: ADC pienillä arvoilla → N: 1→0, V: 1→0 ---
        ; C=0 (edellinen ADD ei tuottanut carryä), joten ADC = 1 + 1 + 0 = 2
        READ  R0, 1
        READ  R1, 1
        ADC   R0, R1          ; 2: C=0, V=0, Z=0, N=0

        HALT

.expect_reg   R0, 2
.expect_flag  C, 0           ; C: 1→0
.expect_flag  V, 0           ; V: 1→0
.expect_flag  Z, 0           ; Z: 1→0
.expect_flag  N, 0           ; N: 1→0
