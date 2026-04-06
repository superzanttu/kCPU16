; =============================================================
; TESTI: Ajastinkeskeytys (STMR + INT 7)
; =============================================================
; Testaa funktionaalinen ajastinkeskeytys:
; - STMR asettaa ajastimen
; - STI sallii keskeytykset
; - Timer INT 7 laukeaa TMR:n monikertaisella käskylaskurilla
; - Handler merkitsee R3:een
; =============================================================

.origin 0x0200

; Aseta INT 7 handler (timer)
LOAD  R0, timer_handler
STORE [0x0007], R0

; R3 = 0 (handler asettaa 0xBEEF)
LOAD  R3, 0

; Aseta ajastin: TMR = 10 (laukeaa joka 10. käsky)
LOAD  R0, 10
STMR  R0

; Salli keskeytykset
STI

; Suorita tarpeeksi käskyjä (noppia)
; Tarvitaan ~10 käskyä ennen laukaisua
; Instruction counter on jo kasvanut tähän asti
; Käytetään NOP-tyylisiä LOAD-käskyjä
LOAD  R0, 0          ; #1
LOAD  R0, 0          ; #2
LOAD  R0, 0          ; #3
LOAD  R0, 0          ; #4
LOAD  R0, 0          ; #5
LOAD  R0, 0          ; #6
LOAD  R0, 0          ; #7
LOAD  R0, 0          ; #8
LOAD  R0, 0          ; #9
LOAD  R0, 0          ; #10
LOAD  R0, 0          ; #11
LOAD  R0, 0          ; #12
LOAD  R0, 0          ; #13
LOAD  R0, 0          ; #14
LOAD  R0, 0          ; #15
LOAD  R0, 0          ; #16
LOAD  R0, 0          ; #17
LOAD  R0, 0          ; #18
LOAD  R0, 0          ; #19
LOAD  R0, 0          ; #20

HALT

timer_handler:
    LOAD  R3, 0xBEEF  ; merkki: timer handler suoritettiin
    IRET

.expect_reg   R3, 0xBEEF     ; timer-keskeytys laukesi
