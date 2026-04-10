; =============================================================================
; test_add_clears_flags.asm — ADD nollaa liput (1→0)
; Varmistaa, että ADD kirjoittaa liput aina uudelleen: kun lippu on 1
; ja tulos ei aseta sitä, lippu menee 0:aan.
; Testataan C, V, Z, N kukin suunnassa 1→0.
; =============================================================================

.origin 0x0200

; --- Vaihe 1: aseta C=1, V=1, Z=1 kerralla ---
; 0x8000 + 0x8000 = 0x10000 → katkaistu 0x0000: C=1, V=1, Z=1, N=0
READ  R0, 0x8000
READ  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; --- Vaihe 2: ADD joka ei aiheuta carry/overflow eikä nollatulosta ---
; C: 1→0, V: 1→0, Z: 1→0
READ  R0, 5
READ  R1, 3
ADD   R0, R1          ; 5 + 3 = 8: C=0, V=0, Z=0, N=0

; --- Vaihe 3: aseta N=1 ---
; 0x4001 + 0x4001 = 0x8002: N=1, V=1, C=0, Z=0
READ  R0, 0x4001
READ  R1, 0x4001
ADD   R0, R1          ; N=1, V=1, C=0, Z=0

; --- Vaihe 4: ADD joka nollaa myös N ---
; N: 1→0, V: 1→0
READ  R0, 1
READ  R1, 1
ADD   R0, R1          ; 1 + 1 = 2: C=0, V=0, Z=0, N=0

HALT

.expect_reg   R0, 2
.expect_flag  C, 0           ; carry: 1→0
.expect_flag  V, 0           ; overflow: 1→0
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0           ; negatiivinen: 1→0
