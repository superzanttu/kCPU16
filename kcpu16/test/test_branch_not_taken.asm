; =============================================================
; TESTI: Ehdolliset hypyt - negatiiviset tapaukset
; =============================================================
; Testaa että ehdolliset hypyt EI tapahdu kun ehto ei täyty.
; Jokaisessa tapauksessa hypyn kohteen jälkeen ladataan arvo
; joka osoittaa että hyppyä ei suoritettu.
; =============================================================

.origin 0x0200

; --- JZ EI hyppää kun Z=0 ---
READ  R0, 5
READ  R1, 3
CMP   R0, R1          ; 5 - 3 = 2 -> Z=0
JZ    fail1           ; EI pitäisi hypätä
READ  R0, 1           ; suoritetaan -> R0=1
JUMP  test2
fail1:
READ  R0, 99          ; ei suoriteta

test2:
; --- JNZ EI hyppää kun Z=1 ---
READ  R1, 5
READ  R2, 5
CMP   R1, R2          ; 5 - 5 = 0 -> Z=1
JNZ   fail2           ; EI pitäisi hypätä
READ  R1, 2           ; suoritetaan -> R1=2
JUMP  test3
fail2:
READ  R1, 99

test3:
; --- JLT EI hyppää kun a > b ---
READ  R2, 10
READ  R3, 3
CMP   R2, R3          ; 10 - 3 = 7 -> N=0, V=0, N=V -> ei LT
JLT   fail3           ; EI pitäisi hypätä
READ  R2, 3           ; suoritetaan -> R2=3
JUMP  test4
fail3:
READ  R2, 99

test4:
; --- JGT EI hyppää kun a = b ---
READ  R3, 7
CPY   FP, R3          ; FP = 7 (käytetään tilapäisesti)
CMP   R3, FP          ; 7 - 7 = 0 -> Z=1, ei GT
JGT   fail4           ; EI pitäisi hypätä (Z=1)
READ  R3, 4           ; suoritetaan -> R3=4
JUMP  test5
fail4:
READ  R3, 99

test5:
; --- JLE EI hyppää kun a > b (signed) ---
READ  R0, 10
READ  R1, 3
CMP   R0, R1          ; 10 - 3 = 7 -> Z=0, N=0, V=0 -> N=V, ei LE
JLE   fail5           ; EI pitäisi hypätä
JUMP  test6
fail5:
READ  R3, 99          ; ei suoriteta

test6:
; --- JGE EI hyppää kun a < b (signed) ---
READ  R0, 3
READ  R1, 10
CMP   R0, R1          ; 3 - 10 -> N=1, V=0 -> N!=V, ei GE
JGE   fail6           ; EI pitäisi hypätä
JUMP  done
fail6:
READ  R3, 99          ; ei suoriteta

done:
HALT

.expect_reg   R0, 3    ; viimeinen LOAD R0 = 3 (test6)
.expect_reg   R1, 10   ; viimeinen LOAD R1 = 10 (test6)
.expect_reg   R2, 3    ; JLT ei hypännyt
.expect_reg   R3, 4    ; JGT ei hypännyt (JLE/JGE eivät muuta R3:a)
