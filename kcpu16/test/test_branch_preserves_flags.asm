; =============================================================================
; test_branch_preserves_flags.asm — haarautumiskäskyt eivät muuta lippuja (1→1)
; Testataan JUMP, JZ (otettu), JNZ (ohitettu), JLT, JGT, JLE, JGE.
; Kun liput ovat 1, mikään haarautuminen ei saa nollata niitä.
; =============================================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
READ  R0, 0x8000
READ  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; --- JUMP (ehdoton) ---
JUMP  j1
j1:

; --- JZ otettu (Z=1) ---
JZ    j2
j2:

; --- JNZ ohitettu (Z=1 → ei hypätä) ---
JNZ   skip1
skip1:

; --- JLE otettu (Z=1 → ≤ pitää) ---
JLE   j3
j3:

; --- JGE ohitettu (Z=1 → ≥ pitää myös; Z=1 joten JGE pitäisi ottaa myös) ---
JGE   j4
j4:

HALT

.expect_flag  C, 1           ; haarautuminen ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; haarautuminen ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; haarautuminen ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
