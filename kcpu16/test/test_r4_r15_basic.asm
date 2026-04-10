; =============================================================================
; test_r4_r15_basic.asm — LOAD rekistereihin R4-R15
; Testaa että kaikkiin uusiin GPR-rekistereihin voi ladata arvon
; ja lukea sen takaisin.
; =============================================================================

        .origin 0x0200

        READ  R4,  10
        READ  R5,  20
        READ  R6,  30
        READ  R7,  40
        READ  R8,  50
        READ  R9,  60
        READ  R10, 70
        READ  R11, 80
        READ  R12, 90
        READ  R13, 100
        READ  R14, 200
        READ  R15, 300

        HALT

.expect_reg   R4,  10
.expect_reg   R5,  20
.expect_reg   R6,  30
.expect_reg   R7,  40
.expect_reg   R8,  50
.expect_reg   R9,  60
.expect_reg   R10, 70
.expect_reg   R11, 80
.expect_reg   R12, 90
.expect_reg   R13, 100
.expect_reg   R14, 200
.expect_reg   R15, 300
