; =============================================================================
; test_call_ret_preserves_flags.asm — CALL/RET eivät muuta lippuja (1→1)
; Kun liput ovat 1 ennen CALL:ia, ne pysyvät 1:nä RET:n jälkeen.
; =============================================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; CALL/RET eivät saa muuttaa lippuja
CALL  aliohjelma
CALL  aliohjelma      ; kutsutaan kahdesti

HALT

aliohjelma:
; Ei aritmetiikkaa — käytetään LOADia joka myös säilyttää liput
LOAD  R0, 0x1234
RET

.expect_reg   R0, 0x1234
.expect_flag  C, 1           ; CALL/RET ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; CALL/RET ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; CALL/RET ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
