; =============================================================================
; test_store_preserves_flags.asm — STORE-variantit eivät muuta lippuja (1→1)
; Testataan kaikki kolme STORE-muotoa: [addr], [reg], [FP+n].
; Kun liput ovat 1 ennen STORE:a, ne pysyvät 1:nä sen jälkeen.
; =============================================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
READ  R0, 0x8000
READ  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; --- STORE [addr], reg ---
READ  R0, 0xABCD
STORE [0x0300], R0    ; kirjoita suoraan osoitteeseen; ei saa muuttaa lippuja

; --- STORE [reg], reg (epäsuora) ---
READ  R1, 0x0301      ; R1 = kohdeosoite
STORE [R1], R0        ; kirjoita R1:n osoittamaan paikkaan; ei saa muuttaa lippuja

; --- STORE [FP+n], reg (suhteellinen) ---
READ  FP, 0x0300
STORE [FP+2], R0      ; kirjoita [0x0302]; ei saa muuttaa lippuja

HALT

.expect_mem   0x0300, 0xABCD
.expect_mem   0x0301, 0xABCD
.expect_mem   0x0302, 0xABCD
.expect_flag  C, 1           ; STORE ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; STORE ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; STORE ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
