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
READ  R0, timer_handler
STORE [0x0007], R0

; R3 = 0 (handler asettaa 0xBEEF)
READ  R3, 0

; Aseta ajastin: TMR = 10 (laukeaa joka 10. käsky)
READ  R0, 10
STMR  R0

; Salli keskeytykset
STI

; Suorita tarpeeksi käskyjä (noppia)
; Tarvitaan ~10 käskyä ennen laukaisua
; Instruction counter on jo kasvanut tähän asti
; Käytetään NOP-tyylisiä LOAD-käskyjä
READ  R0, 0          ; #1
READ  R0, 0          ; #2
READ  R0, 0          ; #3
READ  R0, 0          ; #4
READ  R0, 0          ; #5
READ  R0, 0          ; #6
READ  R0, 0          ; #7
READ  R0, 0          ; #8
READ  R0, 0          ; #9
READ  R0, 0          ; #10
READ  R0, 0          ; #11
READ  R0, 0          ; #12
READ  R0, 0          ; #13
READ  R0, 0          ; #14
READ  R0, 0          ; #15
READ  R0, 0          ; #16
READ  R0, 0          ; #17
READ  R0, 0          ; #18
READ  R0, 0          ; #19
READ  R0, 0          ; #20

HALT

timer_handler:
    READ  R3, 0xBEEF  ; merkki: timer handler suoritettiin
    IRET

.expect_reg   R3, 0xBEEF     ; timer-keskeytys laukesi
