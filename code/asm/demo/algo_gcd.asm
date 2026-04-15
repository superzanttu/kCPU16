; =============================================================================
; algo_gcd.asm — Suurin yhteinen tekijä (GCD) Eukleideen algoritmilla
; =============================================================================
;
; KUVAUS:
;   Demonstroi Eukleideen GCD-algoritmia (suurin yhteinen tekijä).
;   Laskee gcd(a, b) = suurin luku joka jakaa sekä a:n että b:n.
;
; ALGORITMI (Eukleideen jakojäännösalgoritmi):
;   gcd(a, 0) = a
;   gcd(a, b) = gcd(b, a mod b)   kun b > 0
;
;   Iteratiivinen muoto:
;     while b != 0:
;         temp = b
;         b    = a mod b      ; jakojäännös: a - floor(a/b)*b
;         a    = temp
;     return a
;
; JAKOJÄÄNNÖKSEN LASKENTA (koska DIV antaa osamäärän, ei jäännöstä):
;   a mod b = a - floor(a/b) * b
;   Toteutus:
;     CPY  R2, R0   ; R2 = a
;     DIV  R2, R1   ; R2 = a / b = osamäärä
;     MUL  R2, R1   ; R2 = osamäärä * b
;     SUB  R0, R2   ; R0 = a - osamäärä*b = a mod b
;
; ESIMERKIT:
;   gcd(48, 36) = 12   (48 = 4×12, 36 = 3×12)
;   gcd(100, 75) = 25  (100 = 4×25, 75 = 3×25)
;   gcd(17, 13) = 1    (alkuluvut → suy = 1)
;
; ALIOHJELMA gcd:
;   Sisään: R0 = a, R1 = b
;   Ulkoon: R0 = gcd(a, b), R1 = 0
;   Käyttää: R2, R3 (molemmat tuhotaan)
;
; NÄYTTÖASETTELU:
;   Rivi 0   Otsikko
;   Rivi 2   "gcd(48, 36) = " + tulos desimaalina
;   Rivi 3   "gcd(100,75) = " + tulos desimaalina
;   Rivi 4   "gcd(17, 13) = " + tulos desimaalina
;
; REKISTERIEN KÄYTTÖ (pääohjelma):
;   R0, R1  = gcd-syötteet/tulos (vaihtelevat)
;   R2, R3  = gcd-subroutinen väliaikaiset
;   R4      = 10 (desimaalijakaja write_dec3:lle)
;   R5, R6  = write_nibble-väliaikaiset
;   R8      = VRAM-kirjoitusosoitin
;   R9      = merkkijono-osoitin
;   R10     = väriattribuutti
;   R11     = väliaikainen merkki (write_str)
;   R12     = 0  (nollavakio)
;   R13     = 1  (inkrementtivakio)
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA
; =============================================================================

STR_TITLE:
        .dstr "SUURIN YHTEINEN TEKIJA (GCD)"
STR_UNDER:
        .dstr "============================"

STR_EX1:
        .dstr "gcd(  48,  36) = "
STR_EX2:
        .dstr "gcd( 100,  75) = "
STR_EX3:
        .dstr "gcd(  17,  13) = "

STR_ALGO:
        .dstr "Algoritmi: gcd(a,b) = gcd(b, a mod b)"

; =============================================================================
; ALIOHJELMA: write_str
; =============================================================================
write_str:
        READ  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        ADD   R8, R13
        ADD   R9, R13
        JUMP  write_str
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: write_nibble
; =============================================================================
write_nibble:
        READ  R6, 0x000F
        AND   R5, R6
        READ  R6, 9
        CMP   R5, R6
        JGT   wn_alpha
        READ  R6, 0x0030
        JUMP  wn_store
wn_alpha:
        READ  R6, 0x0037
wn_store:
        ADD   R5, R6
        OR    R5, R10
        STORE [R8], R5
        ADD   R8, R13
        RET

; =============================================================================
; ALIOHJELMA: write_hex4
; =============================================================================
write_hex4:
        CPY   R5, R1
        READ  R6, 12
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        READ  R6, 8
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        READ  R6, 4
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        CALL  write_nibble
        RET

; =============================================================================
; ALIOHJELMA: write_dec3
; Kirjoittaa 3-numeroisen desimaalin (0–999) VRAM:iin.
; Sisään: R1=arvo (0-999), R8=VRAM-osoitin, R10=väri, R4=10, R13=1
; Ulkoon:  R8 += 3  (aina kolme merkkiä kirjoitetaan)
; Käyttää: R2 (väliaikainen)
; Huom: muuttaa R1 (ones-laskennan takia)
; =============================================================================
write_dec3:
        ; Sadat (hundreds): R1 / 100
        READ  R6, 100
        CPY   R2, R1          ; R2 = arvo
        DIV   R2, R6          ; R2 = sadat = arvo / 100
        CPY   R5, R2          ; R5 = sadat (backup)
        MUL   R2, R6          ; R2 = sadat * 100
        SUB   R1, R2          ; R1 = arvo mod 100 (= kymmenet + ykköset)

        ; Kirjoita sadat
        READ  R2, 0x0030      ; '0'
        OR    R5, R2
        OR    R5, R10
        STORE [R8], R5
        ADD   R8, R13

        ; Kymmenet: R1 / 10
        CPY   R2, R1
        DIV   R2, R4          ; R2 = kymmenet (R4=10)
        CPY   R5, R2          ; backup
        MUL   R2, R4          ; R2 = kymmenet * 10
        SUB   R1, R2          ; R1 = ykköset

        READ  R2, 0x0030
        OR    R5, R2
        OR    R5, R10
        STORE [R8], R5
        ADD   R8, R13

        ; Ykköset: R1
        READ  R2, 0x0030
        OR    R1, R2
        OR    R1, R10
        STORE [R8], R1
        ADD   R8, R13
        RET

; =============================================================================
; ALIOHJELMA: gcd
; Eukleideen GCD-algoritmi iteratiivisesti.
; Sisään: R0 = a, R1 = b (molemmat positiivisia)
; Ulkoon: R0 = gcd(a,b), R1 = 0
; Käyttää: R2, R3
; =============================================================================
gcd:
gcd_loop:
        CMP   R1, R12         ; b == 0?
        JZ    gcd_done        ; kyllä → R0 on tulos

        ; Laske jakojäännös: a mod b = a − floor(a/b) * b
        CPY   R2, R0          ; R2 = a
        DIV   R2, R1          ; R2 = floor(a/b)
        MUL   R2, R1          ; R2 = floor(a/b) * b
        SUB   R0, R2          ; R0 = a mod b (uusi b:n arvo)

        ; Vaihda: uusi a = vanha b, uusi b = jakojäännös
        CPY   R3, R1          ; R3 = vanha b (= uusi a)
        CPY   R1, R0          ; R1 = jakojäännös (= uusi b)
        CPY   R0, R3          ; R0 = uusi a

        JUMP  gcd_loop
gcd_done:
        RET                   ; R0 = gcd

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        READ  R12, 0          ; nollavakio
        READ  R13, 1          ; inkrementtivakio
        READ  R4, 10          ; desimaalijakaja write_dec3:lle

        ; --- Otsikko: rivi 0, sarake 25 = 0xF819 ---
        READ  R8, 0xF819
        READ  R9, STR_TITLE
        READ  R10, 0x4300     ; bold keltainen
        CALL  write_str

        ; --- Viiva: rivi 1, sarake 25 = 0xF869 ---
        READ  R8, 0xF869
        READ  R9, STR_UNDER
        READ  R10, 0x0700
        CALL  write_str

        ; --- Algoritmin kuvaus: rivi 9, sarake 20 = 0xFAF4 ---
        READ  R8, 0xFAF4
        READ  R9, STR_ALGO
        READ  R10, 0x0300     ; keltainen
        CALL  write_str

; =============================================================================
; Esimerkki 1: gcd(48, 36) = 12
; Rivi 2, sarake 22 = 0xF8A0 + 22 = 0xF8B6
; Rivi 3, sarake 22 = 0xF8F0 + 22 = 0xF906
; Rivi 4, sarake 22 = 0xF940 + 22 = 0xF956
; (Käytetään sarake 0 yksinkertaisuuden vuoksi)
; =============================================================================

        ; Etiketti: rivi 2, sarake 20 = 0xF8B4
        READ  R8, 0xF8B4
        READ  R9, STR_EX1
        READ  R10, 0x0700     ; valkoinen
        CALL  write_str       ; R8 osoittaa tulospaikalle

        READ  R0, 48
        READ  R1, 36
        CALL  gcd             ; R0 = gcd(48, 36) = 12

        CPY   R1, R0          ; siirrä tulosta R1:een (write_dec3 tarve: ei)
        ; write_dec3 käyttää R1 suoraan
        READ  R10, 0x4200     ; bold vihreä
        CALL  write_dec3      ; kirjoittaa "012" → desimaalinen 12

; =============================================================================
; Esimerkki 2: gcd(100, 75) = 25
; =============================================================================

        READ  R8, 0xF904
        READ  R9, STR_EX2
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 100
        READ  R1, 75
        CALL  gcd             ; R0 = gcd(100, 75) = 25

        CPY   R1, R0
        READ  R10, 0x4200
        CALL  write_dec3

; =============================================================================
; Esimerkki 3: gcd(17, 13) = 1  (alkuluvut)
; =============================================================================

        READ  R8, 0xF954
        READ  R9, STR_EX3
        READ  R10, 0x0700
        CALL  write_str

        READ  R0, 17
        READ  R1, 13
        CALL  gcd             ; R0 = gcd(17, 13) = 1

        CPY   R1, R0
        READ  R10, 0x4200
        CALL  write_dec3

        HALT
