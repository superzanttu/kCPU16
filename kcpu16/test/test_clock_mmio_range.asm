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

        LOAD  R0, 1           ; oleta OK

        ; --- Kuukausi: 1..12 ---
        LOAD  R1, [CLOCK_MONTH]
        LOAD  R2, 1
        CMP   R1, R2
        JLT   fail            ; kuukausi < 1 -> virhe
        LOAD  R2, 12
        CMP   R1, R2
        JGT   fail            ; kuukausi > 12 -> virhe

        ; --- Päivä: 1..31 ---
        LOAD  R1, [CLOCK_DAY]
        LOAD  R2, 1
        CMP   R1, R2
        JLT   fail
        LOAD  R2, 31
        CMP   R1, R2
        JGT   fail

        ; --- Tunti: 0..23 ---
        LOAD  R1, [CLOCK_HOUR]
        LOAD  R2, 23
        CMP   R1, R2
        JGT   fail

        ; --- Minuutti: 0..59 ---
        LOAD  R1, [CLOCK_MINUTE]
        LOAD  R2, 59
        CMP   R1, R2
        JGT   fail

        ; --- Sekunti: 0..59 ---
        LOAD  R1, [CLOCK_SECOND]
        LOAD  R2, 59
        CMP   R1, R2
        JGT   fail

        ; --- Millisekunti: 0..999 ---
        LOAD  R1, [CLOCK_MILLIS]
        LOAD  R2, 999
        CMP   R1, R2
        JGT   fail

        JUMP  done

fail:
        LOAD  R0, 0

done:
        HALT

.expect_reg   R0, 1
