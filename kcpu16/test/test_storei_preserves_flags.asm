; =============================================================================
; test_storei_preserves_flags.asm — STOREI-variantit säilyttävät liput (1→1)
; Testataan kaikki kolme STOREI-muotoa:
;   STORE [addr], imm       (STOREI: välitön suoraan osoitteeseen)
;   STORE [reg], imm        (STOREI_IND: välitön epäsuoraan osoitteeseen)
;   STORE [FP+offset], imm  (STOREI_REL: välitön FP-suhteelliseen)
; Kun liput ovat 1 ennen STOREI:tä, ne pysyvät 1:nä sen jälkeen.
; =============================================================================

        .origin 0x0200

        ; Aseta C=1, V=1, Z=1, N=0 ADD:lla
        JARI  R0, 0x8000
        JARI  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; --- STOREI [addr], imm ei saa muuttaa lippuja ---
        STORE [0x0300], 0x1234  ; välitön suoraan osoitteeseen

        ; --- STOREI_IND [reg], imm ei saa muuttaa lippuja ---
        JARI  R0, 0x0301        ; R0 = kohdeosoite (JARI ei muuta lippuja)
        STORE [R0], 0x5678      ; välitön epäsuoraan osoitteeseen

        ; --- STOREI_REL [FP+offset], imm ei saa muuttaa lippuja ---
        JARI  FP, 0x0300        ; FP = kanta (JARI ei muuta lippuja)
        STORE [FP+2], 0x9ABC    ; välitön FP-suhteelliseen

        HALT

.expect_mem   0x0300, 0x1234
.expect_mem   0x0301, 0x5678
.expect_mem   0x0302, 0x9ABC
.expect_flag  C, 1           ; STOREI ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; STOREI ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; STOREI ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
