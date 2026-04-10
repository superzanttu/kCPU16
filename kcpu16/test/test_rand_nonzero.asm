; =============================================================================
; test_rand_nonzero.asm — RAND MMIO: lukeminen palauttaa nollasta poikkeavan arvon
;
; Oletussiemenellä (RAND_LFSR_SEED) ensimmäinen LFSR-askellus ei koskaan
; tuota nollaa (16-bittinen max-length LFSR, jakso 65535). Tarkistetaan
; yksinkertaisesti että R0 != 0 käyttämällä CMP ja JEQ fail -rakennetta.
; R1 = lopputulos: 1 = ok, 0 = virhe.
; =============================================================================

        .origin 0x0200

        LOAD  R1, 1              ; oleta OK

        LOAD  R0, [RAND_MMIO]   ; lue pseudosatunnaisluku

        LOAD  R2, 0
        CMP   R0, R2
        JZ    fail               ; arvo oli 0 — virhe

        HALT

fail:
        LOAD  R1, 0
        HALT

.expect_reg   R1, 1
