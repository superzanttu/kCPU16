; =============================================================================
; test_rand_seed.asm — RAND MMIO: siemennys tekee generaattorista deterministisen
;
; Asetetaan tunnettu siemen ($DEAD) kirjoittamalla RAND_MMIO:lle,
; luetaan ensimmäinen arvo (R0), asetetaan sama siemen uudelleen,
; luetaan toinen arvo (R1). Koska siemen on sama, R0 == R1.
;
; CPU:n Python-funktio laskee: lsb = 0xDEAD & 1 = 1
;   _lfsr = (0xDEAD >> 1) ^ 0xB400 = 0x6F56 ^ 0xB400 = 0xDB56
;
; R2 = lopputulos: 1 = ok, 0 = virhe.
; =============================================================================

        .origin 0x0200

        LOAD  R2, 1              ; oleta OK

        ; Ensimmäinen kierros: siemen $DEAD
        LOAD  R3, 0xDEAD
        STORE [RAND_MMIO], R3   ; aseta siemen
        LOAD  R0, [RAND_MMIO]   ; lue arvo (= 0xDB56)

        ; Toinen kierros: sama siemen uudelleen
        STORE [RAND_MMIO], R3   ; aseta siemen uudelleen
        LOAD  R1, [RAND_MMIO]   ; pitää olla sama arvo

        CMP   R0, R1
        JNZ   fail               ; arvot erilaisia — deterministisyys rikki

        HALT

fail:
        LOAD  R2, 0
        HALT

.expect_reg   R0, 0xDB56
.expect_reg   R1, 0xDB56
.expect_reg   R2, 1
