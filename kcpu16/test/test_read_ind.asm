; =============================================================================
; test_read_ind.asm — LOAD regD, [regS] / STORE [regD], regS
; Epäsuora muistiosoitus: osoite on rekisterissä, ei vakiona.
; STORE [R1], R0  → muisti[R1] = R0
; LOAD  R2, [R1]  → R2 = muisti[R1]
; =============================================================================

        .origin 0x0200

        LOAD      R0, 0x55AA      ; kirjoitettava arvo
        LOAD      R1, 0x0300      ; kohde-osoite

        STORE [R1], R0  ; muisti[0x0300] = 0x55AA
        LOAD R2, [R1]  ; R2 = muisti[0x0300] = 0x55AA

        ; Toinen kierros eri arvolla — varmentaa STORE_IND ylikirjoituksen
        LOAD      R0, 0x1234
        STORE [R1], R0  ; muisti[0x0300] = 0x1234
        LOAD R3, [R1]  ; R3 = 0x1234

        HALT

.expect_reg   R2, 0x55AA
.expect_reg   R3, 0x1234
.expect_mem   0x0300, 0x1234
; LOAD [R]/STORE [R] ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
