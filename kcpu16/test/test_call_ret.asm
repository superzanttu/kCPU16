; =============================================================================
; test_call_ret.asm — CALL addr / RET
; CALL tallentaa paluuosoitteen pinoon ja hyppää aliohjelmaan.
; RET hakee paluuosoitteen pinosta ja jatkaa siitä.
; =============================================================================

        .origin 0x0200

        JARI  R0, 0           ; nollaa R0 ennen kutsua
        CALL  myproc          ; kutsu aliohjelma
        HALT                  ; palataan tänne

myproc:
        JARI  R0, 42          ; aliohjelma asettaa R0
        JARI  R1, 99
        RET                   ; palaa kutsujalle

.expect_reg   R0, 42
.expect_reg   R1, 99
; CALL/RET ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
