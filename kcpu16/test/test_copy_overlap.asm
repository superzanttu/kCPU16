; =============================================================================
; test_copy_overlap.asm — COPY toimii päällekkäisillä lähde/kohdealueilla.
; =============================================================================

        .origin 0x0200

        ; Alku: 0x0300..0x0305 = 1..6
        READ  R0, 1
        STORE [0x0300], R0
        READ  R0, 2
        STORE [0x0301], R0
        READ  R0, 3
        STORE [0x0302], R0
        READ  R0, 4
        STORE [0x0303], R0
        READ  R0, 5
        STORE [0x0304], R0
        READ  R0, 6
        STORE [0x0305], R0

        ; Kopioi 0x0300..0x0305 -> 0x0302..0x0307 (overlap)
        READ  R0, 0x0300
        READ  R1, 0x0305
        READ  R2, 0x0302
        COPY  R0, R1, R2

        HALT

.expect_mem  0x0300, 1
.expect_mem  0x0301, 2
.expect_mem  0x0302, 1
.expect_mem  0x0303, 2
.expect_mem  0x0304, 3
.expect_mem  0x0305, 4
.expect_mem  0x0306, 5
.expect_mem  0x0307, 6
