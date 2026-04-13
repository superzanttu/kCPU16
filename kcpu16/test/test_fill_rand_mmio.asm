; =============================================================================
; test_fill_rand_mmio.asm — FILL MMIO-alueelle käyttää MMIO-aware fallbackia
;
; Täytetään yhden sanan alue RAND_MMIO:ssa komennolla FILL.
; Oikea käyttäytyminen: kirjoitus siementää LFSR:n (ei kirjoita suoraan RAM:iin).
;
; Siemen 0xBEEF -> ensimmäinen RAND-luku:
;   lsb = 1
;   (0xBEEF >> 1) ^ 0xB400 = 0x5F77 ^ 0xB400 = 0xEB77
; =============================================================================

        .origin 0x0200

        READ  R0, RAND_MMIO      ; start
        READ  R1, RAND_MMIO      ; end
        READ  R2, 0xBEEF         ; seed value

        FILL  R0, R1, R2         ; kirjoita RAND_MMIO:lle fallback-polulla
        READ  R3, [RAND_MMIO]    ; ensimmäinen generoitu arvo

        HALT

.expect_reg R3, 0xEB77
