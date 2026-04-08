; =============================================================================
; test_read_preserves_flags.asm — READ-variantit säilyttävät liput (1→1)
; Testataan kaikki kolme READ-muotoa:
;   JARI reg, [addr]      (READ suora)
;   JARI reg, [regS]      (READ_IND epäsuora)
;   JARI reg, [FP+imm]    (READ_REL FP-suhteellinen)
; Kun liput ovat 1 ennen JARI-käskyä, ne pysyvät 1:nä sen jälkeen.
; =============================================================================

        .origin 0x0200

        ; Tallenna testidataa muistiin etukäteen
        JARI  R0, 0xABCD
        STORE [0x0300], R0    ; muisti[0x0300] = 0xABCD

        ; Aseta C=1, V=1, Z=1, N=0 ADD:lla
        JARI  R0, 0x8000
        JARI  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; --- READ (suora) ei saa muuttaa lippuja ---
        JARI  R0, [0x0300]    ; R0 = 0xABCD; liput pysyvät ennallaan

        ; --- READ_IND (epäsuora) ei saa muuttaa lippuja ---
        JARI  R1, 0x0300      ; R1 = osoite (JARI ei muuta lippuja)
        JARI  R2, [R1]        ; R2 = muisti[0x0300] = 0xABCD; liput ennallaan

        ; --- READ_REL (FP-suhteellinen) ei saa muuttaa lippuja ---
        JARI  FP, 0x02FF      ; FP = 0x02FF (JARI ei muuta lippuja)
        JARI  R3, [FP+1]      ; R3 = muisti[0x0300] = 0xABCD; liput ennallaan

        HALT

.expect_reg   R0, 0xABCD
.expect_reg   R2, 0xABCD
.expect_reg   R3, 0xABCD
.expect_flag  C, 1           ; READ ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; READ ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; READ ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
