; =============================================================================
; color_demo.asm - kCPU16 näytön väridemostraatio
; =============================================================================
;
; KUVAUS:
;   Kirjoittaa VRAM:iin kaikki etusta- ja taustavärin yhdistelmät
;   (8 × 8 = 64) sekä neljä attribuuttitilaa per pari, yhteensä 256
;   eri yhdistelmää:
;     N = normaali          (bitti14=0, bitti15=0)
;     B = lihavoitu         (bitti14=1, bitti15=0)
;     K = vilkkuva          (bitti14=0, bitti15=1)
;     X = lihavoitu+vilkkuva (bitti14=1, bitti15=1)
;   Näyttö toimii tarkistusmatriaalina renderöinnin oikeellisuudelle:
;   näyttömuistiin kirjataan attribuuttimerkki + väri, joten
;   tekstistä näkee mitä muistiin on kirjoitettu.
;
; NÄYTÖN RAKENNE:
;   Rivi 0    Otsikko "kCPU16 COLOR DEMO  N=normal B=bold K=blink X=bold+blink"
;   Rivi 1    Taustavärien (BG) sarakeotsikointi
;             "     BG0  BG1  BG2  BG3  BG4  BG5  BG6  BG7  "
;   Rivit 2–9 Yksi rivi per etustaväri (FG 0=Musta .. 7=Valkoinen)
;             Jokaisen rivin rakenne:
;               "FGx: " (5 merkkiä, valkoinen teksti mustalla)
;               Sitten 8 × "NBKX " (5 merkkiä/ryhmä, väri per ryhmä)
;   Rivit 10–23 Tyhjä (VRAM nollattu oletuksena)
;
; RYHMÄN MERKIT (5 kpl per (FG,BG)-pari):
;   'N' = 0x4E  normaali             VRAM-sana: base_attr | 0x004E
;   'B' = 0x42  lihavoitu (bit14=1)  VRAM-sana: base_attr | 0x4042
;   'K' = 0x4B  vilkkuva (bit15=1)   VRAM-sana: base_attr | 0x804B
;   'X' = 0x58  molemmat  (14+15=1)  VRAM-sana: base_attr | 0xC058
;   ' ' = 0x20  välilyönti           VRAM-sana: base_attr | 0x0020
;               (välilyönnin taustaväri näyttää BG:n ilman tekstiä)
;
; VRAM-SANARAKENNE (16 bittiä):
;   Bitit  0– 7  ASCII-merkki (0x20..0x7E)
;   Bitit  8–10  Etustaväri FG (0=Musta 1=Pun 2=Vih 3=Kel 4=Sin 5=Mag 6=Sya 7=Val)
;   Bitit 11–13  Taustaväri BG (sama paletti)
;   Bitti 14     Lihavointi  (1 = päällä)
;   Bitti 15     Vilkkuminen (1 = päällä)
;
;   base_attr = (FG << 8) | (BG << 11)
;   FG=5 BG=3: (5<<8)|(3<<11) = 0x0500|0x1800 = 0x1D00
;   'N'-merkki: 0x1D00 | 0x4E = 0x1D4E
;   'B'-merkki: 0x1D00 | 0x4042 = 0x5D42
;
; REKISTERIEN KÄYTTÖ:
;   R0   FG-silmukkalaskuri (0–7)
;   R1   BG-silmukkalaskuri (0–7)
;   R2   VRAM-kirjoitusosoitin  (päivitetään koko ajan)
;   R3   Väliaikainen (inkrementit, laskenta, const-arvot)
;   R4   base_attr = (FG<<8)|(BG<<11)  — rakennetaan bg_loop alussa
;   R5   Char+attribuutti vakio kirjoitettavalle merkille
;   R6   Nolla (0) — write_str-kutsuissa null-vertailuun
;   R7   Väliaikainen tallennus laskennassa
;   R8   write_str: VRAM-kohde-osoitin (IN/OUT)
;   R9   write_str: Lähteen char-osoitin (IN/OUT)
;   R10  write_str: Väriattribuutti (IN, ei muutu)
;   R11  write_str: Väliaikainen char-luku
;   --- SP, FP: ei koskaan käytetä ohjelman logiikassa ---
;       SP:tä tarvitsee CALL/RET ja EXIT-keskeytys → ei saa ylikirjoittaa.
;
; =============================================================================

        .origin 0x0100

        JUMP  main              ; Hyppää datan ja aliohjelmaesimerkkien yli

; =============================================================================
; MERKKIJONODATA (null-terminoitu, .dstr = yksi sana per merkki + 0-terminaattori)
; =============================================================================

TITLE_STR:
        .dstr "kCPU16 COLOR DEMO  N=normal B=bold K=blink X=bold+blink"

BG_HEADER_STR:
        .dstr "     BG0  BG1  BG2  BG3  BG4  BG5  BG6  BG7  "

; =============================================================================
; write_str — Kirjoita null-terminoitu merkkijono VRAM:iin
; =============================================================================
; Parametrit:
;   R8   VRAM-kohde-osoitin (IN/OUT — päivitetään viimeisenkirjoitetun jälkeen)
;   R9   Lähde-osoitin char-dataan (IN/OUT — päivitetään)
;   R10  Väriattribuutti (IN — OR:ataan jokaisen char:n kanssa, ei muutu)
; Turmelee: R11
; Käyttää R12 nollana (nollataan subroutinen alussa)
; =============================================================================
write_str:
        LOAD  R12, 0            ; R12 = 0  (null-terminaattorin vertailuarvo)
ws_loop:
        LOAD  R11, [R9]         ; R11 = seuraava merkki lähteestä
        CMP   R11, R12          ; R11 == 0?
        JZ    ws_done           ; Kyllä → lopeta
        OR    R11, R10          ; R11 = väri | merkki
        STORE [R8], R11         ; Kirjoita VRAM:iin
        LOAD  R11, 1            ; R11 = 1 (inkrementti)
        ADD   R8, R11           ; VRAM-osoitin++
        ADD   R9, R11           ; Lähde-osoitin++
        JUMP  ws_loop
ws_done:
        RET

; =============================================================================
; main — Ohjelman aloitus
; =============================================================================
main:
        ; ----------------------------------------------------------------
        ; Rivi 0: Otsikkorivi
        ; Kohde: VRAM 0xF800 (rivi 0), väri: valkoinen/musta = 0x0700
        ; ----------------------------------------------------------------
        LOAD  R8, 0xF800        ; VRAM-osoitin rivi 0
        LOAD  R9, TITLE_STR     ; Lähde: otsikko
        LOAD  R10, 0x0700       ; Väri: FG=7(val) BG=0(mus)
        CALL  write_str

        ; ----------------------------------------------------------------
        ; Rivi 1: BG-sarakeotsikointi
        ; Kohde: VRAM 0xF850 (rivi 1 = 0xF800 + 80)
        ; ----------------------------------------------------------------
        LOAD  R8, 0xF850        ; VRAM-osoitin rivi 1
        LOAD  R9, BG_HEADER_STR
        LOAD  R10, 0x0700       ; Väri: valkoinen/musta
        CALL  write_str

        ; ================================================================
        ; FG-SILMUKKA: Rivit 2–9, yksi FG-arvo per rivi
        ;
        ; Rivin osoite = 0xF800 + rivi*80
        ;   Rivi 2 → 0xF8A0  (0xF800 + 160)
        ;   Rivi 9 → 0xFAD0  (0xF800 + 720)
        ; ================================================================
        LOAD  R0, 0             ; FG = 0
        LOAD  R2, 0xF8A0        ; VRAM-osoitin → rivi 2

fg_loop:
        ; ----------------------------------------------------------------
        ; Kirjoita FG-tunniste: "FGx: " (5 merkkiä, valkoinen/musta)
        ;   'F' = 0x46  → 0x0746
        ;   'G' = 0x47  → 0x0747
        ;   '0'+FG      → 0x0730 + FG  (FG=0..7 → '0'..'7')
        ;   ':' = 0x3A  → 0x073A
        ;   ' ' = 0x20  → 0x0720
        ; ----------------------------------------------------------------
        LOAD  R3, 0x0746        ; 'F' (valkoinen)
        STORE [R2], R3
        LOAD  R3, 1
        ADD   R2, R3            ; R2++

        LOAD  R3, 0x0747        ; 'G' (valkoinen)
        STORE [R2], R3
        LOAD  R3, 1
        ADD   R2, R3

        LOAD  R3, 0x0730        ; '0' pohja (valkoinen)
        ADD   R3, R0            ; R3 = '0'+FG (0x0730..0x0737)
        STORE [R2], R3
        LOAD  R3, 1
        ADD   R2, R3

        LOAD  R3, 0x073A        ; ':' (valkoinen)
        STORE [R2], R3
        LOAD  R3, 1
        ADD   R2, R3

        LOAD  R3, 0x0720        ; ' ' (valkoinen)
        STORE [R2], R3
        LOAD  R3, 1
        ADD   R2, R3            ; R2 = rivin alku + 5

        ; ================================================================
        ; BG-SILMUKKA: 8 ryhmää per rivi (BG = 0..7)
        ; Jokaiselle (FG,BG)-parille kirjoitetaan 5 merkkiä: "NBKX "
        ;
        ; base_attr = (FG × 256) | (BG × 2048)
        ;   FG×256  = FG << 8   (siirto 8 = MUL 256)
        ;   BG×2048 = BG << 11  (siirto 11 = MUL 2048)
        ; Laskenta käyttää tilapäismuistia 0x0300 (varattu tähän).
        ;
        ; Char+attr vakiot (OR:ataan base_attr:in kanssa):
        ;   'N' normaali:    R5 = 0x004E
        ;   'B' lihavoitu:   R5 = 0x4042  (bit14=bold, ascii=0x42='B')
        ;   'K' vilkkuva:    R5 = 0x804B  (bit15=blink, ascii=0x4B='K')
        ;   'X' molemmat:    R5 = 0xC058  (bit14+15, ascii=0x58='X')
        ;   ' ' välilyönti:  R5 = 0x0020  (näyttää BG-värin)
        ; ================================================================
        LOAD  R1, 0             ; BG = 0

bg_loop:
        ; ---- Laske base_attr = FG*256 | BG*2048 → R4 ----
        ; Vaihe 1: R4 = FG * 256  (= FG << 8)
        CPY   R4, R0            ; R4 = FG
        LOAD  R3, 256
        MUL   R4, R3            ; R4 = FG << 8

        ; Vaihe 2: Tallenna FG<<8, laske BG*2048
        STORE [0x0300], R4      ; Tallenna FG<<8 tilapäismuistiin
        CPY   R4, R1            ; R4 = BG
        LOAD  R3, 2048
        MUL   R4, R3            ; R4 = BG << 11

        ; Vaihe 3: R4 = base_attr = FG<<8 | BG<<11
        LOAD  R7, [0x0300]      ; R7 = FG<<8
        OR    R4, R7            ; R4 = base_attr

        ; ---- Kirjoita 5 merkkiä ryhmälle (FG, BG) ----

        ; 'N' normaali — bitit 14–15 = 0, ascii = 0x4E
        LOAD  R5, 0x4E
        OR    R5, R4            ; R5 = base_attr | 'N'
        STORE [R2], R5
        LOAD  R3, 1
        ADD   R2, R3

        ; 'B' lihavoitu — bit14=1, ascii = 0x42 → vakio = 0x4042
        LOAD  R5, 0x4042
        OR    R5, R4            ; R5 = base_attr | bold | 'B'
        STORE [R2], R5
        LOAD  R3, 1
        ADD   R2, R3

        ; 'K' vilkkuva — bit15=1, ascii = 0x4B → vakio = 0x804B
        LOAD  R5, 0x804B
        OR    R5, R4            ; R5 = base_attr | blink | 'K'
        STORE [R2], R5
        LOAD  R3, 1
        ADD   R2, R3

        ; 'X' molemmat — bit14+15=1, ascii = 0x58 → vakio = 0xC058
        LOAD  R5, 0xC058
        OR    R5, R4            ; R5 = base_attr | bold+blink | 'X'
        STORE [R2], R5
        LOAD  R3, 1
        ADD   R2, R3

        ; ' ' välilyönti — näyttää BG-värin
        LOAD  R5, 0x20
        OR    R5, R4            ; R5 = base_attr | ' '
        STORE [R2], R5
        LOAD  R3, 1
        ADD   R2, R3            ; R2 = rivin alku + 5 + (BG+1)*5

        ; ---- BG-laskuri ----
        LOAD  R3, 1
        ADD   R1, R3            ; BG++
        LOAD  R3, 8
        CMP   R1, R3            ; BG == 8?
        JNZ   bg_loop           ; Ei → seuraava BG-ryhmä

        ; Kaikki 8 BG-ryhmää kirjoitettu. R2 = rivin alku + 5 + 40 = rivin alku + 45
        ; Siirry seuraavan rivin alkuun: +35  (koska 80 - 45 = 35)
        LOAD  R3, 35
        ADD   R2, R3            ; R2 → seuraavan rivin alkuun

        ; ---- FG-laskuri ----
        LOAD  R3, 1
        ADD   R0, R3            ; FG++
        LOAD  R3, 8
        CMP   R0, R3            ; FG == 8?
        JNZ   fg_loop           ; Ei → seuraava FG-rivi

        ; ================================================================
        ; Kaikki 8×8×4 = 256 kombinaatiota kirjoitettu. Lopetus.
        ; ================================================================
        EXIT
