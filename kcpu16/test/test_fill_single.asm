; =============================================================================
; test_fill_single.asm — FILL yhden sanan alue (regStart == regEnd)
; Varmistaa että FILL toimii kun alue on täsmälleen yksi sana.
; =============================================================================

        .origin 0x0200

        READ  R0, 0x0600        ; alku = loppu = 0x0600
        READ  R1, 0x0600
        READ  R2, 0xCAFE

        FILL  R0, R1, R2        ; täytä vain yksi sana

        HALT

; Vain kohdesana saa muuttua
.expect_mem  0x0600, 0xCAFE
.expect_mem  0x05FF, 0              ; edellinen sana ei muuttunut
.expect_mem  0x0601, 0              ; seuraava sana ei muuttunut
