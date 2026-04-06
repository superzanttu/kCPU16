; =============================================================
; TESTI: SUB ja ADD nollatulokset (Z-lippu)
; =============================================================
; Testaa Z-lipun asettuminen kun tulos = 0.
; =============================================================

.origin 0x0200

; ADD: 0 + 0 = 0 -> Z=1
LOAD  R0, 0
LOAD  R1, 0
ADD   R0, R1
; Tarkista välissä: Z pitäisi olla 1
; (ei voi tarkistaa suoraan, joten jatketaan)

; SUB: 42 - 42 = 0 -> Z=1
LOAD  R0, 42
LOAD  R1, 42
SUB   R0, R1          ; R0 = 0, Z=1

HALT

.expect_reg   R0, 0
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0     ; 42 - 42: ei borrowia (a >= b)
.expect_flag  V, 0
