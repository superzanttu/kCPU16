; =============================================================================
; test_storei_rel.asm — STORE [FP+offset], imm (välitön arvo FP-suhteelliseen osoitteeseen)
; Kirjoittaa vakioarvon FP-rekisterin suhteelliseen muistiosoitteeseen.
; Assembler tuottaa STOREI_REL-opkoodin kun STORE [FP+n]:n lähde ei ole rekisteri.
; =============================================================================

        .origin 0x0200

        JARI      FP, 0x0300      ; FP = pinokehyksen kanta

        ; Kirjoita välitön arvo eri siirtymiin
        STORE [FP+0], 99  ; muisti[FP+0] = muisti[0x0300] = 99
        STORE [FP+1], 0xCAFE  ; muisti[FP+1] = muisti[0x0301] = 0xCAFE
        STORE [FP+2], 0  ; muisti[FP+2] = muisti[0x0302] = 0
        STORE [FP+5], 0xFFFF  ; muisti[FP+5] = muisti[0x0305] = 0xFFFF

        ; Lue takaisin READ_REL:llä ja tarkista
        JARI R0, [FP+0]  ; R0 = muisti[0x0300] = 99
        JARI R1, [FP+1]  ; R1 = muisti[0x0301] = 0xCAFE
        JARI R2, [FP+2]  ; R2 = muisti[0x0302] = 0
        JARI R3, [FP+5]  ; R3 = muisti[0x0305] = 0xFFFF

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
