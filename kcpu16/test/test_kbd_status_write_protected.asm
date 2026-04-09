; =============================================================
; TESTI: Kirjoitus KBD_STATUS-osoitteeseen laukaisee INT 10
; =============================================================
; KBD_STATUS ($0021) on kirjoitussuojattu, kuten KBD_DATA.
; STORE [KBD_STATUS], 0  -käsky pitäisi laukaista INT_WRITE_PROTECTED (10).
; =============================================================

.origin 0x0200

        ; Aseta INT_WRITE_PROTECTED -käsittelijä (vektori 10)
        LOAD  R0, write_prot_handler
        STORE [INT_WRITE_PROTECTED], R0

        ; Yritä kirjoittaa KBD_STATUS -osoitteeseen (pitäisi laukaista INT 10)
        STORE [KBD_STATUS], 0

        ; Tähän ei pitäisi päästä
        LOAD  R1, 0xFF
        HALT

write_prot_handler:
        ; INT 10 laukesi — merkitään onnistuminen
        LOAD  R1, 1
        HALT

.expect_reg R1, 1   ; INT_WRITE_PROTECTED laukesi oikein
