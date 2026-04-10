; test_include_basic.asm — .include-direktiivin perustoiminnallisuus.
; Testataan etta liitetyn tiedoston koodi toimii ja vakio nakyy.

        .origin 0x0200

START:
        READ  R0, 5
        CALL  ADD_TEN       ; R0 = 5 + 10 = 15
        HALT

        .include "includes/include_lib.asm"

.expect_reg  R0, 15
.expect_flag Z, 0
.expect_flag N, 0
