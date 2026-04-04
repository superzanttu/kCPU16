; =============================================================
; TESTI: CALL/RET sisäkkäiset kutsut
; =============================================================
; Testaa CALL ja RET useamman tason syvyydeltä.
; =============================================================

.origin 0x0200

LOAD  R0, 0
CALL  func_a          ; kutsutaso 1
HALT

func_a:
    LOAD  R0, 1       ; R0 = 1
    CALL  func_b      ; kutsutaso 2
    LOAD  R2, 3       ; suoritetaan func_b:n jälkeen
    RET

func_b:
    LOAD  R1, 2       ; R1 = 2
    CALL  func_c      ; kutsutaso 3
    RET

func_c:
    LOAD  R3, 4       ; R3 = 4
    RET

.expect_reg   R0, 1          ; func_a suoritettu
.expect_reg   R1, 2          ; func_b suoritettu
.expect_reg   R2, 3          ; paluu func_b:stä oikeaan paikkaan
.expect_reg   R3, 4          ; func_c suoritettu (3x nested)
