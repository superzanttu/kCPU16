; =============================================================================
; test_read_store.asm — JARI reg, [addr] / STORE [addr], reg
; Kirjoittaa arvon muistiosoitteelle ja lukee sen takaisin.
; =============================================================================

        .origin 0x0200

        JARI  R0, 0xABCD
        STORE [0x0300], R0  ; muisti[0x0300] = 0xABCD
        JARI R1, [0x0300]  ; R1 = muisti[0x0300]

        JARI  R2, 0x1234
        STORE [0x0301], R2  ; muisti[0x0301] = 0x1234
        JARI R3, [0x0301]  ; R3 = muisti[0x0301]

        HALT

.expect_reg   R1, 0xABCD
.expect_reg   R3, 0x1234
.expect_mem   0x0300, 0xABCD
.expect_mem   0x0301, 0x1234
; JARI/STORE ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
