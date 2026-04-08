; =============================================================================
; test_r4_r15_basic.asm — LOAD rekistereihin R4-R15
; Testaa että kaikkiin uusiin GPR-rekistereihin voi ladata arvon
; ja lukea sen takaisin.
; =============================================================================

        .origin 0x0200

        LOAD  R4,  10
        LOAD  R5,  20
        LOAD  R6,  30
        LOAD  R7,  40
        LOAD  R8,  50
        LOAD  R9,  60
        LOAD  R10, 70
        LOAD  R11, 80
        LOAD  R12, 90
        LOAD  R13, 100
        LOAD  R14, 200
        LOAD  R15, 300

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
