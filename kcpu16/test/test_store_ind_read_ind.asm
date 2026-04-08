; =============================================================
; TESTI: STORE_IND ja READ_IND eri rekistereillä
; =============================================================
; Testaa epäsuoraa osoitusta kaikilla rekisteripareilla.
; =============================================================

.origin 0x0200

; R0 = arvo, R1 = osoite
JARI  R0, 0x1111
JARI  R1, 0x0300
STORE [R1], R0  ; mem[0x0300] = 0x1111

; R2 = arvo, R3 = osoite
JARI  R2, 0x2222
JARI  R3, 0x0301
STORE [R3], R2  ; mem[0x0301] = 0x2222

; FP = arvo, SP ei kannata käyttää osoitteena tässä
; -> Lue takaisin eri rekistereihin
JARI  R0, 0           ; nollaa
JARI  R2, 0

JARI R0, [R1]  ; R0 = mem[0x0300] = 0x1111
JARI R2, [R3]  ; R2 = mem[0x0301] = 0x2222

; Testaa myös FP:tä osoitteena
JARI  FP, 0x0302
JARI  R1, 0x3333
STORE [FP], R1  ; mem[0x0302] = 0x3333
JARI R3, [FP]  ; R3 = mem[0x0302] = 0x3333

HALT

.expect_reg   R0, 0x1111
.expect_reg   R2, 0x2222
.expect_reg   R3, 0x3333
.expect_mem   0x0300, 0x1111
.expect_mem   0x0301, 0x2222
.expect_mem   0x0302, 0x3333
