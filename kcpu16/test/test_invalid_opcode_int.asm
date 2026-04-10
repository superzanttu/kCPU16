; =============================================================
; TESTI: INT 1 (INVALID_OPCODE) - virheellinen opcode
; =============================================================
; Testaa että virheellinen opcode (GRP=0 alue, 0x0000) laukaisee
; INT 1 ja suoritus siirtyy handleriin.
;
; Strategia:
;   1. Aseta INT 1 handler (vektori 1)
;   2. .at 0x0500: kirjoita 0x0000 (virheellinen opcode, GRP=0)
;   3. JUMP 0x0500 -> CPU yrittää suorittaa 0x0000 -> INT 1
;   4. Handler asettaa R3=0xFACE ja palauttaa PC:n after_trap:iin
; =============================================================

.origin 0x0200

; Aseta INT 1 handler (invalid opcode)
READ  R0, inv_handler
STORE [0x0001], R0

; Hyppää virheellisen opcoden kohdalle (0x0500)
JUMP  0x0500

after_trap:
        READ  R1, 77
        HALT

inv_handler:
        READ  R3, 0xFACE       ; merkki: INT 1 handler suoritettiin
        ; Palaa after_trap:iin eikä 0x0501:een (joka on myös 0x0000)
        POP   R0               ; old_SR
        POP   R1               ; old_PC (hylkää)
        READ  R1, after_trap   ; palautusosoite
        PUSH  R1
        PUSH  R0
        IRET

.at 0x0500
        .db 0x00               ; 0x0000 = virheellinen opcode (GRP=0)

.expect_reg   R3, 0xFACE     ; INT 1 handler suoritettiin
.expect_reg   R1, 77         ; paluu after_trap:iin onnistui
.expect_flag  P, 1           ; kernel mode
