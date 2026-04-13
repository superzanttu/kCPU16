; =============================================================================
; test_copy_preserves_flags.asm — COPY ei muuta tilalippuja
; =============================================================================

        .origin 0x0200

        ; Aseta tunnetut liput: Z=1, C=1, N=0, V=0
        READ  R3, 0xFFFF
        READ  R4, 1
        ADD   R3, R4

        ; Lähdearvot
        READ  R0, 0xABCD
        STORE [0x0700], R0
        READ  R0, 0x1234
        STORE [0x0701], R0

        READ  R0, 0x0700
        READ  R1, 0x0701
        READ  R2, 0x0710
        COPY  R0, R1, R2

        HALT

.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 1
.expect_flag  V, 0

.expect_mem  0x0710, 0xABCD
.expect_mem  0x0711, 0x1234
