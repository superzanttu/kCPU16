; =============================================================================
; test_sub_overflow.asm — SUB overflow-lippu (V)
; Etumerkillinen ylivuoto: negatiivinen − positiivinen = positiivinen → V=1.
; 0x8000 (−32768) − 1 = 0x7FFF (+32767) — tulos vaihtoi etumerkin → V=1
; =============================================================================

        .origin 0x0200

        READ  R0, 0x8000      ; −32768 etumerkillisessä tulkinnassa
        READ  R1, 1
        SUB   R0, R1          ; 0x8000 − 1 = 0x7FFF, V=1

        HALT

.expect_reg   R0, 0x7FFF
.expect_flag  V, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  Z, 0
