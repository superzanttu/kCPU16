; =============================================================
; TESTI: SUB kun C=1 ja V=1 samanaikaisesti
; =============================================================
; 0x7FFF - 0xFFFF = 0x8000
; C=1 (borrow: 0x7FFF < 0xFFFF), V=1 (signed overflow)
; Z=0, N=1
; =============================================================

.origin 0x0200

JARI  R0, 0x7FFF
JARI  R1, 0xFFFF
SUB   R0, R1          ; 0x7FFF - 0xFFFF = 0x8000

HALT

.expect_reg   R0, 0x8000
.expect_flag  C, 1           ; borrow
.expect_flag  V, 1           ; signed overflow
.expect_flag  Z, 0
.expect_flag  N, 1
