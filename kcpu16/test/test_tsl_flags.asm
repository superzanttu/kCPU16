; =============================================================
; TESTI: TSL lippuvaikutukset
; =============================================================
; Testaa TSL:n Z- ja N-lippujen asettuminen vanhan arvon mukaan.
; =============================================================

.origin 0x0200

; Tapaus 1: vanha arvo = 0 -> Z=1
READ  R0, 0
STORE [0x0300], R0
TSL   R1, 0x0300      ; R1 = 0, Z=1, mem[0x0300] = 1

; Tapaus 2: vanha arvo = 0x8000 (negatiivinen) -> N=1
READ  R0, 0x8000
STORE [0x0301], R0
TSL   R2, 0x0301      ; R2 = 0x8000, N=1, mem[0x0301] = 1

; Tapaus 3: vanha arvo = 1 (ei-nolla, positiivinen) -> Z=0, N=0
READ  R0, 1
STORE [0x0302], R0
TSL   R3, 0x0302      ; R3 = 1

HALT

.expect_reg   R1, 0
.expect_reg   R2, 0x8000
.expect_reg   R3, 1
.expect_mem   0x0300, 1       ; kaikki lukittu
.expect_mem   0x0301, 1
.expect_mem   0x0302, 1
.expect_flag  Z, 0           ; viimeisin TSL: vanha=1, ei nolla
.expect_flag  N, 0           ; viimeisin TSL: vanha=1, ei neg
