; =============================================================
; TESTI: Kirjoitus KBD_DATA-osoitteeseen laukaisee INT 10
; =============================================================
; Näppäimistö-MMIO ($0020-$0021) on kirjoitussuojattu.
; STORE [KBD_DATA], 0  -käsky pitäisi laukaista INT_WRITE_PROTECTED (10).
;
; INT_WRITE_PROTECTED = 10 -> vektori muistipaikassa 10.
; Käsittelijä lataa R1 = 1 ja pysäyttää koneen (HALT).
; =============================================================

.origin 0x0200

        ; Aseta INT_WRITE_PROTECTED -käsittelijä (vektori 10)
        LOAD  R0, write_prot_handler
        STORE [INT_WRITE_PROTECTED], R0

        ; Yritä kirjoittaa KBD_DATA -osoitteeseen (pitäisi laukaista INT 10)
        STORE [KBD_DATA], 0

        ; Tähän ei pitäisi päästä
        LOAD  R1, 0xFF
        HALT

write_prot_handler:
        ; INT 10 laukesi — merkitään onnistuminen
        LOAD  R1, 1
        HALT

.expect_reg R1, 1   ; INT_WRITE_PROTECTED laukesi oikein
