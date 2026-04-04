; =============================================================================
; test_factorial_result.asm — Testi: 5! = 120
; =============================================================================

        .origin 0x0200

        LOAD  R0, 5         ; R0 = n = 5
        LOAD  R1, 1         ; R1 = tulos = 1
        LOAD  R3, 0         ; R3 = vakio 0 (vertailuun)
        LOAD  R2, 1         ; R2 = vakio 1 (vähennykseen)

loop:
        CMP   R0, R3        ; vertaa laskuria nollaan
        JZ    done          ; jos nolla, lopeta
        MUL   R1, R0        ; tulos *= laskuri
        SUB   R0, R2        ; laskuri--
        JUMP  loop

done:
        HALT

; --- Odotukset ---
.expect_reg   R1, 120       ; 5! = 120
.expect_reg   R0, 0         ; laskuri nollautui
.expect_flag  Z, 1          ; viimeisin CMP oli nolla
.expect_flag  N, 0          ; ei negatiivinen
