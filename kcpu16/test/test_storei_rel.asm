; =============================================================================
; test_storei_rel.asm — STORE_REL imm, offset (välitön arvo [FP + offset]:een)
; Assembler valitsee automaattisesti STOREI_REL-opkoodin kun ensimmäinen
; operandi ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        LOAD      FP, 0x0300      ; FP = pinokehyksen kanta

        ; Kirjoita välitön arvo eri siirtymiin
        STORE_REL 99, 0            ; muisti[FP+0] = muisti[0x0300] = 99
        STORE_REL 0xCAFE, 1        ; muisti[FP+1] = muisti[0x0301] = 0xCAFE
        STORE_REL 0, 2             ; muisti[FP+2] = muisti[0x0302] = 0
        STORE_REL 0xFFFF, 5        ; muisti[FP+5] = muisti[0x0305] = 0xFFFF

        ; Lue takaisin READ_REL:llä ja tarkista
        READ_REL  R0, 0            ; R0 = muisti[0x0300] = 99
        READ_REL  R1, 1            ; R1 = muisti[0x0301] = 0xCAFE
        READ_REL  R2, 2            ; R2 = muisti[0x0302] = 0
        READ_REL  R3, 5            ; R3 = muisti[0x0305] = 0xFFFF

        HALT

.expect_reg   FP, 0x0300
.expect_reg   R0, 99
.expect_reg   R1, 0xCAFE
.expect_reg   R2, 0
.expect_reg   R3, 0xFFFF
.expect_mem   0x0300, 99
.expect_mem   0x0301, 0xCAFE
.expect_mem   0x0302, 0
.expect_mem   0x0305, 0xFFFF
; STOREI_REL ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
