; =============================================================
; TESTI: PUSH/POP SP-arvon seuranta
; =============================================================
; Testaa SP:n oikea muutos PUSH/POP-operaatioissa.
; SP alkaa 0xFFFF (testrunner reset_for_test).
; PUSH: [SP]=val, SP=SP-1  ->  SP pienenee
; POP:  SP=SP+1, val=[SP]  ->  SP kasvaa
; =============================================================

.origin 0x0200

; Alkutilanne: SP = 0xFFFF
CPY   R0, SP          ; R0 = alkuperäinen SP = 0xFFFF

; PUSH R1 (100): SP pitäisi olla 0xFFFE
JARI  R1, 100
PUSH  R1
CPY   R2, SP          ; R2 = 0xFFFE

; Toinen PUSH (200): SP pitäisi olla 0xFFFD
JARI  R1, 200
PUSH  R1
CPY   R3, SP          ; R3 = 0xFFFD

; POP: SP pitäisi palautua 0xFFFE
POP   R1              ; R1 = 200, SP = 0xFFFE

; Toinen POP: SP pitäisi palautua 0xFFFF
POP   R1              ; R1 = 100, SP = 0xFFFF

; Tarkista loppu-SP
CPY   FP, SP          ; FP = SP = 0xFFFF (palautunut)

HALT

.expect_reg   R0, 0xFFFF     ; alkuperäinen SP
.expect_reg   R2, 0xFFFE     ; 1 PUSH:n jälkeen
.expect_reg   R3, 0xFFFD     ; 2 PUSH:n jälkeen
.expect_reg   R1, 100        ; viimeinen POP
.expect_reg   FP, 0xFFFF     ; SP palautunut
