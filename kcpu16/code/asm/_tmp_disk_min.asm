        .origin 0x0200
        JUMP  main
        .include "lib-disk.asm"
test_filename:
        .dstr "TESTFILE"
test_data:
        .dw  0x1234, 0x5678
read_buf:
        .dw  0, 0, 0, 0, 0, 0, 0
read_buf_last:
        .dw  0
list_buf:
        .dw  0, 0, 0, 0

main:
        CALL  disk_format
        READ  R0, test_filename
        CALL  disk_create
        READ  R0, test_filename
        READ  R1, test_data
        READ  R2, 2
        CALL  disk_write

        ; Nyt lue takaisin
        READ  R0, test_filename
        READ  R1, read_buf
        READ  R2, 2
        CALL  disk_read
        HALT
; FAT tarkistukset:
.expect_storage  0x0100, 0xFFFF   ; fat[0] = boot varattu
.expect_storage  0x0101, 0xFFFF   ; fat[1] = FAT varattu
.expect_storage  0x0102, 0xFFFF   ; fat[2] = hakemisto varattu
.expect_storage 0x0103, 0xFFFF
.expect_storage 0x0300, 0x1234
.expect_storage 0x0301, 0x5678
; disk_read tulos — lisätty .expect_reg (ei tuettu) → käytetään mem
; disk_read:n pitäisi löytää tiedosto ja kirjoittaa read_buf
; Tarkistetaan onko data oikein:
.expect_mem 0x0984, 0x1234
.expect_mem 0x0985, 0x5678
; disk_read palauttaa R0=0 (DISK_OK) - ei voida tarkistaa rekisteriä suoraan
; Hakemistomerkintä (blokki 2 = 0x0200):
; status=1, nimi=TESTFILE, size=2, first_block=3
.expect_storage 0x0200, 1       ; status = aktiivinen
.expect_storage 0x0211, 2       ; size (offset 17)
.expect_storage 0x0216, 3       ; first_block (offset 22)

