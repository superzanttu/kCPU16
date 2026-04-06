; =============================================================
; TESTI: AND/OR/XOR/NOT nollaavat C ja V
; =============================================================
; Asetetaan C=1, V=1 ensin, sitten logiikkaoperaatio -> C=0, V=0
; =============================================================

.origin 0x0200

; --- AND nollaa C ja V ---
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1
LOAD  R0, 0xFF00
LOAD  R1, 0x0FF0
AND   R0, R1          ; R0 = 0x0F00, C=0, V=0
; Tarkista välitulos
CPY   R2, R0          ; R2 = 0x0F00

; --- OR nollaa C ja V ---
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1
LOAD  R0, 0x0001
LOAD  R1, 0x0002
OR    R0, R1          ; R0 = 0x0003, C=0, V=0

; --- XOR nollaa C ja V ---
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1
LOAD  R0, 0x00FF
LOAD  R1, 0xFF00
XOR   R0, R1          ; R0 = 0xFFFF, C=0, V=0

; --- NOT nollaa C ja V ---
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1
LOAD  R0, 0x0000
NOT   R0              ; R0 = 0xFFFF, C=0, V=0

HALT

.expect_reg   R2, 0x0F00     ; AND-tulos
.expect_reg   R0, 0xFFFF     ; viimeinen NOT-tulos
.expect_flag  C, 0           ; NOT nollasi carry:n
.expect_flag  V, 0           ; NOT nollasi overflow:n
