; =============================================================================
; demo_amiga.asm — Commodore Amiga 500 Guru Mediation Error Simulator
; =============================================================================
;
; KUVAUS:
;   Matkii klassista Commodore Amiga 500:n "Guru Meditation" virhekeytä.
;   Tämä kuuluisa punainen virhe ilmestyi käyttöjärjestelmän törmätessä
;   peruuttamattomaan virheisiin.
;
;   Demo esittää:
;   - VILKKUVA punainen kehys näytön ympärillä (1 Hz)
;   - Musta tausta sisällä
;   - Punaiset virheilmoitukset keskellä
;
; NÄYTTÖASETTELU (80×24, VRAM = $F800):
;
;   Rivi 0        vilkkuva kehys ylä: 80 × "#"
;   Rivi 1        välilyönnit
;   Rivi 2        "Software Failure. Press left mouse button to continue."
;   Rivi 3        "Guru Meditation #80000003.0880AC0"
;   Rivit 4-21    välilyönnit (piilotetun kehyksen väliä)
;   Rivi 22       vilkkuva kehys ala: 80 × "#"
;   Rivi 23       vilkkuva kehys ala: 80 × "#"
;
; VÄRIT (VRAM-sana: bitti 14=bold, 13-11=BG, 10-8=FG, 7-0=ASCII):
;   Tausta:    FG=0 (musta), BG=0 (musta), space              → 0x0020  (musta)
;   Kehys:     FG=1 (punainen), BG=0 (musta), "█" (0xDB)     → 0x01DB  (täyttävä blokki)
;   Teksti:    FG=1 (punainen), BG=0 (musta)                 → 0x0100
;
; VRAM-OSOITTEET:
;   Rivi R: $F800 + R*80
;   Rivi 0:  $F800      ← ylä kehys
;   Rivi 22: $FF00      ← ala kehys
;   Rivi 23: $FF50      ← ala kehys (toinen rivi)
;
; KESKEYTYKSET:
;   INT 9 (SCTMR, 500 ms): vaihtaa vilkkutilan
;
; REKISTERIEN KÄYTTÖ:
;   R2   = taustatäyttöarvo 0x0020 (koko ohjelman ajan)
;   R3   = vakio 1 (VRAM-osoittimen askel, koko ohjelman ajan)
;   R8   = write_str: VRAM-kohde-osoitin (IN/OUT)
;   R9   = write_str: merkkijono-osoitin (IN/OUT)
;   R10  = write_str: väriattribuutti (IN)
;   R11  = write_str: väliaikainen
;   R12  = nollavakio, null-terminaattorin vert. (koko ohjelman ajan)
;   R0, R1 = scratch
;
; KÄYTTÖ:
;   python main.py kcpu16/code/demo_amiga.asm
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; DATA
; =============================================================================

; Vilkkutila: 0 = piilotettu, 1 = näkyvä (vaihdetaan INT 9:ssä)
blink_flag:
        .db 0

; Null-terminoidut merkkijonot
str_line1:
        .dstr "Software Failure. Press left mouse button to continue."

str_line2:
        .dstr "Guru Meditation #80000003.0880AC0"

; =============================================================================
; ALIOHJELMA: write_str
; =============================================================================
; Kirjoittaa null-terminoidun merkkijonon VRAM:iin värillä.
;
; Sisään:
;   R8   = VRAM-kohde-osoitin   (päivitetään)
;   R9   = lähtömerkkijono-osoitin (päivitetään)
;   R10  = väriattribuutti (OR:ataan jokaiseen merkkiin, ei muutu)
; Pysyvät vakiot tarvitaan:
;   R3   = 1
;   R12  = 0
; Käyttää: R11
; =============================================================================
write_str:
ws_loop:
        READ  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        ADD   R8, R3
        ADD   R9, R3
        JUMP  ws_loop
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: draw_border
; =============================================================================
; Piirtää vilkkuvan kehyksen blink_flag:n mukaan.
; Näkyvä (=1): kehys "█" merkeillä, piilossa (=0): välilyönnit
;
; VRAM-osoitteet:
;   Rivi 0:    0xF800 – 0xF84F  (80 sanaa)
;   Rivit 22-23: 0xFEE0 – 0xFF7F  (160 sanaa)
;     Rivi 22: $F800 + 22*80 = $FEE0
;     Rivi 23: $F800 + 23*80 = $FF30
;
; Käyttää: R0, R1, R8
; Pysyvät vakiot: R2=0x0020, R3=1, R4=0x01DB, R12=0
; =============================================================================
draw_border:
        READ  R0, [blink_flag]
        CMP   R0, R12
        JZ    db_hide

db_show:
        ; Rivi 0: kirjoita 80 × "█" osoitteisiin $F800–$F84F
        READ  R8, 0xF800
        READ  R1, 0xF850          ; loppuosoite (eksklusiivinen)
db_show_top:
        STORE [R8], R4
        ADD   R8, R3
        CMP   R8, R1
        JLT   db_show_top

        ; Rivit 22–23: kirjoita 160 × "█" osoitteisiin $FEE0–$FF7F
        READ  R8, 0xFEE0
        READ  R1, 0xFF80          ; loppuosoite
db_show_bot:
        STORE [R8], R4
        ADD   R8, R3
        CMP   R8, R1
        JLT   db_show_bot

        RET

db_hide:
        ; Rivi 0: kirjoita 80 × välilyöntiä
        READ  R8, 0xF800
        READ  R1, 0xF850
db_hide_top:
        STORE [R8], R2
        ADD   R8, R3
        CMP   R8, R1
        JLT   db_hide_top

        ; Rivit 22–23: kirjoita 160 × välilyöntiä
        READ  R8, 0xFEE0
        READ  R1, 0xFF80
db_hide_bot:
        STORE [R8], R2
        ADD   R8, R3
        CMP   R8, R1
        JLT   db_hide_bot

        RET

; =============================================================================
; KELLOKESKEYTYKSEN KÄSITTELIJÄ (INT 9, laukeaa joka 500 ms)
; =============================================================================
clock_handler:
        ; Vaihda blink_flag: 0 → 1 tai 1 → 0
        READ  R0, [blink_flag]
        READ  R1, 1
        XOR   R0, R1
        STORE [blink_flag], R0

        ; Päivitä kehys
        CALL  draw_border

        IRET

; =============================================================================
; MAIN — alustus ja pääsilmukka
; =============================================================================
main:
        ; --- Aseta INT 9 -käsittelijä (kellokeskeytys) ---
        READ  R0, clock_handler
        STORE [0x0009], R0

        ; --- Pysyvät vakiot ---
        READ  R2, 0x0020          ; välilyönti (FG=0, BG=0, space)
        READ  R3, 1               ; VRAM-osoittimen askel
        READ  R4, 0x01DB          ; kehys "█" punainen (täyttävä blokki, 0xDB)
        READ  R12, 0              ; nollavakio

        ; --- 1) Täytä koko VRAM mustalla taustalla ---
        READ  R0, 0xF800          ; VRAM-alkuosoite
        READ  R1, 0xFF80          ; VRAM päättyy ennen kernelpinoaluetta
fill_loop:
        STORE [R0], R2
        ADD   R0, R3
        CMP   R0, R1
        JLT   fill_loop

        ; --- 2) Rivi 2: "Software Failure..." (keskitettävä) ---
        ; Rivi 2 osoite: $F800 + 2*80 = $F8A0
        ; Teksti on noin 51 merkkiä, keskitys: (80-51)/2 = 14 välilyöntiä
        ; Eli alkaa sarakkeesta 14: 0xF8A0 + 14 = 0xF8AE
        READ  R8, 0xF8AE
        READ  R9, str_line1
        READ  R10, 0x0100         ; punainen
        CALL  write_str

        ; --- 3) Rivi 3: "Guru Meditation #80000003..." (keskitettävä) ---
        ; Rivi 3 osoite: $F800 + 3*80 = $F8F0
        ; Teksti on noin 30 merkkiä, keskitys: (80-30)/2 = 25 välilyöntiä
        READ  R8, 0xF909
        READ  R9, str_line2
        READ  R10, 0x0100
        CALL  write_str

        ; --- 4) Kehyksen alkutila: näkyvä ---
        READ  R0, 1
        STORE [blink_flag], R0
        CALL  draw_border

        ; --- 7) Aseta kellokeskeytys 500 ms välein → 1 Hz vilkku ---
        READ  R0, 500
        SCTMR R0

        ; --- 8) Salli laitteistokeskeytykset ---
        STI

; =============================================================================
; PÄÄSILMUKKA — odota ikuisesti keskeytyksiä
; =============================================================================
forever:
        NOP
        JUMP  forever
