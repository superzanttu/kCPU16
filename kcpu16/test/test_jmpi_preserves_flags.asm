; =============================================================================
; test_jmpi_preserves_flags.asm — JMPI ei muuta lippuja
; Asetetaan liput ensin aritmetiikalla, sen jälkeen JMPI:n tulee
; säilyttää ne muuttumattomina.
; =============================================================================

        .origin 0x0200

; Aseta C=1, V=1, Z=1, N=0  (0x8000 + 0x8000 = 0x10000 → 0 carry overflow)
        READ  R0, 0x8000
        READ  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; JMPI ei saa muuttaa lippuja
        READ  R2, 0
        JMPI  R2, target

target:
        HALT

.expect_flag  C, 1
.expect_flag  V, 1
.expect_flag  Z, 1
.expect_flag  N, 0
