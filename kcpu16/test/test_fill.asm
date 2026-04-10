; =============================================================================
; test_fill.asm — FILL regStart, regEnd, regVal
; Täyttää muistialueen [regStart..regEnd] arvolla regVal.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0x0400        ; alkuosoite
        LOAD  R1, 0x0407        ; loppuosoite (8 sanaa: 0x0400-0x0407)
        LOAD  R2, 0xBEEF        ; täytettävä arvo

        FILL  R0, R1, R2        ; täytä muistialue

        HALT

.expect_mem  0x0400, 0xBEEF
.expect_mem  0x0401, 0xBEEF
.expect_mem  0x0404, 0xBEEF
.expect_mem  0x0407, 0xBEEF
