; =============================================================================
; test_push_pop_preserves_flags.asm — PUSH/POP eivät muuta lippuja (1→1)
; Kun liput ovat 1 ennen PUSH/POP:ia, ne pysyvät 1:nä sen jälkeen.
; =============================================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; Pino-operaatiot eivät saa muuttaa lippuja
LOAD  R0, 99
PUSH  R0              ; push 99 → liput säilyvät
LOAD  R0, 42
PUSH  R0              ; push 42 → liput säilyvät
POP   R1              ; pop → R1=42, liput säilyvät
POP   R2              ; pop → R2=99, liput säilyvät

HALT

.expect_reg   R1, 42
.expect_reg   R2, 99
.expect_flag  C, 1           ; PUSH/POP ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; PUSH/POP ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; PUSH/POP ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
