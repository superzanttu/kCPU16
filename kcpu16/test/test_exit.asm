; =============================================================
; TESTI: EXIT-käsky
; =============================================================
; Testaa EXIT: prosessin hallittu lopetus.
; EXIT asettaa process_exit_requested = True ja pysäyttää
; suorituksen. EXIT:n jälkeistä koodia EI suoriteta.
; =============================================================

.origin 0x0200

; Normaalikoodia
JARI  R0, 10
JARI  R1, 20
ADD   R0, R1          ; R0 = 30

; Tallenna merkki R3:een ennen EXIT:iä
JARI  R3, 55

; Aseta EXIT-handler (INT 8) -> HALT
JARI  R2, exit_handler
STORE [0x0008], R2

; Kutsu EXIT
EXIT

; Tätä EI suoriteta EXIT:n jälkeen
JARI  R3, 99
HALT

exit_handler:
    HALT

.expect_reg   R0, 30         ; normaalikoodin tulos
.expect_reg   R3, 55         ; EXIT:n jälkeistä JARI R3, 99 EI suoritettu
