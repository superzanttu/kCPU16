; =============================================================
; TESTI: ADC signed overflow
; =============================================================
; Testaa ADC-käskyn V-lipun asettuminen kun tulos ylittää
; etumerkillisen alueen (signed overflow).
; =============================================================

.origin 0x0200

; Aseta carry=1 ensin
LOAD  R0, 0xFFFF
LOAD  R1, 1
ADD   R0, R1          ; 0xFFFF + 1 -> R0=0, C=1

; ADC joka tuottaa signed overflow:
; 0x7FFE + 0 + 1(carry) = 0x7FFF -> ei vielä overflow
LOAD  R0, 0x7FFE
LOAD  R1, 0
ADC   R0, R1          ; 0x7FFE + 0 + 1(C) = 0x7FFF -> V=0, C=0

; tallenna 0x7FFF
CPY   R2, R0          ; R2 = 0x7FFF

; Aseta carry=1 uudestaan
LOAD  R0, 0xFFFF
LOAD  R1, 1
ADD   R0, R1          ; C=1

; ADC: 0x7FFF + 0 + 1(carry) = 0x8000 -> signed overflow!
LOAD  R0, 0x7FFF
LOAD  R1, 0
ADC   R0, R1          ; 0x7FFF + 0 + 1(C) = 0x8000 -> V=1, N=1

HALT

.expect_reg   R2, 0x7FFF     ; aiempi välitulos
.expect_reg   R0, 0x8000     ; 32767 + 1 = -32768 (overflow!)
.expect_flag  V, 1           ; signed overflow
.expect_flag  N, 1           ; bit 15 set
.expect_flag  Z, 0
.expect_flag  C, 0           ; ei unsigned carry
