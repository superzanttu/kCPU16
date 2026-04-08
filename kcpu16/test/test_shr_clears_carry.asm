; =============================================================================
; test_shr_clears_carry.asm — SHR nollaa C-lipun (1→0)
; Varmistaa, että SHR kirjoittaa C-lipun uudelleen myös kun se oli 1
; eikä uusi siirto tuota carry-bittiä.
; =============================================================================

.origin 0x0200

; --- Vaihe 1: SHR joka asettaa C=1 ---
; 0x0001 siirrettynä oikealle 1: bit 0 (=1) siirtyy ulos → C=1
; tulos = 0x0000, Z=1
JARI  R0, 0x0001
JARI  R1, 1
SHR   R0, R1          ; 0x0001 >> 1 = 0x0000: C=1, Z=1, N=0

; --- Vaihe 2: SHR arvolle jonka bit 0 = 0 → C: 1→0 ---
; 0x0002 >> 1 = 0x0001: bit 0 of 0x0002 = 0 → C=0
JARI  R0, 0x0002
JARI  R1, 1
SHR   R0, R1          ; 0x0002 >> 1 = 0x0001: C=0, Z=0, N=0

HALT

.expect_reg   R0, 1
.expect_flag  C, 0           ; carry: 1→0
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0
