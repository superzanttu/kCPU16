; =============================================================
; TESTI: STORE_IND ja READ_IND eri rekistereillä
; =============================================================
; Testaa epäsuoraa osoitusta kaikilla rekisteripareilla.
; =============================================================

.origin 0x0200

; R0 = arvo, R1 = osoite
LOAD  R0, 0x1111
LOAD  R1, 0x0300
STORE_IND R1, R0      ; mem[0x0300] = 0x1111

; R2 = arvo, R3 = osoite
LOAD  R2, 0x2222
LOAD  R3, 0x0301
STORE_IND R3, R2      ; mem[0x0301] = 0x2222

; FP = arvo, SP ei kannata käyttää osoitteena tässä
; -> Lue takaisin eri rekistereihin
LOAD  R0, 0           ; nollaa
LOAD  R2, 0

READ_IND  R0, R1      ; R0 = mem[0x0300] = 0x1111
READ_IND  R2, R3      ; R2 = mem[0x0301] = 0x2222

; Testaa myös FP:tä osoitteena
LOAD  FP, 0x0302
LOAD  R1, 0x3333
STORE_IND FP, R1      ; mem[0x0302] = 0x3333
READ_IND  R3, FP      ; R3 = mem[0x0302] = 0x3333

HALT

.expect_reg   R0, 0x1111
.expect_reg   R2, 0x2222
.expect_reg   R3, 0x3333
.expect_mem   0x0300, 0x1111
.expect_mem   0x0301, 0x2222
.expect_mem   0x0302, 0x3333
