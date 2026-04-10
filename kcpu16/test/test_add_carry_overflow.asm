; =============================================================
; TESTI: ADD kun C=1 ja V=1 samanaikaisesti
; =============================================================
; 0x8000 + 0x8000 = 0x10000 -> truncated 0x0000
; C=1 (unsigned overflow), V=1 (signed overflow), Z=1, N=0
; =============================================================

.origin 0x0200

READ  R0, 0x8000
READ  R1, 0x8000
ADD   R0, R1          ; 0x8000 + 0x8000 = 0x10000 -> R0=0

HALT

.expect_reg   R0, 0
.expect_flag  C, 1           ; unsigned overflow
.expect_flag  V, 1           ; signed overflow
.expect_flag  Z, 1           ; result = 0
.expect_flag  N, 0
