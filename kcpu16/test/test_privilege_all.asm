; =============================================================
; TESTI: Kaikki privileged-käskyt laukaisevat INT 4 user modessa
; =============================================================
; Testaa: HALT, STI, CLI, SMPR, STMR, IRET
; Handler laskee R3:een montako INT 4:ää tapahtui.
; Käytetään opcode-taulukkoa käskyn koon selvittämiseen.
; =============================================================

.origin 0x0200

; Aseta INT 4 handler (privilege violation)
LOAD  R0, priv_handler
STORE R0, 0x0004

; Aseta INT 8 handler (EXIT)
LOAD  R0, exit_handler
STORE R0, 0x0008

; R3 = laskuri
LOAD  R3, 0

; Siirry user modeen IRET:llä
LOAD  R0, user_code
PUSH  R0              ; PC = user_code
LOAD  R0, 0           ; SR = 0 (user mode, P=0)
PUSH  R0
IRET

user_code:
; 1-sanan käskyt:
HALT                  ; 1 sana -> INT 4 (#1)
STI                   ; 1 sana -> INT 4 (#2)
CLI                   ; 1 sana -> INT 4 (#3)
IRET                  ; 1 sana -> INT 4 (#4)
; 2-sanan käskyt:
SMPR  R0              ; 2 sanaa -> INT 4 (#5)
STMR  R0              ; 2 sanaa -> INT 4 (#6)

; Tänne palataan
EXIT

priv_handler:
    ; R3++ (laskuri)
    PUSH  R0
    PUSH  R1
    PUSH  R2
    LOAD  R0, 1
    ADD   R3, R0

    ; Lue faulting-opcode
    ; Stack: [R2][R1][R0][old_SR][old_PC]
    ; SP+4 = old_SR, SP+5 = old_PC
    ; Käytetään suoraa pinon lukua
    LOAD  R0, 5
    ADD   R0, SP        ; R0 = SP + 5
    READ_IND R1, R0     ; R1 = old_PC
    READ_IND R2, R1     ; R2 = opcode

    ; Käskyn koko: SMPR(0x47) ja STMR(0x48) ovat 2 sanaa, muut 1
    LOAD  R0, 1         ; oletus 1 sana
    LOAD  R1, 0x0047
    CMP   R2, R1
    JZ    ph_two
    LOAD  R1, 0x0048
    CMP   R2, R1
    JZ    ph_two
    JUMP  ph_skip
ph_two:
    LOAD  R0, 2         ; 2 sanan käsky
ph_skip:
    ; Lisää käskyn koko old_PC:hen
    LOAD  R1, 5
    ADD   R1, SP        ; R1 = SP + 5 = &old_PC
    READ_IND R2, R1     ; R2 = old_PC
    ADD   R2, R0        ; R2 = old_PC + size
    STORE_IND R1, R2    ; päivitä old_PC pinossa

    POP   R2
    POP   R1
    POP   R0
    IRET

exit_handler:
    HALT

.expect_reg   R3, 6           ; 6 privilege violation:ia tapahtui
