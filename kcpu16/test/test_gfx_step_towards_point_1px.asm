; =============================================================================
; test_gfx_step_towards_point_1px.asm — 1 px / frame geometria-apuri.
; =============================================================================

        .origin 0x0200

        JUMP  main

        .include "../../code/asm/lib/lib-gfx.asm"

main:
        ; Pelkka x-liike
        READ  R0, 10
        READ  R1, 10
        READ  R2, 13
        READ  R3, 10
        CALL  gfx_step_towards_point_1px
        STORE [0x3030], R0
        STORE [0x3031], R1
        STORE [0x3032], R2

        ; Pelkka y-liike
        READ  R0, 10
        READ  R1, 10
        READ  R2, 10
        READ  R3, 8
        CALL  gfx_step_towards_point_1px
        STORE [0x3033], R0
        STORE [0x3034], R1
        STORE [0x3035], R2

        ; X priorisoidaan jos abs(dx) > abs(dy)
        READ  R0, 10
        READ  R1, 10
        READ  R2, 13
        READ  R3, 12
        CALL  gfx_step_towards_point_1px
        STORE [0x3036], R0
        STORE [0x3037], R1
        STORE [0x3038], R2

        ; Y priorisoidaan jos abs(dy) > abs(dx)
        READ  R0, 10
        READ  R1, 10
        READ  R2, 12
        READ  R3, 14
        CALL  gfx_step_towards_point_1px
        STORE [0x3039], R0
        STORE [0x303A], R1
        STORE [0x303B], R2

        ; Tasatilanne: x priorisoidaan
        READ  R0, 4
        READ  R1, 4
        READ  R2, 6
        READ  R3, 6
        CALL  gfx_step_towards_point_1px
        STORE [0x303C], R0
        STORE [0x303D], R1
        STORE [0x303E], R2

        ; Jo perilla
        READ  R0, 5
        READ  R1, 5
        READ  R2, 5
        READ  R3, 5
        CALL  gfx_step_towards_point_1px
        STORE [0x303F], R0
        STORE [0x3040], R1
        STORE [0x3041], R2

        ; Viimeinen askel merkitsee kohteen saavutetuksi
        READ  R0, 7
        READ  R1, 7
        READ  R2, 8
        READ  R3, 7
        CALL  gfx_step_towards_point_1px
        STORE [0x3042], R0
        STORE [0x3043], R1
        STORE [0x3044], R2

        HALT

.expect_mem 0x3030, 11
.expect_mem 0x3031, 10
.expect_mem 0x3032, 0
.expect_mem 0x3033, 10
.expect_mem 0x3034, 9
.expect_mem 0x3035, 0
.expect_mem 0x3036, 11
.expect_mem 0x3037, 10
.expect_mem 0x3038, 0
.expect_mem 0x3039, 10
.expect_mem 0x303A, 11
.expect_mem 0x303B, 0
.expect_mem 0x303C, 5
.expect_mem 0x303D, 4
.expect_mem 0x303E, 0
.expect_mem 0x303F, 5
.expect_mem 0x3040, 5
.expect_mem 0x3041, 1
.expect_mem 0x3042, 8
.expect_mem 0x3043, 7
.expect_mem 0x3044, 1
