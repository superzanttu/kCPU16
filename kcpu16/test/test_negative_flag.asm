; =============================================================
; TESTI: N-lippu (negatiivinen tulos)
; =============================================================
; Testaa N-lippu kaikissa aritmeettisissa ja loogisissa
; käskyissä jotka asettavat lippuja.
; =============================================================

.origin 0x0200

; ADD: tulos negatiivinen (bit 15 = 1)
READ  R0, 0x7FFF
READ  R1, 0x7FFF
ADD   R0, R1          ; 0x7FFF + 0x7FFF = 0xFFFE -> N=1

; Tarkista: AND ei nollaa N-lippua jos tulos negatiivinen
READ  R0, 0xF000
READ  R1, 0xFF00
AND   R0, R1          ; 0xF000 & 0xFF00 = 0xF000 -> N=1 (bit 15 set)

; OR: negatiivinen tulos
READ  R0, 0x8000
READ  R1, 0x0001
OR    R0, R1          ; 0x8001 -> N=1

; XOR: negatiivinen tulos
READ  R0, 0x0000
READ  R1, 0xFFFF
XOR   R0, R1          ; 0xFFFF -> N=1

; SHL: siirto tuottaa negatiivisen
READ  R0, 1
READ  R1, 15
SHL   R0, R1          ; 1 << 15 = 0x8000 -> N=1

HALT

.expect_reg   R0, 0x8000
.expect_flag  N, 1           ; viimeisin tulos on negatiivinen
.expect_flag  Z, 0
