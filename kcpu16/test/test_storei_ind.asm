; =============================================================================
; test_storei_ind.asm — STORE [reg], imm (välitön arvo rekisterin osoittamaan paikkaan)
; Kirjoittaa vakioarvon epäsuorasti rekisterin osoittamaan muistiosoitteeseen.
; Assembler tuottaa STOREI_IND-opkoodin kun STORE [reg]:n lähde ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        ; R0 osoittaa kohteeseen, kirjoitetaan välitön arvo
        JARI      R0, 0x0300
        STORE [R0], 42  ; muisti[0x0300] = 42

        ; R1 osoittaa eri kohteeseen, kirjoitetaan 0xBEEF
        JARI      R1, 0x0301
        STORE [R1], 0xBEEF  ; muisti[0x0301] = 0xBEEF

        ; FP osoitteena, kirjoitetaan nolla
        JARI      FP, 0x0302
        STORE [FP], 0  ; muisti[0x0302] = 0

        ; R2 osoitteena, kirjoitetaan 0xFFFF
        JARI      R2, 0x0303
        STORE [R2], 0xFFFF  ; muisti[0x0303] = 0xFFFF

        ; Lue takaisin ja tarkista
        JARI R0, [0x0300]  ; R0 = 42
        JARI R1, [0x0301]  ; R1 = 0xBEEF
        JARI R2, [0x0302]  ; R2 = 0
        JARI R3, [0x0303]  ; R3 = 0xFFFF

        HALT

.expect_reg   R0, 42
.expect_reg   R1, 0xBEEF
.expect_reg   R2, 0
.expect_reg   R3, 0xFFFF
.expect_mem   0x0300, 42
.expect_mem   0x0301, 0xBEEF
.expect_mem   0x0302, 0
.expect_mem   0x0303, 0xFFFF
; STOREI_IND ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
