; =============================================================
; TESTI: Kaikkien testattavien keskeytysten testaus
; =============================================================
; Testaa INT 0, 1, 3, 4, 5 ja 7 peräjälkeen, INT 8:llä lopetus.
;
; INT 2 (stack overflow): ei testattavissa luotettavasti
;   automaattisesti (vaatisi erityisen pinon setup:in).
; INT 6 (keyboard): testattu erillisessä test_keyboard_interrupt.asm:ssä.
; INT 8 (process exit): EXIT lopettaa koneen ennen handlerin ajoa
;   (process_exit_requested=True poistuu run-silmukasta välittömästi)
;   -> testattu erikseen test_exit.asm:ssä.
; INT 9 (clock): testattu erillisessä test_clock_interrupt.asm:ssä.
;
; Jokainen handler asettaa oman merkkirekisterinsä:
;   INT 0 (DIV_ZERO)            -> R8  = 0xA0
;   INT 1 (INVALID_OPCODE)      -> R9  = 0xA1
;   INT 3 (BREAKPOINT)          -> R10 = 0xA3
;   INT 7 (TIMER)               -> R11 = 0xA7
;   INT 4 (PRIVILEGE_VIOLATION) -> R12 = 0xA4  (user-tilassa)
;   INT 5 (MEMORY_ACCESS_FAULT) -> R13 = 0xA5  (user-tilassa)
;   INT 8 (PROCESS_EXIT)        -> EXIT lopettaa suorituksen
;
; Testijärjestys:
;   1. Kernel-tilassa: INT 0, 1, 3, 7
;   2. Siirtyminen user-tilaan (IRET)
;   3. User-tilassa: INT 4, 5
;   4. EXIT lopettaa suorituksen
; =============================================================

.origin 0x0200

; --- Aseta handlerit ---
READ  R0, handler0
STORE [0x0000], R0     ; INT 0 (DIV_ZERO)

READ  R0, handler1
STORE [0x0001], R0     ; INT 1 (INVALID_OPCODE)

READ  R0, handler3
STORE [0x0003], R0     ; INT 3 (BREAKPOINT)

READ  R0, handler4
STORE [0x0004], R0     ; INT 4 (PRIVILEGE_VIOLATION)

READ  R0, handler5
STORE [0x0005], R0     ; INT 5 (MEMORY_ACCESS_FAULT)

READ  R0, handler7
STORE [0x0007], R0     ; INT 7 (TIMER)

READ  R0, exit_handler
STORE [0x0008], R0     ; INT 8 (PROCESS_EXIT) -> HALT

; Aseta muistisuojaus: MPR = 0x0300
; User-tila ei voi lukea/kirjoittaa alle 0x0300
READ  R0, 0x0300
SMPR  R0

; -------------------------------------------------------
; INT 0: jako nollalla (DIV_ZERO)
; -------------------------------------------------------
READ  R0, 100
READ  R1, 0
DIV   R0, R1           ; jakaja = 0 -> INT 0

; -------------------------------------------------------
; INT 1: virheellinen opcode (INVALID_OPCODE)
; -------------------------------------------------------
JUMP  0x0700           ; hyppää 0x0000-sanaan -> INT 1

after_inv_opcode:

; -------------------------------------------------------
; INT 3: ohjelmallinen keskeytys (BREAKPOINT)
; -------------------------------------------------------
INT   3

; -------------------------------------------------------
; INT 7: ajastinkeskeytys (TIMER)
; Handler poistaa ajastimen heti, joten se laukeaa kerran.
; -------------------------------------------------------
READ  R0, 5
STMR  R0               ; TMR = 5 (laukeaa joka 5. käsky)
STI                    ; salli keskeytykset
READ  R0, 0            ; #1
READ  R0, 0            ; #2
READ  R0, 0            ; #3
READ  R0, 0            ; #4
READ  R0, 0            ; #5
READ  R0, 0            ; #6
READ  R0, 0            ; #7
READ  R0, 0            ; #8
READ  R0, 0            ; #9
READ  R0, 0            ; #10
READ  R0, 0            ; #11
READ  R0, 0            ; #12
READ  R0, 0            ; #13
READ  R0, 0            ; #14
READ  R0, 0            ; #15
READ  R0, 0            ; #16
READ  R0, 0            ; #17
READ  R0, 0            ; #18
READ  R0, 0            ; #19
READ  R0, 0            ; #20
CLI                    ; estä lisäkeskeytykset
READ  R0, 0
STMR  R0               ; TMR = 0 (ajastin pois)

; -------------------------------------------------------
; Siirry user-tilaan (IRET P=0)
; -------------------------------------------------------
READ  R0, user_code
PUSH  R0               ; PC = user_code
READ  R0, 0            ; SR = 0 (P=0, I=0, user mode)
PUSH  R0
IRET                   ; -> user mode

; ---- HANDLERIT (kernel mode) ----

handler0:
        READ  R8, 0xA0         ; INT 0 merkki
        ; Ohita DIV-käsky (3 sanaa)
        POP   R0
        POP   R1               ; old_PC (osoittaa DIV:iin)
        READ  R2, 3
        ADD   R1, R2
        PUSH  R1
        PUSH  R0
        IRET

handler1:
        READ  R9, 0xA1         ; INT 1 merkki
        ; Palaa after_inv_opcode:iin (ei 0x0701 joka on 0x0000)
        POP   R0
        POP   R1               ; hylkää old_PC
        READ  R1, after_inv_opcode
        PUSH  R1
        PUSH  R0
        IRET

handler3:
        READ  R10, 0xA3        ; INT 3 merkki
        IRET

handler7:
        READ  R11, 0xA7        ; INT 7 merkki
        READ  R0, 0
        STMR  R0               ; poista ajastin heti (ei enempää laukaisuja)
        IRET

handler4:
        READ  R12, 0xA4        ; INT 4 merkki
        ; Ohita HALT-käsky (1 sana) ja palaa user-tilaan
        POP   R0
        POP   R1               ; old_PC (osoittaa HALTiin)
        READ  R2, 1
        ADD   R1, R2           ; hyppää HALTin yli
        PUSH  R1
        PUSH  R0
        IRET                   ; palaa user-tilaan (SR:ssä P=0)

handler5:
        READ  R13, 0xA5        ; INT 5 merkki
        ; Ohita LOAD reg,[addr] -käsky (3 sanaa) ja palaa user-tilaan
        POP   R0
        POP   R1               ; old_PC (osoittaa LOADiin)
        READ  R2, 3
        ADD   R1, R2           ; hyppää LOADin yli
        PUSH  R1
        PUSH  R0
        IRET                   ; palaa user-tilaan

exit_handler:
        HALT                   ; lopeta suoritus (INT 8 handler)

; ---- USER-TILAN KOODI ----

user_code:
; INT 4: yritä ajaa HALT user-tilassa -> privilege violation
HALT                           ; -> INT 4 (privileged in user mode)

after_priv:
; INT 5: lue muistisuojattu osoite (0x0050 < MPR=0x0300)
READ  R6, [0x0050]             ; -> INT 5 (memory access fault)

after_mem_fault:
; INT 8: prosessin lopetus (lopettaa ajon, handleri ei ehdi ajaa)
EXIT

; ---- VIRHEELLINEN OPCODE DATAOSIO ----
.at 0x0700
        .db 0x00               ; 0x0000 = virheellinen opcode (GRP=0)

.expect_reg   R8,  0xA0        ; INT 0 (DIV_ZERO) laukesi
.expect_reg   R9,  0xA1        ; INT 1 (INVALID_OPCODE) laukesi
.expect_reg   R10, 0xA3        ; INT 3 (BREAKPOINT) laukesi
.expect_reg   R11, 0xA7        ; INT 7 (TIMER) laukesi
.expect_reg   R12, 0xA4        ; INT 4 (PRIVILEGE_VIOLATION) laukesi
.expect_reg   R13, 0xA5        ; INT 5 (MEMORY_ACCESS_FAULT) laukesi
