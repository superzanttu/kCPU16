; =============================================================================
; test_calli.asm — CALLI reg, addr... (indeksoitu epäsuora aliohjelmakutsu)
; CALLI tallentaa paluuosoitteen pinoon ja hyppää aliohjelmaan
; targets[reg]. RET palauttaa oikeaan paikkaan. Testataan indeksit 0, 1 ja 2.
; =============================================================================

        .origin 0x0200

; --- Tapaus 0: indeksi 0 → func0 ---
        LOAD  R0, 0
        CALLI R0, func0, func1, func2
        ; palataan tänne
        JUMP  next1

func0:
        LOAD  R1, 10          ; valittiin oikein
        RET
func1:
        LOAD  R1, 99
        RET
func2:
        LOAD  R1, 99
        RET

next1:
; --- Tapaus 1: indeksi 1 → funcB ---
        LOAD  R0, 1
        CALLI R0, funcA, funcB, funcC
        JUMP  next2

funcA:
        LOAD  R2, 99
        RET
funcB:
        LOAD  R2, 20          ; valittiin oikein
        RET
funcC:
        LOAD  R2, 99
        RET

next2:
; --- Tapaus 2: indeksi 2 → funcZ ---
        LOAD  R0, 2
        CALLI R0, funcX, funcY, funcZ
        JUMP  done

funcX:
        LOAD  R3, 99
        RET
funcY:
        LOAD  R3, 99
        RET
funcZ:
        LOAD  R3, 30          ; valittiin oikein
        RET

done:
        HALT

.expect_reg  R1, 10
.expect_reg  R2, 20
.expect_reg  R3, 30
