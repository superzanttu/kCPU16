; =============================================================
; TESTI: Muistisuojaus (SMPR + memory access fault INT 5)
; =============================================================
; Testaa:
; 1. SMPR asettaa muistisuojausrajan (MPR)
; 2. User-mode ei voi lukea alle MPR:n
; 3. Memory access fault (INT 5) laukeaa
; =============================================================

.origin 0x0200

; Aseta keskeytysvektori 5 (memory access fault)
LOAD  R0, mem_handler
STORE [0x0005], R0

; Aseta keskeytysvektori 8 (EXIT)
LOAD  R0, exit_handler
STORE [0x0008], R0

; Aseta muistisuojaus: MPR = 0x0300
; Alle 0x0300 on suojattua (paitsi VRAM)
LOAD  R0, 0x0300
SMPR  R0

; Kirjoita suojattuun alueeseen (kernel-tilassa OK)
LOAD  R0, 0xCAFE
STORE [0x0050], R0  ; kernel voi kirjoittaa alle MPR:n

; Siirry user modeen IRET:llä
LOAD  R0, user_code
PUSH  R0              ; PC = user_code
LOAD  R0, 0           ; SR = 0 (P=0, user mode)
PUSH  R0
IRET

user_code:
; Ollaan user modessa
LOAD  R0, 11          ; tallenna merkki R0:een (handler ei käytä R0:aa)

; Yritä lukea suojatusta osoitteesta (0x0050 < MPR=0x0300)
LOAD R2, [0x0050]  ; -> INT 5 (memory access fault)

; Tänne palataan handler:ista
LOAD  R2, 22
EXIT

mem_handler:
    LOAD  R3, 0xFADE  ; merkki: handler suoritettiin
    ; Ohita LOAD-käsky (3 sanaa: opcode + reg + addr)
    POP   R1          ; old_SR  (handler saa käyttää R1:tä)
    POP   FP          ; old_PC  (handler saa käyttää FP:tä)
    LOAD  R2, 3
    ADD   FP, R2      ; ohita LOAD (3 sanaa)
    PUSH  FP          ; korjattu PC takaisin
    PUSH  R1          ; SR takaisin
    IRET

exit_handler:
    HALT

.expect_reg   R3, 0xFADE     ; memory fault handler suoritettiin
.expect_reg   R0, 11         ; user-koodin arvo ennen faultia säilyi
.expect_mem   0x0050, 0xCAFE ; kernel pystyi kirjoittamaan
