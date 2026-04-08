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
JARI  R0, timer_handler
STORE [0x0007], R0

; R3 = 0 (handler asettaa 0xBEEF)
JARI  R3, 0

; Aseta ajastin: TMR = 10 (laukeaa joka 10. käsky)
JARI  R0, 10
STMR  R0

; Salli keskeytykset
STI

; Suorita tarpeeksi käskyjä (noppia)
; Tarvitaan ~10 käskyä ennen laukaisua
; Instruction counter on jo kasvanut tähän asti
; Käytetään NOP-tyylisiä JARI-käskyjä
JARI  R0, 0          ; #1
JARI  R0, 0          ; #2
JARI  R0, 0          ; #3
JARI  R0, 0          ; #4
JARI  R0, 0          ; #5
JARI  R0, 0          ; #6
JARI  R0, 0          ; #7
JARI  R0, 0          ; #8
JARI  R0, 0          ; #9
JARI  R0, 0          ; #10
JARI  R0, 0          ; #11
JARI  R0, 0          ; #12
JARI  R0, 0          ; #13
JARI  R0, 0          ; #14
JARI  R0, 0          ; #15
JARI  R0, 0          ; #16
JARI  R0, 0          ; #17
JARI  R0, 0          ; #18
JARI  R0, 0          ; #19
JARI  R0, 0          ; #20

HALT

timer_handler:
    JARI  R3, 0xBEEF  ; merkki: timer handler suoritettiin
    IRET

.expect_reg   R3, 0xBEEF     ; timer-keskeytys laukesi
