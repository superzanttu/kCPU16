; TESTI: CHIP-8 snake etenee ja piirtää alkuruudun framebufferiin

.include "../../code/asm/chip-8/chip-8.asm"

; CHIP8_PC ja CHIP8_WAIT_VX ovat chip-8.asm:n tilamuuttujia.
.expect_mem 0x0213, 0x05CE
.expect_mem 0x0218, 0xFFFF

; Hajautettu otos snake-ROMin piirtämästä 64x32 framebufferista 1 000 000 syklin jälkeen.
.expect_mem 0x5108, 0x0001
.expect_mem 0x5149, 0x0001
.expect_mem 0x518D, 0x0001
.expect_mem 0x5208, 0x0001
.expect_mem 0x5270, 0x0001
.expect_mem 0x52EE, 0x0001
.expect_mem 0x55AA, 0x0001