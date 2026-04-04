; =============================================================
; TESTI: Lukuformaatit (decimal, hex, binary, #-prefix)
; =============================================================
; Testaa kaikki assemblerin tukemat lukuformaatit:
; - Desimaali: 42
; - Heksadesimaali: 0xFF
; - Binääri: 0b1010
; - #-etuliite: #42, #0xFF, #0b1010
; =============================================================

.origin 0x0200

; Desimaali
LOAD  R0, 100

; Heksadesimaali
LOAD  R1, 0xAB

; Binääri
LOAD  R2, 0b11001100

; #-etuliitteellä (immediate marker)
LOAD  R3, #50

; #-etuliite + hex
STORE R0, 0x0300
READ  R1, #0x0300      ; sama kuin READ R1, 0x0300 (# ei muuta arvoa)

; Nolla eri formaateissa
LOAD  R0, 0
LOAD  R2, 0x0000
LOAD  R3, 0b0

; Maksimiarvo
LOAD  R0, 0xFFFF
LOAD  R1, 65535        ; sama desimaalina
LOAD  R2, 0b1111111111111111  ; sama binäärinä

HALT

.expect_reg   R0, 0xFFFF
.expect_reg   R1, 65535
.expect_reg   R2, 0xFFFF       ; kaikki samat
.expect_reg   R3, 0            ; viimeisin LOAD R3, 0b0
.expect_mem   0x0300, 100      ; STORE R0, 0x0300 (R0 oli 100)
