; =============================================================
; TESTI: Kaikki privileged-käskyt laukaisevat INT 4 user modessa
; =============================================================
; Testaa: HALT, STI, CLI, SMPR, STMR, IRET
; Handler laskee R3:een montako INT 4:ää tapahtui.
; Käytetään opcode-taulukkoa käskyn koon selvittämiseen.
; =============================================================

.origin 0x0200

; Aseta INT 4 handler (privilege violation)
READ  R0, priv_handler
STORE [0x0004], R0

; Aseta INT 8 handler (EXIT)
READ  R0, exit_handler
STORE [0x0008], R0

; R3 = laskuri
READ  R3, 0

; Siirry user modeen IRET:llä
READ  R0, user_code
PUSH  R0              ; PC = user_code
READ  R0, 0           ; SR = 0 (user mode, P=0)
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
    READ  R0, 1
    ADD   R3, R0

    ; Lue faulting-opcode
    ; Stack: [R2][R1][R0][old_SR][old_PC]
    ; SP+4 = old_SR, SP+5 = old_PC
    ; Käytetään suoraa pinon lukua
    READ  R0, 5
    ADD   R0, SP        ; R0 = SP + 5
    READ R1, [R0]  ; R1 = old_PC
    READ R2, [R1]  ; R2 = opcode

    ; Käskyn koko OPS-kentästä (bitit 7:6): size = 1 + OPS
    READ  R0, 6
    SHR   R2, R0        ; R2 = opcode >> 6
    READ  R0, 3
    AND   R2, R0        ; R2 = OPS kenttä (0-2)
    READ  R0, 1
    ADD   R0, R2        ; R0 = käskyn koko sanoina (1 + OPS)

    ; Lisää käskyn koko old_PC:hen
    READ  R1, 5
    ADD   R1, SP        ; R1 = SP + 5 = &old_PC
    READ R2, [R1]  ; R2 = old_PC
    ADD   R2, R0        ; R2 = old_PC + size
    STORE [R1], R2  ; päivitä old_PC pinossa

    POP   R2
    POP   R1
    POP   R0
    IRET

exit_handler:
    HALT

.expect_reg   R3, 6           ; 6 privilege violation:ia tapahtui
