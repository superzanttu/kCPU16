; test_include_const.asm — .include:n vakio nakyy paatiedostossa.

        .origin 0x0200

        LOAD  R0, LIB_CONST     ; R0 = 99
        HALT

        .include "includes/include_lib.asm"

.expect_reg  R0, 99
