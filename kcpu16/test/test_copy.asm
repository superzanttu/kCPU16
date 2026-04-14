; =============================================================================
; test_copy.asm — COPY regStart, regEnd, regDst
; Kopioi muistialueen [regStart..regEnd] kohdeosoitteeseen regDst.
; =============================================================================

        .origin 0x0200

        ; Lähde 0x0400-0x0403
        READ  R0, 0x1111
        STORE [0x0400], R0
        READ  R0, 0x2222
        STORE [0x0401], R0
        READ  R0, 0x3333
        STORE [0x0402], R0
        READ  R0, 0x4444
        STORE [0x0403], R0

        READ  R0, 0x0400
        READ  R1, 0x0403
        READ  R2, 0x0500
        COPY  R0, R1, R2

        HALT

.expect_mem  0x0500, 0x1111
.expect_mem  0x0501, 0x2222
.expect_mem  0x0502, 0x3333
.expect_mem  0x0503, 0x4444
