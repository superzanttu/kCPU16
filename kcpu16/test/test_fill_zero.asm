; =============================================================================
; test_fill_zero.asm — FILL muistialueen nollaus
; Varmistaa että FILL toimii arvolla 0 (yleisin käyttötapaus: nollaus).
; =============================================================================

        .origin 0x0200

        ; Kirjoita ensin ei-nolla-arvo, jotta nollaus todella testataan
        LOAD  R0, 0x0500
        LOAD  R1, 0x0503
        LOAD  R2, 0x1234
        FILL  R0, R1, R2        ; kirjoita 0x1234 alueelle

        ; Nollaa sama alue
        LOAD  R2, 0
        FILL  R0, R1, R2        ; nollaa alue 0x0500-0x0503

        HALT

.expect_mem  0x0500, 0
.expect_mem  0x0501, 0
.expect_mem  0x0502, 0
.expect_mem  0x0503, 0
