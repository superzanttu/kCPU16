; TESTI: CHIP-8 snake -moduuli latautuu ja näppäinkartta alustuu

.include "../../code/asm/chip-8/chip-8.asm"

.expect_mem 0x6200, 0x0016
.expect_mem 0x6201, 0x00D6
.expect_mem 0x6202, 0x0080
.expect_mem 0x4077, 0x0005
.expect_mem 0x4061, 0x0007
.expect_mem 0x4073, 0x0008
.expect_mem 0x4064, 0x0009
