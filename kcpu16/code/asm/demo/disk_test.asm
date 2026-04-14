; =============================================================================
; disk_test.asm — Tallennuslaitekirjaston (lib-disk.asm) testaus
; =============================================================================
;
; KUVAUS:
;   Demonstroi lib-disk.asm:n toiminnot:
;     1. Alustus (disk_format)
;     2. Hakemiston luominen (disk_mkdir)
;     3. Tiedoston luominen (disk_create)
;     4. Datan kirjoittaminen (disk_write)
;     5. Datan lukeminen takaisin (disk_read)
;     6. Tiedoston metatietojen lukeminen (disk_stat)
;     7. Tiedostojen/hakemistojen listaaminen (disk_list)
;     8. Levy-eheyden tarkistus (disk_check)
;     9. Tiedoston poistaminen (disk_delete)
;
; TULOSTUS:
;   Näyttää testin etenemisen ja tulostaa OK/FAIL tekstinä näytölle.
;   Ylin rivi: otsikko
;   Rivit 1–9: kukin testi
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

; Testihakemiston nimi
test_dirname:
        .dstr "DIR1"

; Testitiedoston nimi
test_filename:
        .dstr "TESTFILE"

; Testausdata (8 sanaa)
test_data:
        .dw  0x1234, 0x5678, 0xABCD, 0xEF01
        .dw  0x2345, 0x6789, 0xBCDE, 0xF012

; Lukupuskuri (8 sanaa)
; FILL-käskyä varten: read_buf_last osoittaa viimeiseen sanaan (inklusiivinen)
read_buf:
        .dw  0, 0, 0, 0,   0, 0, 0
read_buf_last:
        .dw  0

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
.const SCREEN_ROW9,  0xFAD0   ; Rivi 9
.const SCREEN_ROW10, 0xFB20   ; Rivi 10

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
        READ  R12, 1              ; R12 = 1 (askeleen leveys ADD-käskyille)
        READ  R13, 0              ; (käyttämätön — R13 ylikirjoitetaan heti silmukassa)
_ws_loop:
        READ  R13, [R11]          ; R13 = seuraava merkki merkkijonosta
        CMP   R13, R13            ; (tyhjä vertailu — asettaa aina Z; vastaus ei käytössä)
        READ  R14, 0              ; R14 = 0 (null-vertailuarvo)
        CMP   R13, R14            ; onko merkki null (merkkijonon loppu)?
        JZ    _ws_done
        OR    R13, R15            ; lisätään värimäärittely (R15 = väriattribuutti)
        STORE [R10], R13          ; kirjoita merkki+väri VRAMiin
        ADD   R10, R12            ; VRAM-osoitin eteenpäin
        ADD   R11, R12            ; merkkijono-osoitin eteenpäin
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
        .dstr "2. disk_mkdir"

str_test3:
        .dstr "3. disk_create"

str_test4:
        .dstr "4. disk_write"

str_test5:
        .dstr "5. disk_read"

str_test6:
        .dstr "6. disk_stat (koko)"

str_test7:
        .dstr "7. disk_list (2 kohdetta)"

str_test8:
        .dstr "8. disk_check"

str_test9:
        .dstr "9. disk_delete"

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

        ; --- Testi 2: disk_mkdir ---
        READ  R0, SCREEN_ROW2
        READ  R1, str_test2
        CALL  write_str_at

        READ  R0, test_dirname
        CALL  disk_mkdir
        CALL  check_result

        ; --- Testi 3: disk_create ---
        READ  R0, SCREEN_ROW3
        READ  R1, str_test3
        CALL  write_str_at

        READ  R0, test_filename
        CALL  disk_create
        CALL  check_result

        ; --- Testi 4: disk_write ---
        READ  R0, SCREEN_ROW4
        READ  R1, str_test4
        CALL  write_str_at

        READ  R0, test_filename
        READ  R1, test_data
        READ  R2, 8               ; 8 sanaa
        CALL  disk_write
        CALL  check_result

        ; --- Testi 5: disk_read ---
        READ  R0, SCREEN_ROW5
        READ  R1, str_test5
        CALL  write_str_at

        ; Nollaa lukupuskuri ensin (FILL edellyttää rekisterioperandeja)
        ; read_buf on 8 sanaa, read_buf_last osoittaa viimeiseen sanaan (inklusiivinen)
        READ  R0, read_buf
        READ  R1, read_buf_last
        READ  R2, 0
        FILL  R0, R1, R2          ; nollaa kaikki 8 sanaa

        READ  R0, test_filename
        READ  R1, read_buf
        READ  R2, 8
        CALL  disk_read          ; R0 = DISK_OK jos onnistui

        ; Tarkista ensin disk_read:n paluuarvo
        PUSH  R0
        READ  R1, 0
        CMP   R0, R1
        JNZ   _t4_fail

        ; Verifoi luettu data sana sanalta
        READ  R3, test_data       ; R3 = osoitin alkuperäiseen dataan
        READ  R4, read_buf        ; R4 = osoitin luettuun puskuriin
        READ  R5, 8               ; R5 = jäljellä olevien sanojen laskuri
        READ  R6, 1               ; R6 = askeleen leveys
        READ  R7, 0               ; R7 = nollavakio (silmukan lopetusehto)
_t4_verify:
        CMP   R5, R7              ; onko kaikki sanat tarkistettu?
        JZ    _t4_ok
        READ  R8, [R3]            ; R8 = alkuperäinen sana
        READ  R9, [R4]            ; R9 = luettu sana
        CMP   R8, R9              ; vastaako luettu alkuperäistä?
        JNZ   _t4_fail
        ADD   R3, R6              ; siirry seuraavaan alkuperäiseen
        ADD   R4, R6              ; siirry seuraavaan luettuun
        SUB   R5, R6              ; vähennetään laskuria
        JUMP  _t4_verify
_t4_ok:
        POP   R0
        READ  R1, 0
        CPY   R0, R1              ; R0 = 0 (DISK_OK)
        JUMP  _t4_done
_t4_fail:
        POP   R0                  ; tasapainota pino (PUSH R0 alussa)
        READ  R0, 1               ; R0 = 1 (FAIL)
_t4_done:
        CALL  check_result

        ; --- Testi 6: disk_stat ---
        READ  R0, SCREEN_ROW6
        READ  R1, str_test6
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

        ; --- Testi 7: disk_list ---
        READ  R0, SCREEN_ROW7
        READ  R1, str_test7
        CALL  write_str_at

        READ  R0, list_buf
        READ  R1, 8
        CALL  disk_list          ; R0 = löytyneiden tiedostojen määrä

        ; Pitää löytyä tasan 2 kohdetta (hakemisto + tiedosto)
        READ  R1, 2
        CMP   R0, R1
        JNZ   _t6_fail
        READ  R0, 0
        JUMP  _t6_done
_t6_fail:
        READ  R0, 1
_t6_done:
        CALL  check_result

        ; --- Testi 8: disk_check ---
        READ  R0, SCREEN_ROW8
        READ  R1, str_test8
        CALL  write_str_at

        CALL  disk_check
        CALL  check_result

        ; --- Testi 9: disk_delete ---
        READ  R0, SCREEN_ROW9
        READ  R1, str_test9
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
        READ  R0, SCREEN_ROW10
        READ  R1, str_done
        CALL  write_str_at

        HALT

str_done:
        .dstr "Kaikki testit suoritettu."

; =============================================================================
; Tämä tiedosto on ensisijaisesti interaktiivinen demo eikä testrunner-testi.
; Kevyet tarkistukset pidetään mukana, jotta perustoiminta voidaan varmistaa
; myös automaattisesti.
; =============================================================================
.expect_storage  0x0103, 0x0000   ; poistetun tiedoston datablokki vapautettu
.expect_storage  0x0200, 0x0002   ; hakemistomerkintä 0 = hakemisto (status 2)
