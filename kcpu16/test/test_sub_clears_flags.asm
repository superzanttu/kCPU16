; =============================================================================
; test_sub_clears_flags.asm — SUB nollaa liput (1→0)
; Varmistaa, että SUB kirjoittaa liput aina uudelleen: kun lippu on 1
; ja tulos ei aseta sitä, lippu menee 0:aan.
; Testataan C, V, N suunnassa 1→0 sekä Z suunnassa 1→0.
; =============================================================================

.origin 0x0200

; --- Vaihe 1: aseta C=1, V=1, N=1 SUB:lla (borrow + overflow) ---
; 1 - 0x8000: a=1, b=0x8000
;   a < b → C=1 (borrow)
;   signed: +1 − (−32768) = +32769 ylittää +32767 → V=1
;   tulos = 1 − 0x8000 + 0x10000 = 0x8001 → N=1
READ  R0, 1
READ  R1, 0x8000
SUB   R0, R1          ; C=1, V=1, N=1, Z=0

; --- Vaihe 2: SUB joka tuottaa Z=1 ---
; C: 1→0, V: 1→0, N: 1→0, Z: 0→1
READ  R0, 42
READ  R1, 42
SUB   R0, R1          ; 42 − 42 = 0: C=0, V=0, Z=1, N=0

; --- Vaihe 3: SUB joka nollaa Z ---
; Z: 1→0
READ  R0, 10
READ  R1, 3
SUB   R0, R1          ; 10 − 3 = 7: C=0, V=0, Z=0, N=0

HALT

.expect_reg   R0, 7
.expect_flag  C, 0           ; borrow: 1→0
.expect_flag  V, 0           ; overflow: 1→0
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0           ; negatiivinen: 1→0
