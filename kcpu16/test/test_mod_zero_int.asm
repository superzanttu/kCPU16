; =============================================================================
; test_mod_zero_int.asm — MOD jakajalla 0 laukaisee INT 0
; Testaa että jakojäännös nollalla laukaisee keskeytyksen 0.
; =============================================================================

        .origin 0x0200

        ; Aseta keskeytysvektori 0 (INT_DIV_ZERO)
        LOAD  R0, mod_handler
        STORE [0x0000], R0

        ; Yritä laskea jakojäännös nollalla
        LOAD  R0, 99
        LOAD  R1, 0
        MOD   R0, R1          ; jakaja = 0 -> INT 0

        ; Tänne palataan handler:ista (MOD ohitettu)
        LOAD  R2, 88
        HALT

mod_handler:
        LOAD  R3, 0xDEAD      ; merkki: handler suoritettiin
        ; Ohita MOD-käsky: pop SR ja PC, lisää 3 (MOD koko), push takaisin
        POP   R0               ; old_SR
        POP   R1               ; old_PC (osoittaa MOD:iin)
        LOAD  R2, 3
        ADD   R1, R2           ; old_PC + 3 = ohita MOD
        PUSH  R1               ; korjattu PC
        PUSH  R0               ; SR takaisin
        IRET

.expect_reg   R3, 0xDEAD      ; zero-mod handler suoritettiin
.expect_reg   R2, 88          ; palattiin MOD:n jälkeiseen käskyyn
