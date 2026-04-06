; =============================================================================
; test_sti_cli.asm — STI / CLI
; STI asettaa I-lipun (sallii laitteistokeskeytykset).
; CLI nollaa I-lipun (estää laitteistokeskeytykset).
; Molemmat ovat kernel-käskyjä (vaativat P=1).
; =============================================================================

        .origin 0x0200

        ; Oletuksena I=0 käynnistyksessä
        STI                   ; I=1
        LOAD  R0, 1           ; tarkistusarvo

        CLI                   ; I=0
        LOAD  R1, 2

        STI                   ; I=1 uudelleen
        HALT

.expect_reg   R0, 1
.expect_reg   R1, 2
.expect_flag  I, 1            ; viimeisin operaatio oli STI
; STI/CLI muuttaa vain I-lippua — Z, N, C, V pysyvät nollassa
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
