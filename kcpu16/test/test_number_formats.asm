; =============================================================
; TESTI: Lukuformaatit (decimal, hex, binary, octal)
; =============================================================
; Testaa kaikki assemblerin tukemat numeroliteraalimuodot:
; - Desimaali:      42
; - Heksadesimaali: 0xFF
; - Binääri:        0b1010
; - Oktaali:        0o52
; =============================================================

.origin 0x0200

; Desimaali
JARI  R0, 100

; Heksadesimaali
JARI  R1, 0xAB

; Binääri
JARI  R2, 0b11001100

; Oktaali (sama arvo eri muodossa)
JARI  R3, 0o62        ; 0o62 == 50 (desimaali)

; Muistioperaatiot eri formaateilla
STORE [0x0300], R0  ; mem[0x0300] = 100 (hex-osoite)
JARI R1, [0x0300]  ; R1 = mem[0x0300] = 100

; Nolla eri formaateissa
JARI  R0, 0
JARI  R2, 0x0000
JARI  R3, 0b0

; Maksimiarvo
JARI  R0, 0xFFFF
JARI  R1, 65535        ; sama desimaalina
JARI  R2, 0b1111111111111111  ; sama binäärinä

HALT

.expect_reg   R0, 0xFFFF
.expect_reg   R1, 65535
.expect_reg   R2, 0xFFFF       ; kaikki samat
.expect_reg   R3, 0            ; viimeisin JARI R3, 0b0
.expect_mem   0x0300, 100      ; STORE [0x0300], R0 (R0 oli 100)
