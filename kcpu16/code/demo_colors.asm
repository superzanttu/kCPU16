; =============================================================================
; color_demo.asm - kCPU16 näytön väridemostraatio
; =============================================================================
;
; KUVAUS:
;   Kirjoittaa VRAM:iin kaikki etusta- ja taustavärin yhdistelmät
;   (8 × 8 = 64) kahdella attribuuttitilalla per pari:
;     N = normaali   (bitti14=0)
;     B = lihavoitu  (bitti14=1)
;   Näyttö toimii tarkistusmateriaalina renderöinnin oikeellisuudelle:
;   teksti kertoo mitä muistiin on kirjoitettu, väri näyttää miten se
;   renderöidään.
;
; HUOM: Bitti 15 ("vilkkuminen") on poistettu arkkitehtuurista.
;       Arvo ignorataan renderöinnissä. Bitti on varattu tulevaa
;       käyttöä varten.
;
; NÄYTÖN RAKENNE:
;   Rivi 0    Otsikko "kCPU16 COLOR DEMO  N=normal B=bold"
;   Rivi 1    Taustavärien (BG) sarakeotsikointi
;             "     BG0 BG1 BG2 BG3 BG4 BG5 BG6 BG7 "
;   Rivit 2–9 Yksi rivi per etustaväri (FG 0=Musta .. 7=Valkoinen)
;             Jokaisen rivin rakenne:
;               "FGx: " (5 merkkiä, valkoinen teksti mustalla)
;               Sitten 8 × "NB " (3 merkkiä/ryhmä, väri per ryhmä)
;   Rivit 10–23 Tyhjä (VRAM nollattu oletuksena)
;
; RYHMÄN MERKIT (3 kpl per (FG,BG)-pari):
;   'N' = 0x4E  normaali              VRAM-sana: base_attr | 0x004E
;   'B' = 0x42  lihavoitu (bit14=1)   VRAM-sana: base_attr | 0x4042
;   ' ' = 0x20  välilyönti            VRAM-sana: base_attr | 0x0020
;               (välilyönnin taustaväri näyttää BG:n ilman tekstiä)
;
; VRAM-SANARAKENNE (16 bittiä):
;   Bitit  0– 7  ASCII-merkki (0x20..0x7E)
;   Bitit  8–10  Etustaväri FG (0=Musta 1=Pun 2=Vih 3=Kel 4=Sin 5=Mag 6=Sya 7=Val)
;   Bitit 11–13  Taustaväri BG (sama paletti)
;   Bitti 14     Lihavointi  (1 = päällä)
;   Bitti 15     Varattu     (0 — kirjoittaminen sallittu, lukeminen ignorataan)
;
;   base_attr = (FG << 8) | (BG << 11)  = (FG * 256) | (BG * 2048)
;
; REKISTERIEN KÄYTTÖ:
;   R0   FG-silmukkalaskuri (0–7)
;   R1   BG-silmukkalaskuri (0–7)
;   R2   VRAM-kirjoitusosoitin  (päivitetään koko ajan)
;   R3   Väliaikainen (inkrementit, laskenta, const-arvot)
;   R4   base_attr = (FG<<8)|(BG<<11)  — rakennetaan bg_loop alussa
;   R5   Char+attribuutti arvo kirjoitettavalle merkille
;   R7   Väliaikainen tallennus laskennassa
;   R8   write_str: VRAM-kohde-osoitin (IN/OUT)
;   R9   write_str: Lähteen char-osoitin (IN/OUT)
;   R10  write_str: Väriattribuutti (IN, ei muutu)
;   R11  write_str: Väliaikainen char-luku
;   R12  write_str: Nollavakio (null-terminaattorin vertailu)
;   --- SP, FP: ei koskaan käytetä ohjelman logiikassa ---
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA (null-terminoitu, .dstr = yksi sana per merkki + 0)
; =============================================================================

TITLE_STR:
        .dstr "kCPU16 COLOR DEMO  N=normal B=bold"

BG_HEADER_STR:
        .dstr "     BG0 BG1 BG2 BG3 BG4 BG5 BG6 BG7 "

; =============================================================================
; write_str — Kirjoita null-terminoitu merkkijono VRAM:iin
; =============================================================================
; Parametrit:
;   R8   VRAM-kohde-osoitin (IN/OUT)
;   R9   Lähde-osoitin char-dataan (IN/OUT)
;   R10  Väriattribuutti — OR:ataan jokaiseen merkkiin (IN, ei muutu)
; Turmelee: R11, R12
; =============================================================================
write_str:
        READ  R12, 0
ws_loop:
        READ  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        READ  R11, 1
        ADD   R8, R11
        ADD   R9, R11
        JUMP  ws_loop
ws_done:
        RET

; =============================================================================
; main
; =============================================================================
main:
        ; ----------------------------------------------------------------
        ; Rivi 0: Otsikkorivi  (VRAM 0xF800)
        ; ----------------------------------------------------------------
        READ  R8, 0xF800
        READ  R9, TITLE_STR
        READ  R10, 0x0700       ; FG=7 (val), BG=0 (mus)
        CALL  write_str

        ; ----------------------------------------------------------------
        ; Rivi 1: BG-sarakeotsikointi  (VRAM 0xF850 = 0xF800 + 80)
        ; ----------------------------------------------------------------
        READ  R8, 0xF850
        READ  R9, BG_HEADER_STR
        READ  R10, 0x0700
        CALL  write_str

        ; ================================================================
        ; FG-SILMUKKA: Rivit 2–9
        ; Rivin n osoite = 0xF800 + n*80
        ;   Rivi 2 → 0xF8A0  (0xF800 + 160)
        ;   Rivi 9 → 0xFAD0  (0xF800 + 720)
        ; ================================================================
        READ  R0, 0             ; FG = 0
        READ  R2, 0xF8A0        ; VRAM → rivi 2

fg_loop:
        ; ----------------------------------------------------------------
        ; Kirjoita FG-tunniste "FGx: " (5 merkkiä, valkoinen/musta)
        ; ----------------------------------------------------------------
        READ  R3, 0x0746        ; 'F' (valkoinen)
        STORE [R2], R3
        READ  R3, 1 ; ADD R2, 1
        ADD   R2, R3

        READ  R3, 0x0747        ; 'G' (valkoinen)
        STORE [R2], R3
        READ  R3, 1
        ADD   R2, R3

        READ  R3, 0x0730        ; '0' pohja
        ADD   R3, R0            ; R3 = '0' + FG
        STORE [R2], R3
        READ  R3, 1
        ADD   R2, R3

        READ  R3, 0x073A        ; ':'
        STORE [R2], R3
        READ  R3, 1
        ADD   R2, R3

        READ  R3, 0x0720        ; ' '
        STORE [R2], R3
        READ  R3, 1
        ADD   R2, R3            ; R2 = rivin alku + 5

        ; ================================================================
        ; BG-SILMUKKA: 8 ryhmää per rivi (BG = 0..7)
        ; Jokaiselle (FG,BG)-parille kirjoitetaan 3 merkkiä: "NB "
        ;
        ; base_attr = (FG * 256) | (BG * 2048)
        ; ================================================================
        READ  R1, 0             ; BG = 0

bg_loop:
        ; ---- Laske base_attr → R4 ----
        CPY   R4, R0
        READ  R3, 256
        MUL   R4, R3            ; R4 = FG << 8

        STORE [0x0300], R4      ; Tallenna FG<<8 tilapäismuistiin
        CPY   R4, R1
        READ  R3, 2048
        MUL   R4, R3            ; R4 = BG << 11

        READ  R7, [0x0300]
        OR    R4, R7            ; R4 = base_attr

        ; 'N' normaali
        READ  R5, 0x4E
        OR    R5, R4
        STORE [R2], R5
        READ  R3, 1
        ADD   R2, R3

        ; 'B' lihavoitu  (bit14=1, ascii=0x42 → 0x4042)
        READ  R5, 0x4042
        OR    R5, R4
        STORE [R2], R5
        READ  R3, 1
        ADD   R2, R3

        ; ' ' välilyönti — näyttää BG-värin
        READ  R5, 0x20
        OR    R5, R4
        STORE [R2], R5
        READ  R3, 1
        ADD   R2, R3            ; R2 = rivin alku + 5 + (BG+1)*3

        ; ---- BG-laskuri ----
        READ  R3, 1
        ADD   R1, R3            ; BG++
        READ  R3, 8
        CMP   R1, R3
        JNZ   bg_loop

        ; Kirjoitettiin 5 + 8*3 = 29 merkkiä. Siirry seuraavaan riviin: +51
        READ  R3, 51
        ADD   R2, R3

        ; ---- FG-laskuri ----
        READ  R3, 1
        ADD   R0, R3            ; FG++
        READ  R3, 8
        CMP   R0, R3
        JNZ   fg_loop

        EXIT
