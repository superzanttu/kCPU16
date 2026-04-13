; =============================================================================
; test_copy_wrap.asm — COPY tukee wrap-around lähdealuetta.
; =============================================================================

        .origin 0x0200

        READ  R0, 0xAAAA
        STORE [0xFFFE], R0
        READ  R0, 0xBBBB
        STORE [0xFFFF], R0
        READ  R0, 0xCCCC
        STORE [0x0000], R0
        READ  R0, 0xDDDD
        STORE [0x0001], R0

        READ  R0, 0xFFFE
        READ  R1, 0x0001
        READ  R2, 0x0600
        COPY  R0, R1, R2

        HALT

.expect_mem  0x0600, 0xAAAA
.expect_mem  0x0601, 0xBBBB
.expect_mem  0x0602, 0xCCCC
.expect_mem  0x0603, 0xDDDD
