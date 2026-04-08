; =============================================================
; TESTI: JARI FP ja SP rekistereihin
; =============================================================
; Testaa JARI-käskyn käyttöä FP- ja SP-rekistereille.
; =============================================================

.origin 0x0200

; JARI FP:hen
JARI  FP, 0x0500
CPY   R0, FP          ; R0 = 0x0500

; JARI SP:hen (vaihda pinon sijainti)
JARI  SP, 0x0900
CPY   R1, SP          ; R1 = 0x0900

; Testi: PUSH/POP uudessa pinosijainnissa
JARI  R2, 42
PUSH  R2              ; [0x0900] = 42, SP = 0x08FF
POP   R3              ; R3 = 42, SP = 0x0900

HALT

.expect_reg   R0, 0x0500     ; FP ladattu oikein
.expect_reg   R1, 0x0900     ; SP ladattu oikein
.expect_reg   R3, 42         ; PUSH/POP uudessa pinossa toimi
.expect_reg   SP, 0x0900     ; SP palautunut
.expect_reg   FP, 0x0500     ; FP ennallaan
