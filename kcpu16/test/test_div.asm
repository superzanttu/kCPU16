; =============================================================================
; test_div.asm — DIV regD, regS
; Kokonaislukujako: regD = regD / regS (katkaisu nollaan päin).
; =============================================================================

        .origin 0x0200

        LOAD  R0, 100
        LOAD  R1, 4
        DIV   R0, R1          ; R0 = 100 / 4 = 25

        LOAD  R2, 17
        LOAD  R3, 5
        DIV   R2, R3          ; R2 = 17 / 5 = 3 (katkaisu)

        HALT

.expect_reg   R0, 25
.expect_reg   R2, 3
.expect_flag  Z, 0
.expect_flag  N, 0
