; =============================================================================
; tut_conditionals.asm — Ehdolliset hypyt (Conditional Branches)
; =============================================================================
;
; KUVAUS:
;   Demonstroi kaikki kCPU16:n ehdolliset hyppykäskyt.
;   CMP-käsky vertaa kahta rekisteriä ja asettaa liput (Z, N, C, V).
;   Ehdollinen hyppykäsky päättää suorituspolun lippujen perusteella.
;
; KÄSKYT:
;   CMP A, B  — laskee A − B, asettaa liput, ei tallenna tulosta
;   JZ  addr  — hyppää jos Z=1   (A == B)
;   JNZ addr  — hyppää jos Z=0   (A != B)
;   JLT addr  — hyppää jos N!=V  (etumerkillinen A < B)
;   JGT addr  — hyppää jos Z=0 ja N=V  (etumerkillinen A > B)
;   JLE addr  — hyppää jos Z=1 tai N!=V (A <= B)
;   JGE addr  — hyppää jos N=V   (A >= B)
;
; NÄYTTÖASETTELU:
;   Rivi 0   Otsikko
;   Rivi 2   JZ  testi
;   Rivi 3   JNZ testi
;   Rivi 4   JLT testi
;   Rivi 5   JGT testi
;   Rivi 6   JLE testi
;   Rivi 7   JGE testi
;
; REKISTERIEN KÄYTTÖ:
;   R0, R1  = vertailuoperandit (vaihtelevat per testi)
;   R8      = VRAM-kirjoitusosoitin
;   R9      = merkkijono-osoitin
;   R10     = väriattribuutti
;   R11     = väliaikainen merkki (write_str)
;   R12     = 0  (nollavakio, null-vertailu)
;   R13     = 1  (inkrementtivakio)
;
; VRAM-VÄRIT:
;   0x4300 = bold keltainen (otsikko)
;   0x0700 = valkoinen (otsikkoetiketti)
;   0x0200 = vihreä (OK)
;   0x0100 = punainen (FAIL)
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA (null-terminoitu, yksi sana per merkki)
; =============================================================================

STR_TITLE:
        .dstr "EHDOLLISET HYPYT"
STR_UNDER:
        .dstr "================"

STR_JZ:
        .dstr "CMP 5=5  | JZ  (A==B)  ->"
STR_JNZ:
        .dstr "CMP 5,3  | JNZ (A!=B)  ->"
STR_JLT:
        .dstr "CMP 3<5  | JLT (A<B)   ->"
STR_JGT:
        .dstr "CMP 7>4  | JGT (A>B)   ->"
STR_JLE:
        .dstr "CMP 5<=5 | JLE (A<=B)  ->"
STR_JGE:
        .dstr "CMP 9>=3 | JGE (A>=B)  ->"

STR_OK:
        .dstr " OK"
STR_FAIL:
        .dstr " !!"

; =============================================================================
; ALIOHJELMA: write_str
; Kirjoittaa null-terminoidun merkkijonon VRAM:iin.
; Sisään: R8=VRAM-osoitin, R9=merkkijono-osoitin, R10=väri
; R12=0 (null), R13=1 (askel)
; Ulkoon: R8 osoittaa merkkijonon loppuun, R9 osoittaa null:n jälkeen
; =============================================================================
write_str:
        READ  R11, [R9]       ; lue seuraava merkki
        CMP   R11, R12        ; onko null-terminaattori?
        JZ    ws_done         ; kyllä → lopeta
        OR    R11, R10        ; lisää väriattribuutti
        STORE [R8], R11       ; kirjoita VRAM:iin
        ADD   R8, R13         ; VRAM-osoitin eteenpäin
        ADD   R9, R13         ; merkkijono-osoitin eteenpäin
        JUMP  write_str
ws_done:
        RET

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        READ  R12, 0          ; nollavakio (null-terminaattorin tunnistus)
        READ  R13, 1          ; inkrementtivakio (osoittimien kasvatukseen)

        ; --- Otsikko: rivi 0, sarake 32 = 0xF800 + 32 = 0xF820 ---
        READ  R8, 0xF820
        READ  R9, STR_TITLE
        READ  R10, 0x4300     ; bold keltainen
        CALL  write_str

        ; --- Viiva: rivi 1, sarake 32 = 0xF870 ---
        READ  R8, 0xF870
        READ  R9, STR_UNDER
        READ  R10, 0x0700     ; valkoinen
        CALL  write_str

; --- Testi 1: JZ (yhtäläinen) ---
; Tilanne: CMP 5, 5 → Z=1 → JZ otetaan → "OK"
; Sarake 0, rivi 2 = 0xF8A0

        READ  R8, 0xF8A0
        READ  R9, STR_JZ
        READ  R10, 0x0700
        CALL  write_str
        ; --- R8 osoittaa nyt heti otsikon jälkeen ---

        READ  R0, 5
        READ  R1, 5
        CMP   R0, R1          ; Z=1 (5 − 5 = 0)
        JZ    t1_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100     ; punainen
        JUMP  t1_done
t1_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200     ; vihreä
t1_done:
        CALL  write_str

; --- Testi 2: JNZ (erisuuri) ---
; Tilanne: CMP 5, 3 → Z=0 → JNZ otetaan → "OK"
; Sarake 0, rivi 3 = 0xF8F0

        READ  R8, 0xF8F0
        READ  R9, STR_JNZ
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 5
        READ  R1, 3
        CMP   R0, R1          ; Z=0 (5 − 3 = 2 ≠ 0)
        JNZ   t2_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100
        JUMP  t2_done
t2_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200
t2_done:
        CALL  write_str

; --- Testi 3: JLT (pienempi kuin) ---
; Tilanne: CMP 3, 5 → N=1, V=0 → N≠V → JLT otetaan → "OK"
; Sarake 0, rivi 4 = 0xF940

        READ  R8, 0xF940
        READ  R9, STR_JLT
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 3
        READ  R1, 5
        CMP   R0, R1          ; 3 − 5 = −2: N=1, V=0 → N≠V
        JLT   t3_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100
        JUMP  t3_done
t3_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200
t3_done:
        CALL  write_str

; --- Testi 4: JGT (suurempi kuin) ---
; Tilanne: CMP 7, 4 → Z=0, N=0, V=0 → N=V → JGT otetaan → "OK"
; Sarake 0, rivi 5 = 0xF990

        READ  R8, 0xF990
        READ  R9, STR_JGT
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 7
        READ  R1, 4
        CMP   R0, R1          ; 7 − 4 = 3: Z=0, N=0, V=0 → N=V, Z=0
        JGT   t4_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100
        JUMP  t4_done
t4_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200
t4_done:
        CALL  write_str

; --- Testi 5: JLE (pienempi tai yhtäläinen) ---
; Tilanne: CMP 5, 5 → Z=1 → JLE otetaan (Z=1 riittää) → "OK"
; Sarake 0, rivi 6 = 0xF9E0

        READ  R8, 0xF9E0
        READ  R9, STR_JLE
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 5
        READ  R1, 5
        CMP   R0, R1          ; Z=1
        JLE   t5_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100
        JUMP  t5_done
t5_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200
t5_done:
        CALL  write_str

; --- Testi 6: JGE (suurempi tai yhtäläinen) ---
; Tilanne: CMP 9, 3 → N=0, V=0 → N=V → JGE otetaan → "OK"
; Sarake 0, rivi 7 = 0xFA30

        READ  R8, 0xFA30
        READ  R9, STR_JGE
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 9
        READ  R1, 3
        CMP   R0, R1          ; 9 − 3 = 6: N=0, V=0 → N=V
        JGE   t6_ok
        READ  R9, STR_FAIL
        READ  R10, 0x0100
        JUMP  t6_done
t6_ok:
        READ  R9, STR_OK
        READ  R10, 0x0200
t6_done:
        CALL  write_str

        HALT
