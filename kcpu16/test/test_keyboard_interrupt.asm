; =============================================================
; TESTI: Näppäimistökeskeytys (INT 6)
; =============================================================
; Testaa näppäimistön keskeytysmekanismi:
; - .inject_key simuloi näppäinpainallusta ennen suoritusta
; - INT 6 laukeaa automaattisesti kun I=1 ja puskurissa on data
; - Keskeytysrutiini lukee tapahtuman KBD_DATA ($0020) MMIO:sta
; - KBD_RELEASE_BIT (bit 7) erottaa painalluksen vapautuksesta
;
; .inject_key KEY_CODE         = simuloi painallus ennen suoritusta
; .inject_key_release KEY_CODE  = simuloi vapautus ennen suoritusta
; =============================================================

.origin 0x0200

; Aseta INT 6 -handler (näppäimistö)
LOAD  R0, kbd_handler
STORE [INT_KEYBOARD], R0

; Alusta: R1 = 0 (painalluksen koodi), R2 = 0 (vapautuksen koodi)
LOAD  R1, 0
LOAD  R2, 0

; Salli keskeytykset (I=1)
STI

; Suorita muutama käsky niin keskeytys ehtii laueta
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0
LOAD  R0, 0

HALT

; --- Näppäimistön keskeytysrutiini ---
kbd_handler:
    ; Lue näppäintapahtuma KBD_DATA MMIO:sta ($0020)
    LOAD  R0, [KBD_DATA]
    ; Tarkista onko vapautusbitti (bit 7) asetettu
    LOAD  R3, KBD_RELEASE_BIT
    AND   R3, R0
    JZ    key_press
    ; Vapautus: tallenna koodi R2:een (ilman release-bittiä)
    LOAD  R3, 0x7F
    AND   R0, R3
    CPY   R2, R0
    IRET
key_press:
    ; Painallus: tallenna koodi R1:een
    CPY   R1, R0
    IRET

; Syötetään 'A' (0x41 = 65) painallus ja vapautus ennen suoritusta
.inject_key        0x41
.inject_key_release 0x41

.expect_reg   R1, 0x41       ; painallus: 'A' = 0x41
.expect_reg   R2, 0x41       ; vapautus: koodi ilman release-bittiä = 0x41
