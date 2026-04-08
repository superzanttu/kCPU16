; =============================================================
; TESTI: SHL ja SHR reunatapaukset
; =============================================================
; Testaa:
; 1. Siirto 0:lla (ei muutosta, C=0)
; 2. Siirto 16:lla (tulos=0)
; 3. Siirto yli 16 (tulos=0, C=0)
; =============================================================

.origin 0x0200

; SHL 0: ei muutosta
JARI  R0, 0xAAAA
JARI  R1, 0
SHL   R0, R1          ; R0 = 0xAAAA, C=0

CPY   R2, R0          ; tallenna: R2 = 0xAAAA

; SHL 16: kaikki bitit ulos
JARI  R0, 0xFFFF
JARI  R1, 16
SHL   R0, R1          ; R0 = 0, C = bit[0] of original (=1)

CPY   R3, R0          ; tallenna: R3 = 0

; SHR 0: ei muutosta
JARI  R0, 0x5555
JARI  R1, 0
SHR   R0, R1          ; R0 = 0x5555, C=0

; SHR yli 16: kaikki ulos
JARI  R0, 0xFFFF
JARI  R1, 17
SHR   R0, R1          ; R0 = 0, C=0 (yli 16)

HALT

.expect_reg   R2, 0xAAAA     ; SHL 0 ei muuttanut
.expect_reg   R3, 0          ; SHL 16 nollasi
.expect_reg   R0, 0          ; SHR 17 nollasi
.expect_flag  Z, 1           ; viimeisin tulos = 0
.expect_flag  C, 0           ; shift > 16 -> C=0
.expect_flag  N, 0
