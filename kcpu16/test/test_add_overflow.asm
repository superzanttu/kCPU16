; =============================================================================
; test_add_overflow.asm — ADD overflow-lippu (V)
; Etumerkillinen ylivuoto: positiivinen + positiivinen = negatiivinen → V=1.
; 0x7FFF + 1 = 0x8000 (−32768 etumerkillisessä tulkinnassa)
; =============================================================================

        .origin 0x0200

        READ  R0, 0x7FFF      ; 32767 (suurin positiivinen 16-bittinen luku)
        READ  R1, 1
        ADD   R0, R1          ; 32767 + 1 → R0=0x8000, V=1

        HALT

.expect_reg   R0, 0x8000
.expect_flag  V, 1
.expect_flag  N, 1            ; bitti 15 asetettu
.expect_flag  C, 0
.expect_flag  Z, 0
