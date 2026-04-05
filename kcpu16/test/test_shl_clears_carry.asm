; =============================================================================
; test_shl_clears_carry.asm — SHL nollaa C-lipun (1→0)
; Varmistaa, että SHL kirjoittaa C-lipun uudelleen myös kun se oli 1
; eikä uusi siirto tuota carry-bittiä.
; =============================================================================

.origin 0x0200

; --- Vaihe 1: SHL joka asettaa C=1 ---
; 0x8000 siirrettynä vasemmalle 1: bit 15 (=1) siirtyy ulos → C=1
; tulos = 0x0000, Z=1
LOAD  R0, 0x8000
LOAD  R1, 1
SHL   R0, R1          ; 0x8000 << 1 = 0x0000: C=1, Z=1, N=0

; --- Vaihe 2: SHL arvolle jonka bit 15 = 0 → C: 1→0 ---
; 0x0001 << 1 = 0x0002: bit 15 of 0x0001 = 0 → C=0
LOAD  R0, 0x0001
LOAD  R1, 1
SHL   R0, R1          ; 0x0001 << 1 = 0x0002: C=0, Z=0, N=0

HALT

.expect_reg   R0, 2
.expect_flag  C, 0           ; carry: 1→0
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0
