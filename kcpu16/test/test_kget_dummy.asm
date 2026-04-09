; =============================================================
; TESTI: Näppäimistö MMIO (KBD_DATA ja KBD_STATUS)
; =============================================================
; Testaa näppäimistön MMIO-osoitteet kun puskuri on tyhjä.
;
; KBD_DATA   ($0020): lukeminen palauttaa 0 jos puskuri on tyhjä
; KBD_STATUS ($0021): lukeminen palauttaa 0 jos puskuri on tyhjä
;
; Näppäimistön varsinainen toiminta (INT 6 -keskeytys) testataan
; erikseen test_keyboard_interrupt.asm:ssä.
; =============================================================

.origin 0x0200

; Lue KBD_DATA ($0020) kun puskuri tyhjä -> 0
LOAD  R0, [KBD_DATA]     ; R0 = mem[$0020] = 0 (tyhjä puskuri)

; Lue KBD_STATUS ($0021) kun puskuri tyhjä -> 0
LOAD  R1, [KBD_STATUS]   ; R1 = mem[$0021] = 0 (tyhjä puskuri)

HALT

.expect_reg   R0, 0          ; KBD_DATA tyhjänä = 0
.expect_reg   R1, 0          ; KBD_STATUS tyhjänä = 0
