; =============================================================
; TESTI: DIV nollalla -> INT 0 (divide by zero interrupt)
; =============================================================
; Testaa että jako nollalla laukaisee keskeytyksen 0 ja
; suoritus siirtyy keskeytysvektorin osoittamaan handleriin.
;
; Huom: DIV-poikkeus tallentaa PC:n joka osoittaa DIV-käskyyn.
; Handler:in täytyy ohittaa DIV (3 sanaa) palauttaessaan.
; =============================================================

.origin 0x0200

; Aseta keskeytysvektori 0 (INT_DIV_ZERO)
LOAD  R0, div_handler
STORE [0x0000], R0  ; vektori 0

; Yritä jakaa nollalla
LOAD  R0, 100
LOAD  R1, 0
DIV   R0, R1          ; jakaja = 0 -> INT 0

; Tänne palataan handler:ista (DIV ohitettu)
LOAD  R2, 88
HALT

div_handler:
    LOAD  R3, 0xDEAD  ; merkki: handler suoritettiin
    ; Ohita DIV-käsky: pop SR ja PC, lisää 3 (DIV koko), push takaisin
    POP   R0          ; old_SR
    POP   R1          ; old_PC (osoittaa DIV:iin)
    LOAD  R2, 3
    ADD   R1, R2      ; old_PC + 3 = ohita DIV
    PUSH  R1          ; korjattu PC
    PUSH  R0          ; SR takaisin
    IRET

.expect_reg   R3, 0xDEAD     ; div-by-zero handler suoritettiin
.expect_reg   R2, 88         ; palattiin DIV:n jälkeiseen käskyyn
