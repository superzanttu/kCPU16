; =============================================================================
; test_calli_preserves_flags.asm — CALLI/RET ei muuta lippuja
; Asetetaan liput ensin aritmetiikalla, sen jälkeen CALLI:n ja RET:n
; tulee säilyttää ne muuttumattomina (sama kuin CALL/RET).
; =============================================================================

        .origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
        LOAD  R0, 0x8000
        LOAD  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        LOAD  R2, 0
        CALLI R2, aliohjelma  ; yksi kohde, indeksi 0
        CALLI R2, aliohjelma  ; kutsutaan kahdesti

        HALT

aliohjelma:
        LOAD  R0, 0x1234      ; ei aritmetiikkaa, ei muuta lippuja
        RET

.expect_reg   R0, 0x1234
.expect_flag  C, 1
.expect_flag  V, 1
.expect_flag  Z, 1
.expect_flag  N, 0
