; =============================================================
; TESTI: KBD_DATA raakaarvo vapautustapahtumassa
; =============================================================
; Varmistaa että KBD_RELEASE_BIT (bit 7 = 0x80) on asetettu
; vapautustapahtumassa ENNEN maskaamista, ja että maskin jälkeen
; bitti on nolla ja koodi vastaa alkuperäistä näppäinkoodia.
;
; Syötetään: 'Z' (0x5A) vapautus.
; Odotettu raakakoodi KBD_DATA:sta: 0xDA (0x5A | 0x80).
; Odotettu release-bitti (AND 0x80): 0x80.
; Odotettu maskattu koodi (AND 0x7F): 0x5A.
; =============================================================

.origin 0x0200

; Aseta INT 6 -handler
READ  R0, kbd_handler
STORE [INT_KEYBOARD], R0

; Alusta
READ  R1, 0      ; raakakoodi KBD_DATA:sta
READ  R2, 0      ; AND KBD_RELEASE_BIT -tulos
READ  R3, 0      ; AND KBD_KEY_CODE_MASK -tulos

; Salli keskeytykset
STI

READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0

HALT

kbd_handler:
    READ  R1, [KBD_DATA]         ; R1 = raakakoodi (esim. 0x00DA)

    ; Tarkista release-bitti
    READ  R2, KBD_RELEASE_BIT    ; R2 = 0x0080
    AND   R2, R1                 ; R2 = R1 & 0x80

    ; Maskaa näppäinkoodi
    READ  R3, KBD_KEY_CODE_MASK  ; R3 = 0x007F
    AND   R3, R1                 ; R3 = R1 & 0x7F

    IRET

; Syötä vain 'Z' vapautus (ei edeltävää painallusta)
.inject_key_release 0x5A   ; 'Z' vapautus -> KBD_DATA = 0x5A | 0x80 = 0xDA

.expect_reg  R1, 0x00DA    ; raakakoodi: 0x5A | 0x80
.expect_reg  R2, 0x0080    ; release-bitti on asetettu
.expect_reg  R3, 0x005A    ; näppäinkoodi ilman release-bittiä
