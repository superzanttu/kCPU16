; TESTI: CHIP-8 snake vastaanottaa näppäinkeskeytyksen ja päivittää keymaskin

.include "../../code/asm/chip-8/chip-8.asm"

.inject_key 0x77   ; 'w' -> CHIP-8 key 5

; CHIP8_KEYMASK ja CHIP8_LAST_KEY ovat chip-8.asm:n tilamuuttujia.
.expect_mem 0x0217, 0x0020
.expect_mem 0x0219, 0x0005
.expect_mem 0x0218, 0xFFFF

; Ohjelman pitää edelleen edetä normaalisti ja piirtää ruutuun.
.expect_mem 0x0213, 0x05CE
.expect_mem 0x5108, 0x0001