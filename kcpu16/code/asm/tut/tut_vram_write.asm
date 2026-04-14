; =============================================================================
; tut_vram_write.asm — Suoran VRAM-kirjoituksen tutoriaali
; =============================================================================
;
; KUVAUS:
;   Osoittaa miten kCPU16:n VRAM-muistikarttaan kirjoitetaan merkkejä
;   ja värikoodeja LOAD + STORE -käskyillä.
;
; VRAM-MUISTI:
;   Osoitteet:  $F800–$FF7F (1920 sanaa = 80 × 24 merkkiä)
;   Kaava:      addr = $F800 + rivi * 80 + sarake
;
; VRAM-SANAN RAKENNE (16 bittiä):
;   Bitit  0– 7 : ASCII-merkki (0x20..0x7E)
;   Bitit  8–10 : Etustaväri FG  0=musta* 1=pun  2=vih  3=kel
;                               4=sin    5=mag   6=sya  7=val
;   Bitit 11–13 : Taustaväri BG  (sama paletti)
;   Bitti 14    : Lihavointi     (1 = päällä)
;   Bitti 15    : Varattu        (kirjoittaminen ok, arvo ignoroidaan)
;
;   * FG=0 näytetään valkoisena kun merkki on ei-tyhjä (oletusväri)
;
; KAAVA VRAM-SANALLE:
;   vram_word = (FG << 8) | (BG << 11) | (bold << 14) | ascii
;
; ESIMERKKEJÄ:
;   0x0748 = FG=7(valkoinen), BG=0(musta),  merkki='H' (0x48)
;   0x0141 = FG=1(punainen),  BG=0(musta),  merkki='A' (0x41)
;   0x0365 = FG=3(keltainen), BG=0(musta),  merkki='e' (0x65)
;   0x0267 = FG=2(vihreä),    BG=0(musta),  merkki='g' (0x67)
;   0x4748 = FG=7(valkoinen), BG=0(musta),  lihavoitu,  merkki='H'
;   0x2748 = FG=7(valkoinen), BG=4(sininen),merkki='H' (0x2000|0x0700|0x48)
;
; STORE-KÄSKYN MUOTO:
;   STORE [R0], R1   — kirjoittaa R1:n arvon OSOITTEESEEN R0
;   (ei STORE [R1], R0 — se kirjoittaisi R0:n osoitteeseen R1!)
;
; =============================================================================

        .origin 0x0100

; =============================================================================
; OSA 1: Kirjoita "Hello!" näytölle eri väreillä
; Rivi 2 (offset 160 = 0xA0): sarakkeet 0–5
; Rivi 2, sarake 0 = 0xF800 + 160 = 0xF8A0
; =============================================================================

        ; 'H' = valkoinen (FG=7: 0x0700 | 0x48 = 0x0748)
        READ  R0, 0xF8A0      ; osoite rivi 2, sarake 0
        READ  R1, 0x0748      ; 'H', FG=7 (valkoinen)
        STORE [R0], R1

        ; 'e' = keltainen (FG=3: 0x0300 | 0x65 = 0x0365)
        READ  R0, 0xF8A1
        READ  R1, 0x0365      ; 'e', FG=3 (keltainen)
        STORE [R0], R1

        ; 'l' = vihreä (FG=2: 0x0200 | 0x6C = 0x026C)
        READ  R0, 0xF8A2
        READ  R1, 0x026C      ; 'l', FG=2 (vihreä)
        STORE [R0], R1

        ; 'l' = syaani (FG=6: 0x0600 | 0x6C = 0x066C)
        READ  R0, 0xF8A3
        READ  R1, 0x066C      ; 'l', FG=6 (syaani)
        STORE [R0], R1

        ; 'o' = punainen (FG=1: 0x0100 | 0x6F = 0x016F)
        READ  R0, 0xF8A4
        READ  R1, 0x016F      ; 'o', FG=1 (punainen)
        STORE [R0], R1

        ; '!' = bold valkoinen (FG=7, bold: 0x4700 | 0x21 = 0x4721)
        READ  R0, 0xF8A5
        READ  R1, 0x4721      ; '!', FG=7, lihavoitu
        STORE [R0], R1

; =============================================================================
; OSA 2: Kirjoita "kCPU16" sinisellä taustalla
; Rivi 4, sarakkeet 0–5 = 0xF940..0xF945
; Sininen tausta: BG=4 → 4<<11 = 0x2000
; Valkoinen teksti: FG=7 → 7<<8 = 0x0700
; Yhdistettynä: 0x2700 | ascii
; =============================================================================

        READ  R0, 0xF940
        READ  R1, 0x276B      ; 'k' (0x6B), valkoinen-sinisellä
        STORE [R0], R1

        READ  R0, 0xF941
        READ  R1, 0x2743      ; 'C' (0x43)
        STORE [R0], R1

        READ  R0, 0xF942
        READ  R1, 0x2750      ; 'P' (0x50)
        STORE [R0], R1

        READ  R0, 0xF943
        READ  R1, 0x2755      ; 'U' (0x55)
        STORE [R0], R1

        READ  R0, 0xF944
        READ  R1, 0x2731      ; '1' (0x31)
        STORE [R0], R1

        READ  R0, 0xF945
        READ  R1, 0x2736      ; '6' (0x36)
        STORE [R0], R1

; =============================================================================
; OSA 3: Silmukka — täytä rivi 6 vaihtuvilla väreillä '@'-merkillä
; Rivi 6, sarake 0–7 = 0xF9E0..0xF9E7
; =============================================================================

        READ  R0, 0xF9E0      ; VRAM-osoitin
        READ  R2, 8           ; 8 merkkiä
        READ  R3, 1           ; inkrementti
        READ  R4, 1           ; väri-indeksi FG, alkaa 1 (ei musta=0)
        READ  R12, 0          ; nollavakio (silmukan vertailu)

fill_loop:
        CMP   R2, R12         ; R2 == 0?
        JZ    fill_done

        ; Rakenna VRAM-sana: '@' (0x40) + FG-väri (bits 8–10)
        READ  R1, 0x0040      ; '@' (0x40)
        CPY   R5, R4          ; R5 = väri-indeksi (1–7)
        READ  R6, 8
        SHL   R5, R6          ; R5 = FG << 8 (siirtää bits 8–10:een)
        OR    R1, R5          ; R1 = FG-attribuutti | '@'
        STORE [R0], R1        ; kirjoita VRAM:iin

        ADD   R0, R3          ; seuraava VRAM-paikka
        ADD   R4, R3          ; seuraava väri-indeksi
        READ  R5, 8
        CMP   R4, R5
        JGT   reset_color     ; R4 > 7 → palaa arvoon 1
        JUMP  fill_cont
reset_color:
        READ  R4, 1           ; kierrä takaisin väri 1:een
fill_cont:
        SUB   R2, R3          ; laskuri--
        JUMP  fill_loop

fill_done:
        HALT

