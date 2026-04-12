.bootblock "../storage/test_bootblock_boot.dsk", overwrite=1, boot=1
    READ  R0, 0xBEEF
    STORE [0x0100], R0
    JUMP  0x0200
.endbootblock

.origin 0x0200

    READ  R1, [0x0100]
    READ  R2, 0xBEEF
    CMP   R1, R2
    JNZ   fail

    READ  R3, 0x1234
    HALT

fail:
    READ  R3, 0xDEAD
    HALT

.expect_reg R3, 0x1234
.expect_mem 0x0100, 0xBEEF