; =============================================================================
; test_r4_r15_arithmetic.asm — Laskutoimitukset R4-R15-rekistereillä
; ADD, SUB, MUL, DIV käyttäen uusia rekistereitä.
; =============================================================================

        .origin 0x0200

        ; ADD: R4 + R5
        LOAD  R4, 100
        LOAD  R5, 42
        ADD   R4, R5           ; R4 = 100 + 42 = 142

        ; SUB: R6 - R7
        LOAD  R6, 200
        LOAD  R7, 55
        SUB   R6, R7           ; R6 = 200 - 55 = 145

        ; MUL: R8 * R9
        LOAD  R8, 7
        LOAD  R9, 6
        MUL   R8, R9           ; R8 = 7 * 6 = 42

        ; DIV: R10 / R11
        LOAD  R10, 100
        LOAD  R11, 4
        DIV   R10, R11         ; R10 = 100 / 4 = 25

        ; Sekaoperaatio: R12 = R13 + R14 + R15
        LOAD  R13, 10
        LOAD  R14, 20
        LOAD  R15, 30
        CPY   R12, R13
        ADD   R12, R14         ; R12 = 30
        ADD   R12, R15         ; R12 = 60

        HALT

.expect_reg   R4,  142
.expect_reg   R6,  145
.expect_reg   R8,  42
.expect_reg   R10, 25
.expect_reg   R12, 60
