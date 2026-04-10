; Example 1: Simple macro with .origin
; This program demonstrates macros and custom origin address

.origin 0x0300

.macro INIT_REGS
    LOAD R0, 10
    LOAD R1, 20
    LOAD R2, 0
.endmacro

.macro ADD_THREE
    ADD R0, R1
    ADD R0, R2
.endmacro

START:
    ; Initialize registers
    INIT_REGS

    ; Add immediate 5 to R2 via temporary register
    LOAD R3, 5
    ADD  R2, R3

    ; Add all three: R0 = R0 + R1 + R2 = 10 + 20 + 5 = 35
    ADD_THREE

    ; Store result in R3
    CPY R3, R0

    HALT
