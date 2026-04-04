; =============================================================================
; test_dread_dwrite.asm — DREAD regD, regS / DWRITE regS, regD
; Tallennuslaitteen luku ja kirjoitus.
; DWRITE R0, R1  → storage[R1] = R0
; DREAD  R2, R1  → R2 = storage[R1]
; Kernel-käskyjä (vaativat P=1).
; =============================================================================

        .origin 0x0200

        LOAD  R0, 0x1234      ; kirjoitettava arvo
        LOAD  R1, 10          ; tallennusosoite (sana 10)

        DWRITE R0, R1         ; storage[10] = 0x1234
        LOAD   R2, 0          ; nollaa R2 ennen lukua
        DREAD  R2, R1         ; R2 = storage[10]

        ; Kirjoita toinen arvo eri osoitteeseen
        LOAD  R0, 0xABCD
        LOAD  R1, 50
        DWRITE R0, R1         ; storage[50] = 0xABCD
        LOAD   R3, 0
        DREAD  R3, R1         ; R3 = storage[50]

        HALT

.expect_reg     R2, 0x1234
.expect_reg     R3, 0xABCD
.expect_storage 10,  0x1234
.expect_storage 50,  0xABCD
