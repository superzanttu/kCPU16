; =============================================================================
; test_fill_max_value.asm — FILL maksimiarvolla 0xFFFF
; Varmistaa että 16-bittinen maksimiarvo tallennetaan oikein.
; =============================================================================

        .origin 0x0200

        READ  R0, 0x0800        ; alkuosoite
        READ  R1, 0x0804        ; loppuosoite (5 sanaa: 0x0800-0x0804)
        READ  R2, 0xFFFF        ; 16-bittinen maksimiarvo

        FILL  R0, R1, R2

        HALT

.expect_mem  0x0800, 0xFFFF
.expect_mem  0x0802, 0xFFFF
.expect_mem  0x0804, 0xFFFF
.expect_mem  0x07FF, 0              ; edellinen
.expect_mem  0x0805, 0              ; seuraava
