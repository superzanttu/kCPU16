; test_include_twice.asm — Sama tiedosto voidaan sisallyttaa useaan kertaan
; (eri kohtiin), kunhan ei luoda sykleja.
; Tassa liitetaan include_lib.asm kahdesti, mutta kummassakin paikassa
; maaritetaan eri label ympararoivilla labeleilla.
; HUOM: Koska labelin ADD_TEN ja vakion LIB_CONST duplikaatti
;       aiheuttaisi virheen, kaytetaan tassa kahta eri kirjastotiedostoa.

        .origin 0x0200

START:
        LOAD  R0, 10
        CALL  ADD_FIVE      ; R0 = 15
        CALL  ADD_THREE     ; R0 = 18
        HALT

        .include "includes/include_lib_a.asm"   ; maarittaa ADD_FIVE / LIB_A
        .include "includes/include_lib_b.asm"   ; maarittaa ADD_THREE / LIB_B

.expect_reg  R0, 18
