; =============================================================================
; test_jump.asm — JUMP addr
; Ehdoton hyppy: PC = addr, jatko suoritetaan hypätystä osoitteesta.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 1
        JUMP  skip            ; hyppää yli seuraavan käskyn
        LOAD  R0, 99          ; tätä ei suoriteta

skip:
        LOAD  R1, 2
        HALT

.expect_reg   R0, 1           ; 99:ää ei kirjoitettu
.expect_reg   R1, 2
