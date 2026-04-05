; =============================================================
; TESTI: Privilege violation - user mode yrittää kernel-käskyä
; =============================================================
; Testaa INT 4 (PRIVILEGE_VIOLATION) laukeaminen kun
; user-mode ohjelma yrittää suorittaa HALT-käskyn (privileged).
;
; Strategia:
; 1. Aseta privilege violation handler (vektori 4)
; 2. Siirry user modeen (IRET:llä P=0)
; 3. Yritä HALT -> INT 4
; 4. Handler asettaa merkkiarvon ja palaa
; =============================================================

.origin 0x0200

; Aseta keskeytysvektori 4 (privilege violation)
LOAD  R0, priv_handler
STORE [0x0004], R0

; Aseta keskeytysvektori 8 (EXIT/process exit)
LOAD  R0, exit_handler
STORE [0x0008], R0

; Valmistele IRET joka siirtyy user modeen
; IRET: POP SR, POP PC
; Haluamme: SR = 0 (P=0, I=0), PC = user_code
LOAD  R0, user_code
PUSH  R0              ; PC pinoon
LOAD  R0, 0           ; SR = 0 (user mode, interrupts off)
PUSH  R0              ; SR pinoon
IRET                  ; -> user mode, PC = user_code

user_code:
; Ollaan nyt user modessa (P=0)
LOAD  R1, 55

; Yritä HALT (privileged!) -> laukaisee INT 4
HALT

; Tänne palataan handler:ista
LOAD  R2, 66
EXIT                   ; lopeta prosessi

priv_handler:
    LOAD  R3, 0xBEEF  ; merkki: handler suoritettiin
    ; Ohita HALT-käsky (PC osoittaa HALT:iin, koko 1 sana)
    ; POP palauttaa alkuperäisen SR ja PC:n
    ; mutta PC osoittaa HALTiin joten vain IRET palaisi samaan
    ; -> Korjataan: pop SR/PC, siirretään PC yli HALT:n
    ; IRET palaisi HALTiin -> loputon silmukka
    ; -> Ratkaisu: manipuloidaan pinoa
    ; Pinossa: [old_PC, old_SR]
    ; Pop SR pois, pop PC, lisää 1, push takaisin, push SR, IRET
    POP   R0          ; R0 = old_SR
    POP   R1          ; R1 = old_PC (osoittaa HALT:iin)
    LOAD  R2, 1
    ADD   R1, R2      ; R1 = old_PC + 1 (ohita HALT)
    PUSH  R1          ; korjattu PC takaisin
    PUSH  R0          ; SR takaisin
    IRET              ; palaa HALT:n jälkeiseen käskyyn

exit_handler:
    HALT              ; pysäytä kone EXIT:n jälkeen

.expect_reg   R3, 0xBEEF     ; privilege violation handler ajettiin
