; =============================================================================
; test_r4_r15_stack.asm — PUSH/POP R4-R15
; Testaa että uusia rekistereitä voi tallentaa pinoon ja palauttaa.
; =============================================================================

        .origin 0x0200

        READ  R4,  0xABCD
        READ  R8,  0x1234
        READ  R15, 0x5678

        PUSH  R4               ; pino: [0xABCD]
        PUSH  R8               ; pino: [0xABCD, 0x1234]
        PUSH  R15              ; pino: [0xABCD, 0x1234, 0x5678]

        ; Nollaa rekisterit varmistaaksemme että POP hakee pinosta
        READ  R4,  0
        READ  R8,  0
        READ  R15, 0

        POP   R15              ; R15 = 0x5678
        POP   R8               ; R8  = 0x1234
        POP   R4               ; R4  = 0xABCD

        HALT

.expect_reg   R4,  0xABCD
.expect_reg   R8,  0x1234
.expect_reg   R15, 0x5678
