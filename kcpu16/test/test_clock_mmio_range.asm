; =============================================================================
; test_clock_mmio_range.asm — Järjestelmäkello: arvoaluetarkistukset
;
; Lukee kellorekisterit MMIO-osoitteista ja varmistaa että arvot
; ovat odotetuilla alueilla käyttämällä vertailuja ja ehdollisia hyppyjä.
; R0 = lopputulos: 1 = kaikki ok, 0 = virhe.
;
; Tarkistukset:
;   kuukausi:  1..12
;   päivä:     1..31
;   tunti:     0..23
;   minuutti:  0..59
;   sekunti:   0..59
;   millis:    0..999
; =============================================================================

        .origin 0x0200

        READ  R0, 1           ; oleta OK

        ; --- Kuukausi: 1..12 ---
        READ  R1, [CLOCK_MONTH]
        READ  R2, 1
        CMP   R1, R2
        JLT   fail            ; kuukausi < 1 -> virhe
        READ  R2, 12
        CMP   R1, R2
        JGT   fail            ; kuukausi > 12 -> virhe

        ; --- Päivä: 1..31 ---
        READ  R1, [CLOCK_DAY]
        READ  R2, 1
        CMP   R1, R2
        JLT   fail
        READ  R2, 31
        CMP   R1, R2
        JGT   fail

        ; --- Tunti: 0..23 ---
        READ  R1, [CLOCK_HOUR]
        READ  R2, 23
        CMP   R1, R2
        JGT   fail

        ; --- Minuutti: 0..59 ---
        READ  R1, [CLOCK_MINUTE]
        READ  R2, 59
        CMP   R1, R2
        JGT   fail

        ; --- Sekunti: 0..59 ---
        READ  R1, [CLOCK_SECOND]
        READ  R2, 59
        CMP   R1, R2
        JGT   fail

        ; --- Millisekunti: 0..999 ---
        READ  R1, [CLOCK_MILLIS]
        READ  R2, 999
        CMP   R1, R2
        JGT   fail

        JUMP  done

fail:
        READ  R0, 0

done:
        HALT

.expect_reg   R0, 1
