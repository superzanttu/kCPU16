; Example 1: Simple macro with .origin
; This program demonstrates macros and custom origin address

.origin 0x0300

.macro INIT_REGS
    LOAD R0, #10
    LOAD R1, #20
    LOAD R2, #0
.endmacro

.macro ADD_THREE
    ADD R0, R1
    ADD R0, R2
.endmacro

START:
    ; Initialize registers
    INIT_REGS

    ; Add values
    ADD R2, #5
    ADD_THREE

    ; Store result in R3
    CPY R3, R0

    HALT
