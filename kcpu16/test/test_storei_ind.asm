; =============================================================================
; test_storei_ind.asm — STORE_IND regD, imm (välitön arvo rekisterin osoittamaan paikkaan)
; Assembler valitsee automaattisesti STOREI_IND-opkoodin kun toinen
; operandi ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        ; R0 osoittaa kohteeseen, kirjoitetaan välitön arvo
        LOAD      R0, 0x0300
        STORE_IND R0, 42          ; muisti[0x0300] = 42

        ; R1 osoittaa eri kohteeseen, kirjoitetaan 0xBEEF
        LOAD      R1, 0x0301
        STORE_IND R1, 0xBEEF      ; muisti[0x0301] = 0xBEEF

        ; FP osoitteena, kirjoitetaan nolla
        LOAD      FP, 0x0302
        STORE_IND FP, 0           ; muisti[0x0302] = 0

        ; R2 osoitteena, kirjoitetaan 0xFFFF
        LOAD      R2, 0x0303
        STORE_IND R2, 0xFFFF      ; muisti[0x0303] = 0xFFFF

        ; Lue takaisin ja tarkista
        READ      R0, 0x0300      ; R0 = 42
        READ      R1, 0x0301      ; R1 = 0xBEEF
        READ      R2, 0x0302      ; R2 = 0
        READ      R3, 0x0303      ; R3 = 0xFFFF

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
