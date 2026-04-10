; =============================================================
; TESTI: INT ja IRET - ohjelmallinen keskeytys ja paluu
; =============================================================
; Testaa INT-käskyn kutsuminen ja IRET-paluu.
;
; INT-sekvenssi:
;   1. PUSH PC (paluuosoite)
;   2. PUSH SR
;   3. P=1, I=0
;   4. PC = [vektori]
;
; IRET-sekvenssi:
;   1. POP SR
;   2. POP PC
; =============================================================

.origin 0x0200

; Aseta keskeytysvektori 3 (breakpoint) osoittamaan handler:iin
READ  R0, handler
STORE [0x0003], R0  ; vektori 3 = handler:in osoite

; Aseta testiarvo
READ  R0, 0
READ  R1, 0

; Kutsu INT 3 (breakpoint)
INT   3

; Paluu INT:stä tulee tähän
READ  R1, 77          ; tämä suoritetaan IRET:in jälkeen
HALT

handler:
    READ  R0, 42      ; handler asettaa R0=42
    IRET              ; palaa INT:n jälkeiseen käskyyn

.expect_reg   R0, 42         ; handler suoritettiin
.expect_reg   R1, 77         ; paluu IRET:llä onnistui
.expect_flag  P, 1           ; kernel mode (testrunner aloittaa kernel-tilassa)
