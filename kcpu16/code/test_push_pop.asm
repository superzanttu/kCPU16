; =============================================================================
; test_push_pop.asm — PUSH reg / POP reg
; PUSH tallentaa rekisterin pinoon, POP hakee sen takaisin.
; Pino toimii LIFO-periaatteella (Last In, First Out).
; =============================================================================

        .origin 0x0200

        LOAD  R0, 100
        LOAD  R1, 200

        PUSH  R0              ; pino: [100]         SP=0xFFFE
        PUSH  R1              ; pino: [100, 200]    SP=0xFFFD

        POP   R2              ; R2 = 200 (viimeksi työnnetty)
        POP   R3              ; R3 = 100 (ensimmäisenä työnnetty)

        HALT

.expect_reg   R2, 200
.expect_reg   R3, 100
