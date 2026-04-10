; =============================================================================
; test_clock_year.asm — Vuosiluku > 2000
;
; Varmistaa että CLOCK_YEAR palauttaa järkevän vuosiluvun (> 2000).
; =============================================================================

        .origin 0x0200

        READ  R0, [CLOCK_YEAR]   ; Lue vuosi MMIO:sta
        READ  R1, 2000
        CMP   R0, R1
        JGT   ok                 ; vuosi > 2000 -> OK
        READ  R0, 0              ; fail
        JUMP  done
ok:
        READ  R0, 1              ; pass
done:
        HALT

.expect_reg   R0, 1
