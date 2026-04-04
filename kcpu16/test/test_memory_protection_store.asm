; =============================================================
; TESTI: User-mode STORE suojattuun muistiin -> INT 5
; =============================================================
; Testaa että user-mode STORE alle MPR:n laukaisee INT 5.
; Myös STORE_IND ja READ_IND suojattuun osoitteeseen.
; =============================================================

.origin 0x0200

; Aseta INT 5 handler (memory access fault)
LOAD  R0, mem_handler
STORE R0, 0x0005

; Aseta INT 8 handler (EXIT)
LOAD  R0, exit_handler
STORE R0, 0x0008

; Aseta MPR = 0x0300
LOAD  R0, 0x0300
SMPR  R0

; R3 = laskuri
LOAD  R3, 0

; Siirry user modeen
LOAD  R0, user_code
PUSH  R0
LOAD  R0, 0           ; SR = 0 (user mode)
PUSH  R0
IRET

user_code:
; Testi 1: STORE suojattuun osoitteeseen (3 sanan käsky)
STORE R0, 0x0050      ; 0x0050 < MPR=0x0300 -> INT 5 (#1)

; Testi 2: STORE_IND suojattuun osoitteeseen (3 sanan käsky)
LOAD  R0, 0x0050      ; R0 = suojattu osoite
STORE_IND R0, R1      ; memory[R0=0x0050] -> INT 5 (#2)

; Testi 3: READ_IND suojattuun osoitteeseen (3 sanan käsky)
READ_IND R1, R0       ; memory[R0=0x0050] -> INT 5 (#3)

EXIT

mem_handler:
    ; R3++
    PUSH  R0
    PUSH  R1
    LOAD  R0, 1
    ADD   R3, R0

    ; Kaikki testatut käskyt ovat 3 sanaa (STORE/STORE_IND/READ_IND)
    ; Ohita 3 sanaa
    LOAD  R0, 4
    ADD   R0, SP      ; R0 = SP + 4 = &old_PC
    READ_IND R1, R0   ; R1 = old_PC
    LOAD  R0, 3
    ADD   R1, R0      ; R1 = old_PC + 3
    LOAD  R0, 4
    ADD   R0, SP      ; R0 = &old_PC
    STORE_IND R0, R1  ; päivitä old_PC

    POP   R1
    POP   R0
    IRET

exit_handler:
    HALT

.expect_reg   R3, 3           ; 3 memory access fault:ia
