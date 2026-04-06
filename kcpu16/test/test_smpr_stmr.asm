; =============================================================
; TESTI: SMPR ja STMR -käskyt
; =============================================================
; Testaa:
; 1. SMPR reg -> MPR = reg (muistisuojausraja)
; 2. STMR reg -> TMR = reg (ajastinkeskeytyksen väli)
; =============================================================

.origin 0x0200

; --- SMPR testi ---
; Aseta MPR = 0x0400
LOAD  R0, 0x0400
SMPR  R0

; Aseta MPR = 0x0200 (muuta)
LOAD  R0, 0x0200
SMPR  R0

; --- STMR testi ---
; Aseta TMR = 100 (ajastinkeskeytys joka 100 käskyn välein)
LOAD  R1, 100
STMR  R1

; Aseta TMR = 0 (pois päältä, jotta ei laukea tässä testissä)
LOAD  R1, 0
STMR  R1

; Tarkista: MPR ja TMR eivät ole suoraan .expect_reg:llä
; luettavissa, mutta SMPR/STMR eivät aseta lippuja
LOAD  R0, 42
LOAD  R1, 43
HALT

.expect_reg   R0, 42         ; SMPR ei muuttanut R0:aa
.expect_reg   R1, 43         ; STMR ei muuttanut R1:tä
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
