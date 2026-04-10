; =============================================================================
; test_fill_large.asm — FILL suurella alueella (64 sanaa)
; Varmistaa alun, keskikohdan ja lopun arvot.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0x0700        ; alkuosoite
        LOAD  R1, 0x073F        ; loppuosoite (64 sanaa: 0x0700-0x073F)
        LOAD  R2, 0xABCD        ; täytettävä arvo

        FILL  R0, R1, R2

        HALT

.expect_mem  0x0700, 0xABCD       ; ensimmäinen sana
.expect_mem  0x0701, 0xABCD       ; toinen sana
.expect_mem  0x071F, 0xABCD       ; keskikohta
.expect_mem  0x073E, 0xABCD       ; toiseksi viimeinen
.expect_mem  0x073F, 0xABCD       ; viimeinen sana
.expect_mem  0x0740, 0            ; ensimmäinen täyttämätön sana
