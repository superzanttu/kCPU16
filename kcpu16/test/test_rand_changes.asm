; =============================================================================
; test_rand_changes.asm — RAND MMIO: kaksi peräkkäistä lukua eroavat toisistaan
;
; LFSR ei koskaan pysähdy samaan arvoon kahdesti peräkkäin (paitsi jos
; siemenenä olisi erikoisarvo, mutta oletussiemenellä näin ei ole).
; Luetaan kaksi arvoa ja varmistetaan R0 != R1.
; R2 = lopputulos: 1 = ok, 0 = virhe.
; =============================================================================

        .origin 0x0200

        LOAD  R2, 1              ; oleta OK

        LOAD  R0, [RAND_MMIO]   ; ensimmäinen satunnaisluku
        LOAD  R1, [RAND_MMIO]   ; toinen satunnaisluku

        CMP   R0, R1
        JZ    fail               ; arvot samat — virhe

        HALT

fail:
        LOAD  R2, 0
        HALT

.expect_reg   R2, 1
