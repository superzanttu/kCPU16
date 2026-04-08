; =============================================================================
; test_storei.asm — STORE [addr], imm (välitön arvo suoraan muistiosoitteeseen)
; Kirjoittaa vakioarvon suoraan muistiosoitteeseen ilman rekisteriä.
; Assembler tuottaa STOREI-opkoodin kun STORE:n lähde ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        ; Kirjoita desimaaliluku suoraan muistiosoitteeseen
        STORE [0x0300], 77  ; muisti[0x0300] = 77

        ; Kirjoita heksaluku muistiosoitteeseen
        STORE [0x0301], 0xABCD  ; muisti[0x0301] = 0xABCD

        ; Kirjoita nolla muistiosoitteeseen (erityistapaus)
        STORE [0x0302], 0  ; muisti[0x0302] = 0

        ; Kirjoita 0xFFFF muistiosoitteeseen (maksimarvo)
        STORE [0x0303], 0xFFFF  ; muisti[0x0303] = 0xFFFF

        ; Lue takaisin ja tarkista
        JARI R0, [0x0300]  ; R0 = 77
        JARI R1, [0x0301]  ; R1 = 0xABCD
        JARI R2, [0x0302]  ; R2 = 0
        JARI R3, [0x0303]  ; R3 = 0xFFFF

        HALT

.expect_reg   R0, 77
.expect_reg   R1, 0xABCD
.expect_reg   R2, 0
.expect_reg   R3, 0xFFFF
.expect_mem   0x0300, 77
.expect_mem   0x0301, 0xABCD
.expect_mem   0x0302, 0
.expect_mem   0x0303, 0xFFFF
; STOREI ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
