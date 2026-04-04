; =============================================================
; TESTI: Ehdolliset hypyt - negatiiviset tapaukset
; =============================================================
; Testaa että ehdolliset hypyt EI tapahdu kun ehto ei täyty.
; Jokaisessa tapauksessa hypyn kohteen jälkeen ladataan arvo
; joka osoittaa että hyppyä ei suoritettu.
; =============================================================

.origin 0x0200

; --- JZ EI hyppää kun Z=0 ---
LOAD  R0, 5
LOAD  R1, 3
CMP   R0, R1          ; 5 - 3 = 2 -> Z=0
JZ    fail1           ; EI pitäisi hypätä
LOAD  R0, 1           ; suoritetaan -> R0=1
JUMP  test2
fail1:
LOAD  R0, 99          ; ei suoriteta

test2:
; --- JNZ EI hyppää kun Z=1 ---
LOAD  R1, 5
LOAD  R2, 5
CMP   R1, R2          ; 5 - 5 = 0 -> Z=1
JNZ   fail2           ; EI pitäisi hypätä
LOAD  R1, 2           ; suoritetaan -> R1=2
JUMP  test3
fail2:
LOAD  R1, 99

test3:
; --- JLT EI hyppää kun a > b ---
LOAD  R2, 10
LOAD  R3, 3
CMP   R2, R3          ; 10 - 3 = 7 -> N=0, V=0, N=V -> ei LT
JLT   fail3           ; EI pitäisi hypätä
LOAD  R2, 3           ; suoritetaan -> R2=3
JUMP  test4
fail3:
LOAD  R2, 99

test4:
; --- JGT EI hyppää kun a = b ---
LOAD  R3, 7
CPY   FP, R3          ; FP = 7 (käytetään tilapäisesti)
CMP   R3, FP          ; 7 - 7 = 0 -> Z=1, ei GT
JGT   fail4           ; EI pitäisi hypätä (Z=1)
LOAD  R3, 4           ; suoritetaan -> R3=4
JUMP  done
fail4:
LOAD  R3, 99

done:
HALT

.expect_reg   R0, 1    ; JZ ei hypännyt
.expect_reg   R1, 2    ; JNZ ei hypännyt
.expect_reg   R2, 3    ; JLT ei hypännyt
.expect_reg   R3, 4    ; JGT ei hypännyt
