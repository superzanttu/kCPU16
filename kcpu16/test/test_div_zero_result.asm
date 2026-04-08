; =============================================================================
; test_div_zero_result.asm — DIV ja Z-lippu + C/V-säilyminen
; 1) Nollatulos: 0 / n = 0 → Z=1 (0→1)
; 2) Z: 1→0 kun tulos ei-nolla
; 3) DIV ei kosketa C- eikä V-lippua: ne säilyvät muuttumattomina (1→1)
; =============================================================================

.origin 0x0200

; --- Vaihe 1: aseta C=1, V=1 ADD:lla ---
JARI  R0, 0x8000
JARI  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; --- Vaihe 2: DIV nollatuloksella → Z pysyy 1; C, V säilyvät ---
; DIV ei kutsu set_carry_overflow → C ja V eivät muutu
JARI  R0, 0
JARI  R1, 5
DIV   R0, R1          ; 0 / 5 = 0: Z=1, N=0; C ja V ennallaan (1)

; --- Vaihe 3: DIV ei-nollatuloksella → Z: 1→0; C, V yhä ennallaan ---
JARI  R0, 15
JARI  R1, 3
DIV   R0, R1          ; 15 / 3 = 5: Z=0, N=0; C ja V edelleen 1

HALT

.expect_reg   R0, 5
.expect_flag  Z, 0           ; nollatulos: 1→0
.expect_flag  N, 0
.expect_flag  C, 1           ; DIV säilyttää C (1→1)
.expect_flag  V, 1           ; DIV säilyttää V (1→1)
