; =============================================================
; TESTI: CMP kaikki vertailutapaukset
; =============================================================
; Testaa CMP:n lippuasetukset kaikilla kombinaatioilla:
; 1. A = B  (Z=1)
; 2. A > B  (Z=0, N=0, C=0 unsigned)
; 3. A < B  (Z=0, N=1, C=1 borrow)
; 4. Signed: positiivinen vs negatiivinen
; 5. CMP ei muuta operandeja
; =============================================================

.origin 0x0200

; Case 1: A = B
JARI  R0, 100
JARI  R1, 100
CMP   R0, R1          ; Z=1, N=0, C=0, V=0
JZ    case2
JARI  R2, 99          ; ei suoriteta
case2:

; Case 2: A > B (unsigned ja signed)
JARI  R0, 200
JARI  R1, 50
CMP   R0, R1          ; Z=0, N=0, C=0, V=0
JGT   case3
JARI  R2, 99
case3:

; Case 3: A < B
JARI  R0, 10
JARI  R1, 500
CMP   R0, R1          ; Z=0, C=1 (borrow: 10 < 500)
JLT   case4
JARI  R2, 99
case4:

; Case 4: Signed: 0x8000 (-32768) vs 0x0001 (1)
; CMP: 0x8000 - 0x0001 = 0x7FFF
; N=0, V=1 -> N!=V -> signed less than!
JARI  R0, 0x8000
JARI  R1, 0x0001
CMP   R0, R1
JLT   case5            ; -32768 < 1 -> otettu
JARI  R2, 99
case5:

; Viimeinen CMP: varmista operandit ehjät
JARI  R0, 42
JARI  R1, 42
CMP   R0, R1

HALT

.expect_reg   R0, 42         ; CMP ei muuta R0:aa
.expect_reg   R1, 42         ; CMP ei muuta R1:tä
.expect_reg   R2, 0          ; kaikki hypyt onnistuivat
.expect_flag  Z, 1           ; viimeisin CMP: 42 = 42
.expect_flag  C, 0
.expect_flag  V, 0
.expect_flag  N, 0
