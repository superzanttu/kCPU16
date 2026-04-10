; =============================================================
; TESTI: User-mode STORE suojattuun muistiin -> INT 5
; =============================================================
; Testaa että user-mode STORE alle MPR:n laukaisee INT 5.
; Myös STORE [reg], src ja LOAD reg, [reg] suojattuun osoitteeseen.
; =============================================================

.origin 0x0200

; Aseta INT 5 handler (memory access fault)
READ  R0, mem_handler
STORE [0x0005], R0

; Aseta INT 8 handler (EXIT)
READ  R0, exit_handler
STORE [0x0008], R0

; Aseta MPR = 0x0300
READ  R0, 0x0300
SMPR  R0

; R3 = laskuri
READ  R3, 0

; Siirry user modeen
READ  R0, user_code
PUSH  R0
READ  R0, 0           ; SR = 0 (user mode)
PUSH  R0
IRET

user_code:
; Testi 1: STORE suojattuun osoitteeseen (3 sanan käsky)
STORE [0x0050], R0  ; 0x0050 < MPR=0x0300 -> INT 5 (#1)

; Testi 2: STORE [reg], src suojattuun osoitteeseen (3 sanan käsky)
READ  R0, 0x0050      ; R0 = suojattu osoite
STORE [R0], R1  ; memory[R0=0x0050] -> INT 5 (#2)

; Testi 3: LOAD reg, [reg] suojattuun osoitteeseen (3 sanan käsky)
READ R1, [R0]  ; memory[R0=0x0050] -> INT 5 (#3)

EXIT

mem_handler:
    ; R3++
    PUSH  R0
    PUSH  R1
    READ  R0, 1
    ADD   R3, R0

    ; Kaikki testatut käskyt ovat 3 sanaa (STORE [addr]/STORE [reg]/LOAD [reg])
    ; Ohita 3 sanaa
    READ  R0, 4
    ADD   R0, SP      ; R0 = SP + 4 = &old_PC
    READ R1, [R0]  ; R1 = old_PC
    READ  R0, 3
    ADD   R1, R0      ; R1 = old_PC + 3
    READ  R0, 4
    ADD   R0, SP      ; R0 = &old_PC
    STORE [R0], R1  ; päivitä old_PC

    POP   R1
    POP   R0
    IRET

exit_handler:
    HALT

.expect_reg   R3, 3           ; 3 memory access fault:ia
