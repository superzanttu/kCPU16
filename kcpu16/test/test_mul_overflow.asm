; =============================================================
; TESTI: MUL overflow ja carry-liput
; =============================================================
; Testaa MUL-käskyn carry (C) ja overflow (V) lippujen asettuminen
; kun tulos ylittää 16 bitin rajan.
; =============================================================

.origin 0x0200

; Tapaus 1: Pieni tulos, ei overflowia
LOAD  R0, 10
LOAD  R1, 5
MUL   R0, R1          ; 10 * 5 = 50 -> C=0, V=0

; Tarkista välitulos
LOAD  R2, 0            ; tallenna tulos R2:een
CPY   R2, R0           ; R2 = 50

; Tapaus 2: Suuri tulos, carry
LOAD  R0, 0x0100       ; 256
LOAD  R1, 0x0100       ; 256
MUL   R0, R1          ; 256 * 256 = 65536 -> R0=0, C=1

HALT

.expect_reg   R2, 50         ; välitulos
.expect_reg   R0, 0          ; 65536 & 0xFFFF = 0
.expect_flag  Z, 1           ; tulos = 0
.expect_flag  C, 1           ; 65536 > 0xFFFF
.expect_flag  N, 0
.expect_flag  V, 0           ; MUL 256*256: V=0 (no signed overflow)
