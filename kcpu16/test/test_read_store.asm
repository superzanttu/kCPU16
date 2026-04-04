; =============================================================================
; test_read_store.asm — READ reg, addr / STORE reg, addr
; Kirjoittaa arvon muistiosoitteelle ja lukee sen takaisin.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0xABCD
        STORE R0, 0x0300      ; muisti[0x0300] = 0xABCD
        READ  R1, 0x0300      ; R1 = muisti[0x0300]

        LOAD  R2, 0x1234
        STORE R2, 0x0301      ; muisti[0x0301] = 0x1234
        READ  R3, 0x0301      ; R3 = muisti[0x0301]

        HALT

.expect_reg   R1, 0xABCD
.expect_reg   R3, 0x1234
.expect_mem   0x0300, 0xABCD
.expect_mem   0x0301, 0x1234
