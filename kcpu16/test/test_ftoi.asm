; =============================================================================
; test_ftoi.asm — FTOI regD, regS
; float16 -> kokonaisluku muunnos (katkaisu nollaan päin).
; FTOI regD, regS: regD = int(float16(regS))
; =============================================================================
; float16-arvot:
;   3.0 = 0x4200
;   6.0 = 0x4600
;  42.0 = 0x5140

        .origin 0x0200

        LOAD  R1, 0x4200      ; R1 = 3.0 (float16)
        FTOI  R0, R1          ; R0 = int(3.0) = 3

        LOAD  R3, 0x5140      ; R3 = 42.0 (float16)
        FTOI  R2, R3          ; R2 = int(42.0) = 42

        HALT

.expect_reg   R0, 3
.expect_reg   R2, 42
