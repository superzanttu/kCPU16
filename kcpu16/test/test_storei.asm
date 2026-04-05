; =============================================================================
; test_storei.asm — STORE imm, addr (välitön arvo suoraan muistiosoitteeseen)
; Assembler valitsee automaattisesti STOREI-opkoodin kun ensimmäinen
; operandi ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        ; Kirjoita desimaaliluku suoraan muistiosoitteeseen
        STORE     77, 0x0300       ; muisti[0x0300] = 77

        ; Kirjoita heksaluku muistiosoitteeseen
        STORE     0xABCD, 0x0301   ; muisti[0x0301] = 0xABCD

        ; Kirjoita nolla muistiosoitteeseen (erityistapaus)
        STORE     0, 0x0302        ; muisti[0x0302] = 0

        ; Kirjoita 0xFFFF muistiosoitteeseen (maksimarvo)
        STORE     0xFFFF, 0x0303   ; muisti[0x0303] = 0xFFFF

        ; Lue takaisin ja tarkista
        READ      R0, 0x0300       ; R0 = 77
        READ      R1, 0x0301       ; R1 = 0xABCD
        READ      R2, 0x0302       ; R2 = 0
        READ      R3, 0x0303       ; R3 = 0xFFFF

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
