; =============================================================================
; test_mul_clears_flags.asm — MUL nollaa liput (1→0)
; Varmistaa, että MUL kirjoittaa C, V, Z, N aina uudelleen.
; Kun lippu on 1 ja tulos ei aiheuta ylivuotoa/nollia, lippu menee 0:aan.
; =============================================================================

.origin 0x0200

; --- Vaihe 1: aseta C=1 ADD:lla ---
JARI  R0, 0xFFFF
JARI  R1, 1
ADD   R0, R1          ; 0xFFFF + 1 = 0x10000 → C=1, Z=1

; --- Vaihe 2: MUL ei-nollatuloksella → C: 1→0, Z: 1→0 ---
JARI  R0, 6
JARI  R1, 7
MUL   R0, R1          ; 6 × 7 = 42: C=0, V=0, Z=0, N=0

; --- Vaihe 3: aseta N=1 MUL:lla (tulos 0xC000 = negatiivinen) ---
; 3 × 0x4000 = 0xC000: N=1 (bit 15 asetettu), C=0, V=0, Z=0
JARI  R0, 3
JARI  R1, 0x4000
MUL   R0, R1          ; 0xC000: N=1

; --- Vaihe 4: MUL pienillä arvoilla → N: 1→0 ---
JARI  R0, 2
JARI  R1, 4
MUL   R0, R1          ; 2 × 4 = 8: C=0, V=0, Z=0, N=0

HALT

.expect_reg   R0, 8
.expect_flag  C, 0           ; ylivuoto: 1→0
.expect_flag  V, 0           ; merkkiylivuoto: 1→0
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0           ; negatiivinen: 1→0
