; =============================================================
; TESTI: User/Kernel mode -vaihto
; =============================================================
; Testaa:
; 1. Testrunner aloittaa kernel modessa (P=1)
; 2. IRET:llä siirtyminen user modeen (P=0)
; 3. INT:n kautta paluu kernel modeen (P=1)
; 4. P-lipun oikea tila eri vaiheissa
; =============================================================

.origin 0x0200

; Aseta INT 3 -vektori
JARI  R0, int3_handler
STORE [0x0003], R0

; Aseta INT 8 -vektori (EXIT)
JARI  R0, exit_handler
STORE [0x0008], R0

; Kernel modessa alkuun: P=1
JARI  R0, 1           ; merkki: kernel-vaihe suoritettu

; Siirry user modeen
JARI  R1, user_start
PUSH  R1              ; PC
JARI  R1, 0           ; SR=0 (P=0, user mode)
PUSH  R1              ; SR
IRET                  ; -> user mode

user_start:
; Ollaan user modessa (P=0)
JARI  R1, 2           ; merkki: user-vaihe suoritettu

; Kutsu INT 3 -> siirtyy kernel modeen
INT   3

; Paluu INT:stä -> ollaan taas user modessa
JARI  R2, 3           ; merkki: paluu-vaihe suoritettu
EXIT

int3_handler:
    ; Handler ajetaan kernel modessa
    JARI  R3, 4       ; merkki: handler suoritettu kernel-tilassa
    IRET              ; palaa user-tilaan

exit_handler:
    HALT

.expect_reg   R0, 1          ; kernel-vaihe OK
.expect_reg   R1, 2          ; user-vaihe OK
.expect_reg   R2, 3          ; paluu INT:stä OK
.expect_reg   R3, 4          ; handler suoritettu
