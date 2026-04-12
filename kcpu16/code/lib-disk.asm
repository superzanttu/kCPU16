; =============================================================================
; lib-disk.asm — Tallennuslaitekirjasto (yksinkertainen tiedostojärjestelmä)
; =============================================================================
;
; KUVAUS:
;   Toteuttaa yksinkertaisen tiedostojärjestelmän kCPU16:n block-
;   tallennuslaitteelle. Käyttää DREAD/DWRITE-käskyjä suoraan laitteeseen.
;   Vaatii Kernel-tilan.
;
; TALLENNUSLAITTEEN RAKENNE:
;   Laite: 256 blokkia × 256 sanaa = 65536 sanaa (0x0000–0xFFFF, 16-bittiset)
;   Blokki = 256 sanaa = STORAGE_BLOCK_SIZE
;
; TIEDOSTOJÄRJESTELMÄN ASETTELU:
;
;   Blokki 0  (0x0000–0x00FF) : Boot-sektori — varattua, ei kosketa
;   Blokki 1  (0x0100–0x01FF) : FAT (File Allocation Table)
;   Blokki 2  (0x0200–0x02FF) : Hakemisto (Directory)
;   Blokki 3+ (0x0300–0xFFFF) : Data-alueet
;
; FAT-TAULUKKO (Blokki 1):
;   256 sanaa, yksi sana / blokki.
;   fat[blokki] = arvo:
;     0x0000 = blokki vapaa
;     0x0001–0x00FE = seuraava blokki (ketjutettu lista)
;     0xFFFF = viimeinen blokki (EOF)
;   Blokit 0–2 merkitään varatuiksi (fat[0..2] = 0xFFFF: koskematon/varattu).
;
; HAKEMISTO (Blokki 2):
;   8 merkintää × 32 sanaa = 256 sanaa.
;   Merkintän rakenne (kaikki arvot sanoja):
;     Offset  0    : status   (0 = vapaa, 1 = tiedosto, 2 = hakemisto)
;     Offset  1–16 : nimi     (16 sanaa, null-terminoitu; max 15 merkkiä + null)
;     Offset 17    : koko     (sanoja, 0–65535)
;     Offset 18    : luontiaika_y   (vuosi, esim. 2026)
;     Offset 19    : luontiaika_md  (kuukausi << 8 | päivä)
;     Offset 20    : muokkausaika_y (vuosi)
;     Offset 21    : muokkausaika_md (kuukausi << 8 | päivä)
;     Offset 22    : ensimmäinen_blokki (blokki-indeksi, tai 0 jos koko=0)
;     Offset 23–31 : varattu (täytetty nollilla)
;
; TOIMINNOT:
;   disk_format        — Alusta tiedostojärjestelmä (tyhjennä FAT + hakemisto)
;   disk_mkdir         — Luo hakemisto
;   disk_create        — Luo uusi tiedosto
;   disk_write         — Kirjoita dataa tiedostoon
;   disk_read          — Lue dataa tiedostosta
;   disk_delete        — Poista tiedosto
;   disk_find          — Etsi tiedosto nimellä
;   disk_stat          — Lue tiedoston metatiedot
;   disk_list          — Listaa kaikki tiedostot ja hakemistot
;   disk_check         — Tarkista tiedostojärjestelmän eheys
;
; REKISTERIKONVENTIO (kutsuvilla aliohjelmilla):
;   Sisään: R0–R3 (käyttö vaihtelee, ks. kukin aliohjelma)
;   Ulos:   R0 = tulos/paluuarvo (0 = OK, ≠0 = virhekoodi)
;   Clobbers: R0–R9 (tallenna pinoon tarvittaessa)
;
; VIRHEARVOT (palautetaan R0:ssa):
;   0        = OK (toiminto onnistui)
;   1        = DISK_ERR_NOT_FOUND     (tiedostoa ei löydy)
;   2        = DISK_ERR_DIR_FULL      (hakemisto täynnä)
;   3        = DISK_ERR_DISK_FULL     (levytila loppu)
;   4        = DISK_ERR_EXISTS        (tiedosto on jo olemassa)
;   5        = DISK_ERR_RANGE         (osoite alueen ulkopuolella)
;
; KÄYTTÖESIMERKKI:
;
;   ; 1. Alusta tiedostojärjestelmä (tehdään kerran)
;   CALL  disk_format
;
;   ; 2. Luo tiedosto "HELLO"
;   READ  R0, disk_str_hello   ; R0 = osoitin nimeen RAM:ssa
;   CALL  disk_create          ; R0 = 0 jos onnistui
;
;   ; 3. Kirjoita dataa
;   READ  R0, disk_str_hello   ; R0 = nimi
;   READ  R1, data_ptr         ; R1 = datan osoitin RAM:ssa
;   READ  R2, 10               ; R2 = sanoja kirjoitettavaksi
;   CALL  disk_write
;
;   ; 4. Lue data takaisin
;   READ  R0, disk_str_hello   ; R0 = nimi
;   READ  R1, buf_ptr          ; R1 = puskuri RAM:ssa
;   READ  R2, 10               ; R2 = sanoja luettavaksi
;   CALL  disk_read
;
;   ; 5. Poista tiedosto
;   READ  R0, disk_str_hello
;   CALL  disk_delete
;
; VAKIOT (assembly-koodissa käytettävissä .include:n jälkeen):
;   DISK_FAT_BLOCK   = 1   (FAT-blokki)
;   DISK_DIR_BLOCK   = 2   (hakemistoblokki)
;   DISK_DATA_START  = 3   (ensimmäinen datablokki)
;   DISK_BLOCK_SIZE  = 256 (STORAGE_BLOCK_SIZE)
;   DISK_DIR_ENTRIES = 8   (merkintöjä hakemistossa)
;   DISK_DIR_ENTRY_SIZE = 32 (sanoja / hakemistomerkintä)
;   DISK_NAME_WORDS  = 16  (nimen pituus sanoina hakemistossa)
;   DISK_EOF         = 0xFFFF (FAT-ketjun viimeinen merkki)
;   DISK_ERR_*       = 0–5 (virhearvot)
;
; =============================================================================

; --- Vakiot ---
.const DISK_FAT_BLOCK,    1      ; FAT sijaitsee blokissa 1
.const DISK_DIR_BLOCK,    2      ; Hakemisto sijaitsee blokissa 2
.const DISK_DATA_START,   3      ; Ensimmäinen vapaa datablokki
.const DISK_BLOCK_SIZE,   256    ; Sanoina (== STORAGE_BLOCK_SIZE)
.const DISK_DIR_ENTRIES,  8      ; Hakemistomerkintöjä max
.const DISK_DIR_ENTRY_SIZE, 32   ; Sanoja per merkintä
.const DISK_NAME_WORDS,   16     ; Nimen varaama tila sanoina
.const DISK_EOF,          0xFFFF ; FAT-ketjun päätösmerkki
.const DISK_ENTRY_FILE,   1      ; Hakemistomerkintä on tiedosto
.const DISK_ENTRY_DIR,    2      ; Hakemistomerkintä on hakemisto

.const DISK_OK,           0      ; Toiminto onnistui
.const DISK_ERR_NOT_FOUND, 1     ; Tiedostoa ei löydy
.const DISK_ERR_DIR_FULL, 2      ; Hakemisto täynnä
.const DISK_ERR_DISK_FULL, 3     ; Levytila loppu
.const DISK_ERR_EXISTS,   4      ; Tiedosto on jo olemassa
.const DISK_ERR_RANGE,    5      ; Osoite alueen ulkopuolella

; --- Laskennalliset vakiot ---
; FAT blokki-osoite: blokki N alkaa osoitteessa N * 256
; DISK_FAT_ADDR  = 1 * 256 = 0x0100
; DISK_DIR_ADDR  = 2 * 256 = 0x0200
; DISK_DATA_ADDR = 3 * 256 = 0x0300
; (lasketaan ajoaikana koodissa)

; =============================================================================
; disk_io_buf — Kirjaston yksityinen puskuri (käytetään sisäisesti)
;
; Yksi blokki (256 sanaa) puskuria lukemista/kirjoittamista varten.
; Sijaitsee RAM:ssa — ei tallennuslaitteella.
; =============================================================================

disk_io_buf:
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0
        .dw   0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0

; =============================================================================
; _disk_read_block — Lue yksi blokki tallennuslaitteelta disk_io_buf:iin
;
; Sisään: R0 = blokki-indeksi (0–255)
; Ulos:   (disk_io_buf täytetty)
; Clobbers: R0–R5
; =============================================================================
_disk_read_block:
        PUSH  R4
        PUSH  R5
        ; Laske blokin aloitusosoite tallennuslaitteella: addr = blokki * 256
        READ  R1, 256
        MUL   R0, R1              ; R0 = blokki * 256 = aloitusosoite laitteella
        READ  R2, disk_io_buf     ; R2 = kohde RAM:ssa
        READ  R3, 256             ; R3 = laskuri (256 sanaa)
        READ  R4, 0
_drb_loop:
        CMP   R3, R4
        JZ    _drb_done
        DREAD R5, R0              ; R5 = storage[R0]
        STORE [R2], R5            ; RAM[R2] = R5
        READ  R4, 1
        ADD   R0, R4              ; R0++
        ADD   R2, R4              ; R2++
        SUB   R3, R4              ; R3--
        READ  R4, 0
        JUMP  _drb_loop
_drb_done:
        POP   R5
        POP   R4
        RET

; =============================================================================
; _disk_write_block — Kirjoita disk_io_buf yksi blokki tallennuslaitteelle
;
; Sisään: R0 = blokki-indeksi (0–255)
; Ulos:   (data kirjoitettu laitteelle)
; Clobbers: R0–R4
; =============================================================================
_disk_write_block:
        PUSH  R5
        ; Laske blokin aloitusosoite: addr = blokki * 256
        READ  R1, 256
        MUL   R0, R1              ; R0 = aloitusosoite laitteella
        READ  R2, disk_io_buf     ; R2 = lähde RAM:ssa
        READ  R3, 256             ; R3 = laskuri
        READ  R4, 1
_dwb_loop:
        READ  R5, 0
        CMP   R3, R5
        JZ    _dwb_done
        READ  R5, [R2]            ; R5 = RAM[R2]
        DWRITE R5, R0             ; storage[R0] = R5
        ADD   R0, R4
        ADD   R2, R4
        SUB   R3, R4
        JUMP  _dwb_loop
_dwb_done:
        POP   R5
        RET

; =============================================================================
; _disk_str_cmp — Vertaa kaksi null-terminoitua merkkijonoa
;
; Sisään: R0 = osoitin merkkijono A (RAM)
;         R1 = osoitin merkkijono B (RAM)
; Ulos:   R0 = 0 jos samat, ≠0 jos erot
; Clobbers: R0–R4
; =============================================================================
_disk_str_cmp:
        PUSH  R5
        PUSH  R6
        READ  R5, 1
_dsc_loop:
        READ  R3, [R0]            ; R3 = A[i]
        READ  R4, [R1]            ; R4 = B[i]
        CMP   R3, R4
        JNZ   _dsc_diff
        ; Samat — onko null?
        READ  R6, 0
        CMP   R3, R6
        JZ    _dsc_equal
        ADD   R0, R5
        ADD   R1, R5
        JUMP  _dsc_loop
_dsc_equal:
        READ  R0, 0
        POP   R6
        POP   R5
        RET
_dsc_diff:
        READ  R0, 1
        POP   R6
        POP   R5
        RET

; =============================================================================
; _disk_str_copy — Kopioi null-terminoitu merkkijono
;
; Sisään: R0 = lähde (RAM-osoitin)
;         R1 = kohde (RAM-osoitin)
;         R2 = max sanoja (sisältäen null-lopetuksen)
; Ulos:   (kohde täytetty; null lisätty ennen max:ia)
; Clobbers: R0–R4
; =============================================================================
_disk_str_copy:
        PUSH  R5
        READ  R3, 1
        READ  R4, 0
_dscp_loop:
        CMP   R2, R4
        JZ    _dscp_done
        READ  R5, [R0]
        STORE [R1], R5
        ADD   R0, R3
        ADD   R1, R3
        SUB   R2, R3
        CMP   R5, R4
        JZ    _dscp_done
        JUMP  _dscp_loop
_dscp_done:
        ; Varmista null-lopetus jos laskuri täyttyi
        CMP   R2, R4
        JNZ   _dscp_ret
        READ  R5, 0
        STORE [R1], R5
_dscp_ret:
        POP   R5
        RET

; =============================================================================
; disk_format — Alusta tiedostojärjestelmä
;
; Nollaa FAT-taulukon (blokki 1) ja hakemiston (blokki 2).
; Merkitsee boot-sektori, FAT- ja hakemistoblokit varatuiksi FAT:ssa.
;
; Sisään: (ei operandeja)
; Ulos:   R0 = DISK_OK (aina)
; Clobbers: R0–R9
; =============================================================================
disk_format:
        PUSH  R8
        PUSH  R9

        ; --- Tyhjennä disk_io_buf (nollaa kaikki 256 sanaa) ---
        READ  R0, disk_io_buf
        READ  R1, 0
        READ  R2, disk_io_buf
        READ  R8, 256
        ADD   R2, R8              ; R2 = disk_io_buf + 256 (lopetussoite)
        READ  R8, DISK_ENTRY_FILE
        ; käytetään FILL: FILL start, end, arvo
        ; FILL [R0..R2-1] = R1 → FILL R0, R2, R1 ei ole suoraan käytettävissä
        ; Sen sijaan nollaamme käsin silmukalla
_fmt_clear_buf:
        ; (ei hyppykohde — suoritus laskeutuu tähän suoraan ylhäältä)
        ; Nollaa koko blokki (256 sanaa) silmukalla ennen tallennusta
        READ  R7, disk_io_buf
        READ  R9, 256
        READ  R6, 0
        READ  R5, 1
_fmt_zero_loop:
        CMP   R9, R6
        JZ    _fmt_zero_done
        STORE [R7], R6
        ADD   R7, R5
        SUB   R9, R5
        JUMP  _fmt_zero_loop
_fmt_zero_done:

        ; --- Merkitse varautumattomat blokit vapaiksi FAT:ssa ---
        ; FAT[0] = 0xFFFF (boot-sektori, varattu)
        ; FAT[1] = 0xFFFF (FAT itse, varattu)
        ; FAT[2] = 0xFFFF (hakemisto, varattu)
        ; FAT[3..255] = 0x0000 (vapaa) — jo nollattu ylläolevassa silmukassa
        ; Nollattu puskuri kirjoitetaan levylle jälkempänä.
        READ  R7, disk_io_buf
        READ  R8, 0xFFFF
        STORE [R7], R8            ; fat[0] = 0xFFFF
        READ  R9, 1
        ADD   R7, R9
        STORE [R7], R8            ; fat[1] = 0xFFFF
        ADD   R7, R9
        STORE [R7], R8            ; fat[2] = 0xFFFF

        ; --- Kirjoita FAT tallennuslaitteelle (blokki 1) ---
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_write_block

        ; --- Nollaa disk_io_buf uudelleen hakemistoa varten ---
        READ  R7, disk_io_buf
        READ  R9, 256
        READ  R6, 0
        READ  R5, 1
_fmt_zero_dir_loop:
        CMP   R9, R6
        JZ    _fmt_zero_dir_done
        STORE [R7], R6
        ADD   R7, R5
        SUB   R9, R5
        JUMP  _fmt_zero_dir_loop
_fmt_zero_dir_done:

        ; --- Kirjoita hakemisto tallennuslaitteelle (blokki 2) ---
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_write_block

        POP   R9
        POP   R8
        READ  R0, DISK_OK
        RET

; =============================================================================
; _fat_alloc — Etsi ja varaa yksi vapaa blokki FAT:sta
;
; Lukee FAT:n disk_io_buf:iin, etsii ensimmäisen nollasanan (vapaan blokin)
; aloittaen blokista DISK_DATA_START (3).
;
; Sisään: (ei operandeja)
; Ulos:   R0 = blokki-indeksi jos löytyi, 0xFFFF jos levy täynnä
; Clobbers: R0–R6
; =============================================================================
_fat_alloc:
        PUSH  R7

        ; Lue FAT blokki (blokki 1 → disk_io_buf)
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_read_block

        ; Etsi vapaa blokki alkaen DISK_DATA_START (3)
        READ  R2, disk_io_buf
        READ  R3, DISK_DATA_START  ; R3 = blokki-indeksi (alkaa 3:sta)
        READ  R4, 1
        READ  R5, 0
        READ  R6, 256              ; max blokki-indeksi

_fa_loop:
        ; Onko blokki-indeksi > 255?
        CMP   R3, R6
        JGE   _fa_full
        ; Laske osoitin FAT-alkiolle: &fat[R3] = disk_io_buf + R3
        READ  R0, disk_io_buf
        ADD   R0, R3
        READ  R0, [R0]            ; fat[R3]
        CMP   R0, R5              ; == 0? (vapaa)
        JZ    _fa_found
        ADD   R3, R4              ; seuraava blokki
        JUMP  _fa_loop

_fa_found:
        ; Merkitse blokki varatuksi: fat[R3] = DISK_EOF
        READ  R0, disk_io_buf
        ADD   R0, R3
        READ  R1, DISK_EOF
        STORE [R0], R1
        ; Kirjoita päivitetty FAT takaisin
        PUSH  R3                  ; suojaa blokki-indeksi (_disk_write_block clobberoi R3)
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_write_block
        POP   R3                  ; palauta blokki-indeksi
        ; Palauta blokki-indeksi
        CPY   R0, R3
        POP   R7
        RET

_fa_full:
        READ  R0, DISK_EOF        ; 0xFFFF = levy täynnä
        POP   R7
        RET

; =============================================================================
; _fat_free_chain — Vapauta blokki-ketju FAT:ssa aloittaen annetusta blokista
;
; Sisään: R0 = aloitusblokki
; Ulos:   (ketju vapautettu)
; Clobbers: R0–R5
; =============================================================================
_fat_free_chain:
        PUSH  R6

        ; Lue FAT
        PUSH  R0
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_read_block
        POP   R0

        READ  R1, disk_io_buf
        READ  R2, 1
        READ  R3, 0
        READ  R4, DISK_EOF

_ffc_loop:
        CMP   R0, R4              ; Onko blokki DISK_EOF tai 0?
        JZ    _ffc_done
        CMP   R0, R3
        JZ    _ffc_done
        ; Hae seuraava blokki ketjusta ennen nollausta
        READ  R5, disk_io_buf
        ADD   R5, R0
        READ  R6, [R5]            ; R6 = fat[R0] (seuraava blokki)
        ; Vapauta nykyinen blokki: fat[R0] = 0
        STORE [R5], R3
        CPY   R0, R6              ; siirrä seuraavaan
        JUMP  _ffc_loop

_ffc_done:
        ; Kirjoita päivitetty FAT
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_write_block

        POP   R6
        RET

; Korjattu kutsu — käytetään apumuuttujaa:
; Syy: _disk_str_cmp clobberoi R6:n, joten merkintäindeksiä ei voi
; pitää pelkästään rekisterissä. Tallennetaan väliaikaiseen muuttujaan
; ennen kutsua ja luetaan takaisin kutsun jälkeen.
_dfbn_cur_idx:
        .dw  0

; =============================================================================
; disk_find — Etsi tiedosto nimellä (julkinen rajapinta)
;
; Sisään: R0 = osoitin tiedoston nimeen RAM:ssa (null-terminoitu)
; Ulos:   R0 = merkintä-indeksi (0–7) jos löytyi
;         R0 = DISK_ERR_NOT_FOUND (1) jos ei löydy
;         disk_io_buf sisältää hakemistodatan (käytettävissä disk_stat:ille)
; Clobbers: R0–R9
; =============================================================================
disk_find:
        PUSH  R8
        PUSH  R9
        CPY   R9, R0              ; R9 = haetun nimen osoitin

        ; Lue hakemisto disk_io_buf:iin
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R6, 0               ; R6 = merkintäindeksi
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1

_df_loop:
        CMP   R6, R7
        JGE   _df_not_found

        ; Merkinnän perusosoite: disk_io_buf + indeksi * 32
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]

        ; Tarkista status (offset 0) — pitää olla tiedosto
        READ  R1, [R0]
        CMP   R1, R8
        JNZ   _df_next

        ; Tallenna indeksi
        STORE [_dfbn_cur_idx], R6

        ; Vertaa nimi: &entry[R6] + 1
        ADD   R0, R8
        CPY   R1, R9
        CALL  _disk_str_cmp       ; R0 = 0 jos nimet samat

        ; Palauta tallennettu indeksi ja tarkista tulos
        READ  R2, 0
        CMP   R0, R2
        JZ    _df_found
        JUMP  _df_next

_df_next:
        ADD   R6, R8
        JUMP  _df_loop

_df_found:
        READ  R0, [_dfbn_cur_idx]
        POP   R9
        POP   R8
        RET

_df_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_find_any — Etsi tiedosto tai hakemisto nimellä
;
; Sisään: R0 = osoitin nimeen RAM:ssa (null-terminoitu)
; Ulos:   R0 = merkintä-indeksi (0–7) jos löytyi
;         R0 = DISK_ERR_NOT_FOUND (1) jos ei löydy
;         disk_io_buf sisältää hakemistodatan
; Clobbers: R0–R9
; =============================================================================
disk_find_any:
        PUSH  R8
        PUSH  R9
        CPY   R9, R0              ; R9 = haetun nimen osoitin

        ; Lue hakemisto disk_io_buf:iin
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R6, 0               ; R6 = merkintäindeksi
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1

_dfa_loop:
        CMP   R6, R7
        JGE   _dfa_not_found

        ; Merkinnän perusosoite: disk_io_buf + indeksi * 32
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]

        ; Tarkista status (offset 0) — pitää olla käytössä (ei 0)
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JZ    _dfa_next

        ; Tallenna indeksi
        STORE [_dfbn_cur_idx], R6

        ; Vertaa nimi: &entry[R6] + 1
        ADD   R0, R8
        CPY   R1, R9
        CALL  _disk_str_cmp       ; R0 = 0 jos nimet samat

        ; Palauta tallennettu indeksi ja tarkista tulos
        READ  R2, 0
        CMP   R0, R2
        JZ    _dfa_found
        JUMP  _dfa_next

_dfa_next:
        ADD   R6, R8
        JUMP  _dfa_loop

_dfa_found:
        READ  R0, [_dfbn_cur_idx]
        POP   R9
        POP   R8
        RET

_dfa_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_create — Luo uusi tiedosto
;
; Sisään: R0 = osoitin nimeen RAM:ssa (null-terminoitu, max 15 merkkiä)
; Ulos:   R0 = DISK_OK          jos onnistui
;         R0 = DISK_ERR_EXISTS   jos samanniminen tiedosto on jo olemassa
;         R0 = DISK_ERR_DIR_FULL jos hakemisto on täynnä
; Clobbers: R0–R9
; =============================================================================
disk_create:
        PUSH  R8
        PUSH  R9
        CPY   R9, R0              ; R9 = nimen osoitin

        ; Tarkista ettei samanniminen kohde (tiedosto/hakemisto) ole jo olemassa
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _dc_exists          ; Löytyi → virhe

        ; Lue hakemisto (disk_find on jo lukenut sen, mutta lue varmuuden vuoksi)
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        ; Etsi vapaa merkintä (status == 0)
        READ  R6, 0
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1
_dc_find_free:
        CMP   R6, R7
        JGE   _dc_dir_full
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JZ    _dc_free_found
        ADD   R6, R8
        JUMP  _dc_find_free

_dc_free_found:
        ; Täytä merkintä: status=tiedosto, nimi, koko=0, ajat, ensimmäinen blokki=0
        READ  R1, DISK_ENTRY_FILE
        STORE [R0], R1
        ; Kopioi nimi kenttään (offset 1)
        READ  R1, 1
        ADD   R0, R1              ; R0 = &entry.name
        CPY   R3, R0              ; R3 = kohde
        CPY   R0, R9              ; R0 = lähde (haettu nimi)
        CPY   R1, R3              ; R1 = kohde
        READ  R2, DISK_NAME_WORDS
        CALL  _disk_str_copy

        ; Laske merkinnän perusosoite uudelleen (R0 muuttui str_copy:ssa)
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]
        READ  R1, DISK_NAME_WORDS
        READ  R2, 1
        ADD   R1, R2
        ADD   R0, R1              ; R0 = &entry + 1 + 16 = offset 17

        ; koko = 0
        READ  R1, 0
        STORE [R0], R1
        ADD   R0, R2

        ; Luontiaika: vuosi, kuukausi<<8|päivä
        ; CLOCK_YEAR (0x0010), CLOCK_MONTH (0x0011), CLOCK_DAY (0x0012)
        ; ovat vain luettavia MMIO-rekisterejä — suora muistinosoitus riittää.
        READ  R1, [CLOCK_YEAR]
        STORE [R0], R1
        ADD   R0, R2
        READ  R3, [CLOCK_MONTH]
        READ  R4, 8
        SHL   R3, R4
        READ  R4, [CLOCK_DAY]
        OR    R3, R4
        STORE [R0], R3
        ADD   R0, R2

        ; Muokkausaika = sama kuin luontiaika (tiedosto juuri luotu)
        READ  R1, [CLOCK_YEAR]    ; MMIO 0x0010
        STORE [R0], R1
        ADD   R0, R2
        STORE [R0], R3            ; R3 = kuukausi<<8|päivä (laskettu yllä)
        ADD   R0, R2

        ; Ensimmäinen blokki = 0 (ei dataa vielä)
        READ  R1, 0
        STORE [R0], R1

        ; Kirjoita hakemisto takaisin levylle
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_write_block

        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dc_exists:
        READ  R0, DISK_ERR_EXISTS
        POP   R9
        POP   R8
        RET

_dc_dir_full:
        READ  R0, DISK_ERR_DIR_FULL
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_mkdir — Luo uusi hakemisto
;
; Sisään: R0 = osoitin nimeen/polkuun RAM:ssa (null-terminoitu, max 15 merkkiä)
; Ulos:   R0 = DISK_OK           jos onnistui
;         R0 = DISK_ERR_EXISTS   jos samanniminen kohde on jo olemassa
;         R0 = DISK_ERR_DIR_FULL jos hakemisto on täynnä
; Clobbers: R0–R9
; =============================================================================
disk_mkdir:
        PUSH  R8
        PUSH  R9
        CPY   R9, R0              ; R9 = nimen osoitin

        ; Tarkista ettei samanniminen kohde ole jo olemassa
        CALL  disk_find_any
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JNZ   _dm_exists

        ; Lue hakemisto
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        ; Etsi vapaa merkintä (status == 0)
        READ  R6, 0
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1
_dm_find_free:
        CMP   R6, R7
        JGE   _dm_dir_full
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JZ    _dm_free_found
        ADD   R6, R8
        JUMP  _dm_find_free

_dm_free_found:
        ; status = hakemisto
        READ  R1, DISK_ENTRY_DIR
        STORE [R0], R1

        ; Kopioi nimi kenttään (offset 1)
        READ  R1, 1
        ADD   R0, R1              ; R0 = &entry.name
        CPY   R3, R0              ; R3 = kohde
        CPY   R0, R9              ; R0 = lähde
        CPY   R1, R3              ; R1 = kohde
        READ  R2, DISK_NAME_WORDS
        CALL  _disk_str_copy

        ; Laske merkinnän perusosoite uudelleen
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]
        READ  R1, DISK_NAME_WORDS
        READ  R2, 1
        ADD   R1, R2
        ADD   R0, R1              ; R0 = &entry + 17

        ; koko = 0
        READ  R1, 0
        STORE [R0], R1
        ADD   R0, R2

        ; Luontiaika: vuosi, kuukausi<<8|päivä
        READ  R1, [CLOCK_YEAR]
        STORE [R0], R1
        ADD   R0, R2
        READ  R3, [CLOCK_MONTH]
        READ  R4, 8
        SHL   R3, R4
        READ  R4, [CLOCK_DAY]
        OR    R3, R4
        STORE [R0], R3
        ADD   R0, R2

        ; Muokkausaika = sama kuin luontiaika
        READ  R1, [CLOCK_YEAR]
        STORE [R0], R1
        ADD   R0, R2
        STORE [R0], R3
        ADD   R0, R2

        ; Ensimmäinen blokki = 0 (hakemistot eivät käytä datablokkeja tässä toteutuksessa)
        READ  R1, 0
        STORE [R0], R1

        ; Kirjoita hakemisto takaisin levylle
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_write_block

        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dm_exists:
        READ  R0, DISK_ERR_EXISTS
        POP   R9
        POP   R8
        RET

_dm_dir_full:
        READ  R0, DISK_ERR_DIR_FULL
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_write — Kirjoita dataa tiedostoon (ylikirjoittaa olemassa olevan datan)
;
; Sisään: R0 = osoitin tiedoston nimeen RAM:ssa
;         R1 = osoitin dataan RAM:ssa
;         R2 = kirjoitettavien sanojen määrä
; Ulos:   R0 = DISK_OK           jos onnistui
;         R0 = DISK_ERR_NOT_FOUND jos tiedostoa ei löydy
;         R0 = DISK_ERR_DISK_FULL jos levytila loppuu
; Clobbers: R0–R9
;
; HUOM: Kirjoittaa koko sisällön kerralla aloittaen alusta.
;       Jos tiedostolla oli aiempaa dataa, näillä blokeilla on nyt uusi data
;       (tai blokki vapautetaan ylijäävistä).
; =============================================================================
disk_write:
        PUSH  R8
        PUSH  R9

        ; Tallenna parametrit
        STORE [_dw_data_ptr],   R1
        STORE [_dw_data_words], R2
        STORE [_dw_orig_words], R2  ; tallenna alkuperäinen sanamäärä
        CPY   R9, R0              ; R9 = nimi

        ; Etsi tiedosto → R0 = indeksi tai virhe
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JZ    _dw_not_found

        STORE [_dw_entry_idx], R0

        ; Hae merkintä: laske perusosoite
        CPY   R0, R0              ; (indeksi on R0:ssa disk_find:istä)
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry
        STORE [_dw_entry_ptr], R0

        ; Hae vanha ensimmäinen blokki (offset 22)
        READ  R1, 22
        ADD   R0, R1
        READ  R1, [R0]            ; R1 = vanha ensimmäinen blokki
        STORE [_dw_old_first_block], R1

        ; Vapauta vanhat blokit (jos oli dataa)
        READ  R2, 0
        CMP   R1, R2
        JZ    _dw_no_old_data
        CPY   R0, R1
        CALL  _fat_free_chain

_dw_no_old_data:
        ; Kirjoita data blokki kerrallaan
        READ  R0, [_dw_data_words]
        READ  R2, 0
        CMP   R0, R2
        JZ    _dw_empty_file

        ; Varaa ensimmäinen blokki
        CALL  _fat_alloc
        READ  R1, DISK_EOF
        CMP   R0, R1
        JZ    _dw_disk_full

        STORE [_dw_first_block], R0
        STORE [_dw_cur_block], R0

        ; Kirjoitussilmukka
_dw_write_loop:
        ; Nollaa io-puskuri
        READ  R7, disk_io_buf
        READ  R8, 256
        READ  R6, 1
        READ  R2, 0              ; R2 = nollavakio (R9 on varattu nimelle)
_dw_clr_buf:
        CMP   R8, R2
        JZ    _dw_clr_done
        STORE [R7], R2
        ADD   R7, R6
        SUB   R8, R6
        JUMP  _dw_clr_buf
_dw_clr_done:

        ; Kopioi max 256 sanaa datasta → io-puskuriin
        READ  R5, [_dw_data_ptr]   ; R5 = datan osoitin
        READ  R4, [_dw_data_words] ; R4 = jäljellä olevat sanat
        READ  R7, disk_io_buf
        READ  R8, 256
        READ  R6, 1
        READ  R2, 0              ; R2 = nollavakio

        ; min(R4, 256) sanaa kopioidaan
_dw_copy_loop:
        CMP   R4, R2
        JZ    _dw_copy_done
        CMP   R8, R2
        JZ    _dw_copy_done
        READ  R3, [R5]
        STORE [R7], R3
        ADD   R5, R6
        ADD   R7, R6
        SUB   R4, R6
        SUB   R8, R6
        JUMP  _dw_copy_loop
_dw_copy_done:

        ; Päivitä datan osoitin ja jäljellä olevat sanat
        STORE [_dw_data_ptr], R5
        STORE [_dw_data_words], R4

        ; Kirjoita blokki levylle
        READ  R0, [_dw_cur_block]
        CALL  _disk_write_block

        ; Onko dataa jäljellä?
        READ  R4, [_dw_data_words]
        READ  R9, 0
        CMP   R4, R9
        JZ    _dw_write_done

        ; Varaa seuraava blokki
        CALL  _fat_alloc
        READ  R1, DISK_EOF
        CMP   R0, R1
        JZ    _dw_disk_full

        ; Ketjuta ketju: fat[cur_block] = uusi_blokki
        ; _fat_alloc on jo merkinnyt fat[uusi_blokki] = DISK_EOF.
        ; Nyt yhdistetään vanhan blokin linkki uuteen:
        ;   fat[cur_block] = uusi_blokki  (edell. blokki osoittaa seuraavaan)
        ;   fat[uusi_blokki] = DISK_EOF   (uusi blokki on ketjun pää)
        ; FAT luetaan levyltä uudelleen, koska _fat_alloc saattoi muuttaa sitä.
        READ  R1, DISK_FAT_BLOCK
        PUSH  R0                  ; tallenna uusi blokki-indeksi

        ; Lue ajantasainen FAT (kirjoitettu _fat_alloc:ssa)
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_read_block

        POP   R0                  ; R0 = uusi blokki (varattu _fat_alloc:lla)
        ; Kirjoita linkki: fat[cur_block] → uusi_blokki
        READ  R2, disk_io_buf
        READ  R3, [_dw_cur_block]
        ADD   R2, R3
        STORE [R2], R0            ; fat[cur_block] = uusi blokki

        STORE [_dw_cur_block], R0

        ; Kirjoita päivitetty FAT
        PUSH  R0
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_write_block
        POP   R0

        JUMP  _dw_write_loop

_dw_write_done:
        JUMP  _dw_update_dir

_dw_empty_file:
        READ  R0, 0
        STORE [_dw_first_block], R0

_dw_update_dir:
        ; Päivitä hakemistomerkintä: koko ja ensimmäinen blokki, muokkausaika
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R0, [_dw_entry_idx]
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry

        ; Kopioi nimi takaisin (jo olemassa), hyppää offset 17:ään
        READ  R1, 17
        ADD   R0, R1

        ; Kirjoita koko (alkuperäinen sanamäärä — laskettava uudelleen)
        ; Alkuperäinen sanamäärä tallennettiin _dw_orig_words:iin
        READ  R1, [_dw_orig_words]
        READ  R2, 1
        STORE [R0], R1
        ADD   R0, R2

        ; Luontiaika (offsetit 18–19) säilyy ennallaan — ohitetaan.
        ; Muokkausaika (offsetit 20–21) päivitetään kellosta.
        ADD   R0, R2              ; offset 18: luontivuosi — ohitetaan
        ADD   R0, R2              ; offset 19: luontipäivä — ohitetaan
        ; offset 20: muokkausvuosi (MMIO 0x0010)
        READ  R1, [CLOCK_YEAR]
        STORE [R0], R1
        ADD   R0, R2
        ; offset 21: muokkaus md — pakattu: (kuukausi << 8) | päivä
        READ  R1, [CLOCK_MONTH]
        READ  R3, 8
        SHL   R1, R3
        READ  R3, [CLOCK_DAY]
        OR    R1, R3
        STORE [R0], R1
        ADD   R0, R2
        ; offset 22: ensimmäinen blokki
        READ  R1, [_dw_first_block]
        STORE [R0], R1

        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_write_block

        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dw_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

_dw_disk_full:
        READ  R0, DISK_ERR_DISK_FULL
        POP   R9
        POP   R8
        RET

; --- disk_write apumuuttujat ---
_dw_data_ptr:
        .dw  0
_dw_data_words:
        .dw  0
_dw_orig_words:
        .dw  0
_dw_entry_idx:
        .dw  0
_dw_entry_ptr:
        .dw  0
_dw_old_first_block:
        .dw  0
_dw_first_block:
        .dw  0
_dw_cur_block:
        .dw  0

; =============================================================================
; disk_read — Lue dataa tiedostosta
;
; Sisään: R0 = osoitin tiedoston nimeen RAM:ssa
;         R1 = osoitin puskuriin RAM:ssa (kohde)
;         R2 = luettavien sanojen enimmäismäärä
; Ulos:   R0 = DISK_OK           jos onnistui
;         R0 = DISK_ERR_NOT_FOUND jos tiedostoa ei löydy
;         R0 = DISK_ERR_RANGE     jos yritetään lukea liikaa
; Clobbers: R0–R9
; =============================================================================
disk_read:
        PUSH  R8
        PUSH  R9

        STORE [_dr_dst_ptr],  R1
        STORE [_dr_max_words], R2
        CPY   R9, R0

        ; Etsi tiedosto
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JZ    _dr_not_found

        ; Hae tiedoston koko ja ensimmäinen blokki hakemistosta
        CPY   R8, R0              ; R8 = merkintäindeksi
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R8, R1
        READ  R1, disk_io_buf
        ADD   R8, R1              ; R8 = &entry

        ; offset 17 = koko
        CPY   R0, R8
        READ  R1, 17
        ADD   R0, R1
        READ  R6, [R0]            ; R6 = tiedoston koko sanoina
        STORE [_dr_file_words], R6

        ; offset 22 = ensimmäinen blokki
        CPY   R0, R8
        READ  R1, 22
        ADD   R0, R1
        READ  R5, [R0]            ; R5 = ensimmäinen blokki

        ; Luettavien sanojen määrä = min(max_words, file_words)
        ; Jos kutsuja pyytää enemmän kuin tiedostossa on, rajoitetaan file_words:iin.
        ; Huom: JLE vertaa etumerkillisesti — file_words oletetaan < 0x8000.
        READ  R3, [_dr_max_words]
        CMP   R3, R6
        JLE   _dr_use_max         ; max_words <= file_words → käytetään max_words
        CPY   R3, R6              ; max_words > file_words → käytetään file_words
_dr_use_max:
        STORE [_dr_rem_words], R3

        READ  R0, 0
        CMP   R3, R0
        JZ    _dr_done_ok          ; 0 sanaa luettavaksi

        ; Lue blokki kerrallaan
_dr_read_loop:
        READ  R4, [_dr_rem_words]
        READ  R0, 0
        CMP   R4, R0
        JZ    _dr_done_ok

        CMP   R5, R0
        JZ    _dr_done_ok          ; ensimmäinen blokki = 0 → ei dataa

        ; Lue blokki disk_io_buf:iin
        CPY   R0, R5
        CALL  _disk_read_block

        ; Kopioi min(jäljellä, 256) sanaa puskuriin
        READ  R7, [_dr_dst_ptr]
        READ  R6, disk_io_buf
        READ  R3, 256
        READ  R0, [_dr_rem_words]
        CMP   R0, R3
        JLE   _dr_copy_n_max      ; luetaan max 256
        CPY   R0, R3
_dr_copy_n_max:
        ; R0 = kopioitavat sanat
        STORE [_dr_copy_n], R0
        READ  R1, 1
        READ  R2, 0
_dr_copy_loop:
        CMP   R0, R2
        JZ    _dr_copy_done
        READ  R3, [R6]
        STORE [R7], R3
        ADD   R6, R1
        ADD   R7, R1
        SUB   R0, R1
        JUMP  _dr_copy_loop
_dr_copy_done:
        STORE [_dr_dst_ptr], R7

        ; Vähennä rem_words
        READ  R0, [_dr_rem_words]
        READ  R1, [_dr_copy_n]
        SUB   R0, R1
        STORE [_dr_rem_words], R0

        ; Seuraava blokki FAT:sta
        READ  R0, DISK_FAT_BLOCK
        CALL  _disk_read_block
        READ  R0, disk_io_buf
        ADD   R0, R5
        READ  R5, [R0]            ; R5 = fat[cur_blokki]

        READ  R0, DISK_EOF
        CMP   R5, R0
        JZ    _dr_done_ok          ; Viimeinen blokki

        JUMP  _dr_read_loop

_dr_done_ok:
        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dr_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

; --- disk_read apumuuttujat ---
_dr_dst_ptr:
        .dw  0
_dr_max_words:
        .dw  0
_dr_file_words:
        .dw  0
_dr_rem_words:
        .dw  0
_dr_copy_n:
        .dw  0

; =============================================================================
; disk_delete — Poista tiedosto
;
; Sisään: R0 = osoitin tiedoston nimeen RAM:ssa
; Ulos:   R0 = DISK_OK           jos onnistui
;         R0 = DISK_ERR_NOT_FOUND jos tiedostoa ei löydy
; Clobbers: R0–R9
; =============================================================================
disk_delete:
        PUSH  R8
        PUSH  R9
        CPY   R9, R0

        ; Etsi tiedosto
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JZ    _dd_not_found

        ; Tallenna indeksi
        STORE [_dd_entry_idx], R0

        ; Hae ensimmäinen blokki (offset 22)
        CPY   R8, R0
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R8, R1
        READ  R1, disk_io_buf
        ADD   R8, R1              ; R8 = &entry
        READ  R0, R8
        READ  R1, 22
        ADD   R0, R1
        READ  R0, [R0]            ; R0 = ensimmäinen blokki

        ; Vapauta blokki-ketju
        READ  R1, 0
        CMP   R0, R1
        JZ    _dd_free_dir        ; ei dataa
        CALL  _fat_free_chain

_dd_free_dir:
        ; Merkitse hakemistomerkintä vapaaksi (status = 0)
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R0, [_dd_entry_idx]
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1

        READ  R1, 0
        STORE [R0], R1            ; status = 0

        ; Kirjoita hakemisto
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_write_block

        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dd_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

; --- disk_delete apumuuttujat ---
_dd_entry_idx:
        .dw  0

; =============================================================================
; disk_stat — Lue tiedoston metatiedot
;
; Sisään: R0 = osoitin tiedoston nimeen RAM:ssa
;         R1 = osoitin tulosrakenteeseen RAM:ssa (9 sanaa):
;              [0] = koko (sanoja)
;              [1] = luontivuosi
;              [2] = luonti md (kuukausi<<8|päivä)
;              [3] = muokkausvuosi
;              [4] = muokkaus md
;              [5] = ensimmäinen blokki
; Ulos:   R0 = DISK_OK           jos onnistui
;         R0 = DISK_ERR_NOT_FOUND jos ei löydy
; Clobbers: R0–R7
; =============================================================================
disk_stat:
        PUSH  R8
        PUSH  R9
        CPY   R9, R1              ; R9 = tulospuskuri

        ; Etsi
        CALL  disk_find
        READ  R1, DISK_ERR_NOT_FOUND
        CMP   R0, R1
        JZ    _dst_not_found

        ; Laske merkinnän osoitin
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry

        ; Siirry offset 17:ään
        READ  R1, 17
        ADD   R0, R1              ; R0 = &entry.size

        READ  R2, 1
        ; Kopioi 6 kenttää: koko, luontivuosi, luontimd, muokvuosi, muokmd, 1.blokki
        READ  R3, [R0]  ; koko
        STORE [R9], R3
        ADD   R0, R2
        ADD   R9, R2

        READ  R3, [R0]  ; luontivuosi
        STORE [R9], R3
        ADD   R0, R2
        ADD   R9, R2

        READ  R3, [R0]  ; luontimd
        STORE [R9], R3
        ADD   R0, R2
        ADD   R9, R2

        READ  R3, [R0]  ; muokkausvuosi
        STORE [R9], R3
        ADD   R0, R2
        ADD   R9, R2

        READ  R3, [R0]  ; muokkausmd
        STORE [R9], R3
        ADD   R0, R2
        ADD   R9, R2

        READ  R3, [R0]  ; ensimmäinen blokki
        STORE [R9], R3

        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dst_not_found:
        READ  R0, DISK_ERR_NOT_FOUND
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_list — Listaa kaikki tiedostot puskuriin
;
; Käy läpi hakemiston kaikki käytetyt merkinnät ja kirjoittaa niiden
; nimet (osoittimet disk_io_buf:ssa oleviin nimiin) annettuun puskuriin.
;
; TÄRKEÄÄ: Palautetut osoittimet osoittavat disk_io_buf:n sisälle.
; disk_io_buf on kirjaston globaali puskuri — se ylikirjoitetaan jokaisen
; disk_*-kutsun yhteydessä. Kutsuja voi lukea nimet vain _ennen_ seuraavaa
; disk_*-kutsua. Kopioi nimet omaan puskuriisi jos tarvitset niitä myöhemmin.
;
; Sisään: R0 = osoitin puskuriin RAM:ssa (kohta johon kirjoitetaan osoittimia)
;         R1 = puskurin max koko (max alkioita, kukin 1 sana = osoitin)
; Ulos:   R0 = löytyneiden tiedostojen määrä (0 jos ei tiedostoja)
;         Puskuriin kirjoitettu osoittimet /kunkin tiedoston nimi-kenttään
;         (disk_io_buf + entry_offset + 1)
; Clobbers: R0–R8
; =============================================================================
disk_list:
        PUSH  R8
        PUSH  R9

        STORE [_dl_dst_ptr],  R0
        STORE [_dl_max],      R1

        ; Lue hakemisto
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R6, 0               ; R6 = merkintäindeksi
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1
        READ  R9, 0               ; R9 = löytyneiden laskuri

_dl_loop:
        CMP   R6, R7
        JGE   _dl_done
        ; Puskuri täynnä?
        READ  R0, [_dl_max]
        CMP   R9, R0
        JGE   _dl_done

        ; &entry[R6] = disk_io_buf + R6 * 32
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1              ; R0 = &entry[R6]

        READ  R1, [R0]            ; status (offset 0)
        READ  R2, 0
        CMP   R1, R2              ; status != 0?
        JZ    _dl_skip

        ; Kirjoita nimen osoitin puskuriin (&entry + 1 = nimi-kenttä)
        ADD   R0, R8              ; R0 = &entry.name
        READ  R2, [_dl_dst_ptr]
        STORE [R2], R0
        ADD   R2, R8
        STORE [_dl_dst_ptr], R2
        ADD   R9, R8              ; laskuri++

_dl_skip:
        ADD   R6, R8
        JUMP  _dl_loop

_dl_done:
        CPY   R0, R9              ; R0 = löytyneiden määrä
        POP   R9
        POP   R8
        RET

; =============================================================================
; disk_check — Tarkista tiedostojärjestelmän eheys
;
; Tarkistaa:
;   - FAT:n varatut blokit (0..2) ovat varattuina (DISK_EOF)
;   - Hakemiston status-kentät ovat sallittuja (0, tiedosto, hakemisto)
;   - Hakemistojen first_block = 0
;   - Tiedostojen blokkiketjut osoittavat data-alueelle ja päättyvät oikein
;
; Sisään:  (ei parametreja)
; Ulos:    R0 = DISK_OK jos eheä, muuten DISK_ERR_RANGE
; Clobbers: R0–R9
; =============================================================================
disk_check:
        PUSH  R8
        PUSH  R9

        ; FAT[0], FAT[1], FAT[2] pitää olla varattuja (DISK_EOF)
        READ  R0, 0x0100
        DREAD R1, R0
        READ  R2, DISK_EOF
        CMP   R1, R2
        JNZ   _dchk_fail

        READ  R0, 0x0101
        DREAD R1, R0
        CMP   R1, R2
        JNZ   _dchk_fail

        READ  R0, 0x0102
        DREAD R1, R0
        CMP   R1, R2
        JNZ   _dchk_fail

        ; Lue hakemisto
        READ  R0, DISK_DIR_BLOCK
        CALL  _disk_read_block

        READ  R6, 0               ; merkintäindeksi
        READ  R7, DISK_DIR_ENTRIES
        READ  R8, 1

_dchk_entry_loop:
        CMP   R6, R7
        JGE   _dchk_ok

        ; R0 = &entry[R6]
        CPY   R0, R6
        READ  R1, DISK_DIR_ENTRY_SIZE
        MUL   R0, R1
        READ  R1, disk_io_buf
        ADD   R0, R1

        ; status
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JZ    _dchk_next_entry

        READ  R2, DISK_ENTRY_FILE
        CMP   R1, R2
        JZ    _dchk_check_file

        READ  R2, DISK_ENTRY_DIR
        CMP   R1, R2
        JZ    _dchk_check_dir

        JUMP  _dchk_fail

_dchk_check_dir:
        ; hakemistolla ei dataketjua (first_block = 0)
        READ  R1, 22
        ADD   R0, R1
        READ  R1, [R0]
        READ  R2, 0
        CMP   R1, R2
        JNZ   _dchk_fail
        JUMP  _dchk_next_entry

_dchk_check_file:
        ; tiedoston first_block
        READ  R1, 22
        ADD   R0, R1
        READ  R0, [R0]

        ; tyhjä tiedosto on sallittu
        READ  R1, 0
        CMP   R0, R1
        JZ    _dchk_next_entry

        ; aloitusblokin pitää olla data-alueella
        READ  R1, DISK_DATA_START
        CMP   R0, R1
        JLT   _dchk_fail
        READ  R1, 256
        CMP   R0, R1
        JGE   _dchk_fail

        READ  R3, 0               ; ketjun askelmäärä
        READ  R4, DISK_BLOCK_SIZE ; yläraja silmukalle (256)

_dchk_chain_loop:
        READ  R5, 1
        ADD   R3, R5
        CMP   R3, R4
        JGE   _dchk_fail

        ; next = FAT[cur_block]
        READ  R1, 0x0100
        ADD   R1, R0
        DREAD R2, R1

        READ  R1, DISK_EOF
        CMP   R2, R1
        JZ    _dchk_next_entry

        READ  R1, 0
        CMP   R2, R1
        JZ    _dchk_fail

        ; seuraavan blokin pitää olla data-alueella
        READ  R1, DISK_DATA_START
        CMP   R2, R1
        JLT   _dchk_fail
        READ  R1, 256
        CMP   R2, R1
        JGE   _dchk_fail

        CPY   R0, R2
        JUMP  _dchk_chain_loop

_dchk_next_entry:
        ADD   R6, R8
        JUMP  _dchk_entry_loop

_dchk_ok:
        READ  R0, DISK_OK
        POP   R9
        POP   R8
        RET

_dchk_fail:
        READ  R0, DISK_ERR_RANGE
        POP   R9
        POP   R8
        RET

; --- disk_list apumuuttujat ---
_dl_dst_ptr:
        .dw  0
_dl_max:
        .dw  0
