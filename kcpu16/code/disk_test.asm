; =============================================================================
; disk_test.asm — Tallennuslaitekirjaston (lib-disk.asm) testaus
; =============================================================================
;
; KUVAUS:
;   Demonstroi lib-disk.asm:n toiminnot:
;     1. Alustus (disk_format)
;     2. Tiedoston luominen (disk_create)
;     3. Datan kirjoittaminen (disk_write)
;     4. Datan lukeminen takaisin (disk_read)
;     5. Tiedoston metatietojen lukeminen (disk_stat)
;     6. Tiedostojen listaaminen (disk_list)
;     7. Tiedoston poistaminen (disk_delete)
;
; TULOSTUS:
;   Näyttää testin etenemisen ja tulostaa OK/FAIL tekstinä näytölle.
;   Ylin rivi: otsikko
;   Rivit 1–7: kukin testi
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/disk_test.asm
;
; HUOM:
;   Tarvitsee liitetyn tallennuslaitteen (.dsk).
;   Jos tallennuslaitetta ei ole, DREAD/DWRITE aiheuttavat suoritusvirheen.
;   Käynnistä: python main.py --run kcpu16/code/disk_test.asm --disk kcpu16/storage/zero.dsk
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; =============================================================================
; Kirjasto
; =============================================================================
        .include "lib-disk.asm"

; =============================================================================
; Testausdata
; =============================================================================

; Testitiedoston nimi
test_filename:
        .dstr "TESTFILE"

; Testausdata (8 sanaa)
test_data:
        .dw  0x1234, 0x5678, 0xABCD, 0xEF01
        .dw  0x2345, 0x6789, 0xBCDE, 0xF012

; Lukupuskuri (8 sanaa)
read_buf:
        .dw  0, 0, 0, 0,   0, 0, 0, 0

; Metatietopuskuri (6 sanaa: koko, luontivuosi, luontimd, muokvuosi, muokmd, 1.blokki)
stat_buf:
        .dw  0, 0, 0, 0, 0, 0

; Listauspuskuri (8 osoitinta)
list_buf:
        .dw  0, 0, 0, 0,   0, 0, 0, 0

; Näyttökonstan­tit
.const SCREEN_ROW0,  0xF800   ; Rivi 0, sarake 0
.const SCREEN_ROW1,  0xF850   ; Rivi 1, sarake 0 (80 saraketta/rivi)
.const SCREEN_ROW2,  0xF8A0   ; Rivi 2
.const SCREEN_ROW3,  0xF8F0   ; Rivi 3
.const SCREEN_ROW4,  0xF940   ; Rivi 4
.const SCREEN_ROW5,  0xF990   ; Rivi 5
.const SCREEN_ROW6,  0xF9E0   ; Rivi 6
.const SCREEN_ROW7,  0xFA30   ; Rivi 7
.const SCREEN_ROW8,  0xFA80   ; Rivi 8

; Värimäärittely: valkoinen teksti mustalla taustalla = 0xE000
.const COLOR_WHITE_TEXT, 0xE000

; Testitulosten tallennus (0 = OK, ≠0 = FAIL)
test_results:
        .dw  0, 0, 0, 0, 0, 0, 0

; =============================================================================
; Apualiohjelmat
; =============================================================================

; write_str — Kirjoita null-terminoitu merkkijono VRAMiin
; Sisään: R10 = VRAM-osoitin, R11 = merkkijonon osoitin
; Ulos: R10 = osoitin merkin jälkeiseen kohtaan
; Clobbers: R10, R11, R12, R13
write_str:
        READ  R12, 1
        READ  R13, 0
_ws_loop:
        READ  R13, [R11]
        CMP   R13, R13
        READ  R14, 0
        CMP   R13, R14
        JZ    _ws_done
        OR    R13, R15           ; lisää värimäärittely
        STORE [R10], R13
        ADD   R10, R12
        ADD   R11, R12
        JUMP  _ws_loop
_ws_done:
        RET

; write_str_at — Kirjoita merkkijono tietylle VRAMriville
; Sisään: R0 = VRAM-rivin osoite, R1 = merkkijonon RAM-osoite
; Clobbers: R10, R11, R12, R13, R14, R15
write_str_at:
        CPY   R10, R0
        CPY   R11, R1
        READ  R15, COLOR_WHITE_TEXT
        CALL  write_str
        RET

; print_ok — Kirjoita " OK" rivin loppuun
; Sisään: R10 = VRAM-osoitin (rivin loppu)
print_ok:
        READ  R11, str_ok
        READ  R15, COLOR_WHITE_TEXT
        CALL  write_str
        RET

; print_fail — Kirjoita " FAIL" rivin loppuun
; Sisään: R10 = VRAM-osoitin (rivin loppu)
print_fail:
        READ  R11, str_fail
        READ  R15, 0xC000       ; punainen teksti
        CALL  write_str
        RET

str_ok:
        .dstr " OK"

str_fail:
        .dstr " FAIL"

str_title:
        .dstr "DISK LIBRARY TEST"

str_test1:
        .dstr "1. disk_format"

str_test2:
        .dstr "2. disk_create"

str_test3:
        .dstr "3. disk_write"

str_test4:
        .dstr "4. disk_read"

str_test5:
        .dstr "5. disk_stat (koko)"

str_test6:
        .dstr "6. disk_list (1 tiedosto)"

str_test7:
        .dstr "7. disk_delete"

; =============================================================================
; check_result — Tarkista tulos ja tulosta OK/FAIL
;
; Sisään: R0 = tulos (0 = OK, ≠0 = FAIL)
;         R10 = VRAM-osoitin (rivin loppuun)
; =============================================================================
check_result:
        READ  R1, 0
        CMP   R0, R1
        JNZ   _cr_fail
        CALL  print_ok
        RET
_cr_fail:
        CALL  print_fail
        RET

; =============================================================================
; main — Pääohjelma
; =============================================================================
main:
        ; Alusta näyttö
        READ  R0, SCREEN_ROW0
        READ  R1, str_title
        CALL  write_str_at

        ; --- Testi 1: disk_format ---
        READ  R0, SCREEN_ROW1
        READ  R1, str_test1
        CALL  write_str_at        ; R10 = osoitin rivin loppuun

        CALL  disk_format         ; R0 = DISK_OK tai virhe
        CALL  check_result

        ; --- Testi 2: disk_create ---
        READ  R0, SCREEN_ROW2
        READ  R1, str_test2
        CALL  write_str_at

        READ  R0, test_filename
        CALL  disk_create
        CALL  check_result

        ; --- Testi 3: disk_write ---
        READ  R0, SCREEN_ROW3
        READ  R1, str_test3
        CALL  write_str_at

        READ  R0, test_filename
        READ  R1, test_data
        READ  R2, 8               ; 8 sanaa
        CALL  disk_write
        CALL  check_result

        ; --- Testi 4: disk_read ---
        READ  R0, SCREEN_ROW4
        READ  R1, str_test4
        CALL  write_str_at

        ; Nollaa lukupuskuri ensin
        FILL  read_buf, read_buf_end, 0

        READ  R0, test_filename
        READ  R1, read_buf
        READ  R2, 8
        CALL  disk_read          ; R0 = DISK_OK jos onnistui

        ; Tarkista ensin disk_read:n paluuarvo
        PUSH  R0
        READ  R1, 0
        CMP   R0, R1
        JNZ   _t4_fail

        ; Verifoi luettu data
        READ  R3, test_data
        READ  R4, read_buf
        READ  R5, 8              ; 8 sanaa vertailtavaksi
        READ  R6, 1
        READ  R7, 0
_t4_verify:
        CMP   R5, R7
        JZ    _t4_ok
        READ  R8, [R3]
        READ  R9, [R4]
        CMP   R8, R9
        JNZ   _t4_fail
        ADD   R3, R6
        ADD   R4, R6
        SUB   R5, R6
        JUMP  _t4_verify
_t4_ok:
        POP   R0
        READ  R1, 0
        CPY   R0, R1             ; R0 = 0 = OK
        JUMP  _t4_done
_t4_fail:
        POP   R0
        READ  R0, 1              ; R0 = 1 = FAIL
_t4_done:
        CALL  check_result

        ; --- Testi 5: disk_stat ---
        READ  R0, SCREEN_ROW5
        READ  R1, str_test5
        CALL  write_str_at

        READ  R0, test_filename
        READ  R1, stat_buf
        CALL  disk_stat
        READ  R1, 0
        CMP   R0, R1
        JNZ   _t5_fail

        ; Tarkista koko: stat_buf[0] pitäisi olla 8
        READ  R3, [stat_buf]
        READ  R4, 8
        CMP   R3, R4
        JNZ   _t5_fail
        READ  R0, 0
        JUMP  _t5_done
_t5_fail:
        READ  R0, 1
_t5_done:
        CALL  check_result

        ; --- Testi 6: disk_list ---
        READ  R0, SCREEN_ROW6
        READ  R1, str_test6
        CALL  write_str_at

        READ  R0, list_buf
        READ  R1, 8
        CALL  disk_list          ; R0 = löytyneiden tiedostojen määrä

        ; Pitää löytyä tasan 1 tiedosto
        READ  R1, 1
        CMP   R0, R1
        JNZ   _t6_fail
        READ  R0, 0
        JUMP  _t6_done
_t6_fail:
        READ  R0, 1
_t6_done:
        CALL  check_result

        ; --- Testi 7: disk_delete ---
        READ  R0, SCREEN_ROW7
        READ  R1, str_test7
        CALL  write_str_at

        READ  R0, test_filename
        CALL  disk_delete
        READ  R1, 0
        CMP   R0, R1
        JNZ   _t7_fail

        ; Varmista poistettu: disk_find palauttaa DISK_ERR_NOT_FOUND
        READ  R0, test_filename
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _t7_fail
        READ  R0, 0
        JUMP  _t7_done
_t7_fail:
        READ  R0, 1
_t7_done:
        CALL  check_result

        ; --- Kaikki testit suoritettu ---
        READ  R0, SCREEN_ROW8
        READ  R1, str_done
        CALL  write_str_at

        HALT

str_done:
        .dstr "Kaikki testit suoritettu."

; Merkki puskurin lopulle (FILL-käskyä varten)
read_buf_end:

; =============================================================================
; Tarkistukset (testrunner)
; =============================================================================
; read_buf:ssa pitää olla sama data kuin test_data:ssa disk_read:n jälkeen.
; Osoitteet: read_buf=0x0983 (assemblointihetkellä tarkistettu --asm:llä)
.expect_mem  0x0983, 0x1234
.expect_mem  0x0984, 0x5678
.expect_mem  0x0985, 0xABCD
.expect_mem  0x0986, 0xEF01
.expect_mem  0x0987, 0x2345
.expect_mem  0x0988, 0x6789
.expect_mem  0x0989, 0xBCDE
.expect_mem  0x098A, 0xF012
; FAT: blokki 1, sana 3 = 0xFFFF (blokki 3 varattu DISK_EOF:lla)
.expect_storage  0x0103, 0xFFFF
