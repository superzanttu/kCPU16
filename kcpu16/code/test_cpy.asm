; =============================================================================
; test_cpy.asm — CPY regD, regS
; Kopioi rekisterin arvo toiseen rekisteriin.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 123
        CPY   R1, R0          ; R1 = R0 = 123
        CPY   R2, R1          ; R2 = R1 = 123
        LOAD  R3, 99
        CPY   R3, R0          ; R3 = R0 = 123 (ylikirjoitus)

        HALT

.expect_reg   R0, 123
.expect_reg   R1, 123
.expect_reg   R2, 123
.expect_reg   R3, 123
