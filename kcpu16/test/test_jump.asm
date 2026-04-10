; =============================================================================
; test_jump.asm — JUMP addr
; Ehdoton hyppy: PC = addr, jatko suoritetaan hypätystä osoitteesta.
; =============================================================================

        .origin 0x0200

        READ  R0, 1
        JUMP  skip            ; hyppää yli seuraavan käskyn
        READ  R0, 99          ; tätä ei suoriteta

skip:
        READ  R1, 2
        HALT

.expect_reg   R0, 1           ; 99:ää ei kirjoitettu
.expect_reg   R1, 2
; JUMP ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
