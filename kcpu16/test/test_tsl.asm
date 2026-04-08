; =============================================================================
; test_tsl.asm — TSL reg, addr
; Test and Set Lock: atominen lukkoprimitiivi.
; Lukee muistipaikan vanhan arvon rekisteriin ja asettaa paikan arvoksi 1.
; Käytetään lukon tilan tarkistamiseen ja varamiseen yhdellä operaatiolla.
; =============================================================================

        .origin 0x0200

        ; Alusta lukko vapaaaksi (0 = vapaa)
        JARI  R0, 0
        STORE [0x0300], R0

        ; Ensimmäinen TSL: lukko oli vapaa → R1 = 0, lukko lukittuu
        TSL   R1, 0x0300      ; R1 = 0 (vapaa), muisti[0x0300] = 1

        ; Toinen TSL: lukko on jo lukittu → R2 = 1, pysyy lukittuna
        TSL   R2, 0x0300      ; R2 = 1 (lukittu), muisti[0x0300] = 1

        HALT

.expect_reg   R1, 0           ; ensimmäinen TSL löysi vapaan lukon
.expect_reg   R2, 1           ; toinen TSL löysi lukitun lukon
.expect_mem   0x0300, 1       ; lukko on lukittu
.expect_flag  Z, 0            ; viimeisin TSL: vanha arvo=1 → Z=0
.expect_flag  N, 0            ; arvo 1 ei aseta N-lippua (bitti 15 = 0)
.expect_flag  C, 0            ; TSL ei aseta C-lippua
.expect_flag  V, 0            ; TSL ei aseta V-lippua
