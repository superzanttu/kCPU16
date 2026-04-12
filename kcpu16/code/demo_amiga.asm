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
;   - VILKKUVA punainen kehys tekstin ympärillä (1 Hz)
;   - Kehys näytön yläreunassa
;   - Punaiset virheilmoitukset kehyksen sisällä
;
; NÄYTTÖASETTELU (80×24, VRAM = $F800):
;
;   Rivi 0        kehyksen yläreuna (sarake 8-71, vilkkuva)
;   Rivi 1        teksti 1 + kehyksen sivut (vilkkuvat)
;   Rivi 2        teksti 2 + kehyksen sivut (vilkkuvat)
;   Rivi 3        kehyksen alareuna (sarake 8-71, vilkkuva)
;   Rivit 4-23    musta tausta
;
; VÄRIT (VRAM-sana: bitti 14=bold, 13-11=BG, 10-8=FG, 7-0=ASCII):
;   Tausta:    FG=0 (musta), BG=0 (musta), space              → 0x0020
;   Kehys ON:  space + BG=1 (punainen)                        → 0x0820
;   Kehys OFF: space + BG=0 (musta)                           → 0x0020
;   Teksti:    FG=1 (punainen), BG=0 (musta)                  → 0x0100
;
; VRAM-OSOITTEET:
;   Kehys vasen/oikea: sarakkeet 8 ja 71
;   Kehys ylä/alareuna: rivit 0 ja 3, sarakkeet 8-71
;   Teksti 1: rivi 1, sarake 13
;   Teksti 2: rivi 2, sarake 23
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
; ALIOHJELMA: draw_frame
; =============================================================================
; Piirtää vilkkuvan kehyksen tekstin ympärille näytön yläreunaan.
; Näkyvä (=1): punainen tausta kehysalueella (0x0820)
; Piilotettu (=0): musta tausta samoissa soluissa (0x0020)
;
; Kehysalue:
;   Ylä/alareuna: rivi 0 ja 3, sarakkeet 8-71  (64 solua)
;   Sivut: rivi 1 ja 2, sarakkeet 8 ja 71
;
; Käyttää: R0, R1, R5, R8
; Pysyvät vakiot: R2=0x0020, R3=1, R12=0
; =============================================================================
draw_frame:
        READ  R0, [blink_flag]
        CMP   R0, R12
        JZ    df_hide

df_show:
        READ  R5, 0x0820          ; punainen BG + välilyönti
        JUMP  df_draw

df_hide:
        CPY   R5, R2              ; musta BG + välilyönti

df_draw:
        ; Yläreuna: rivi 0, sarakkeet 8-71
        READ  R8, 0xF808
        READ  R1, 0xF848
df_top_loop:
        STORE [R8], R5
        ADD   R8, R3
        CMP   R8, R1
        JLT   df_top_loop

        ; Alareuna: rivi 3, sarakkeet 8-71
        READ  R8, 0xF8F8
        READ  R1, 0xF938
df_bottom_loop:
        STORE [R8], R5
        ADD   R8, R3
        CMP   R8, R1
        JLT   df_bottom_loop

        ; Sivut: rivi 1 ja 2
        STORE [0xF858], R5        ; rivi 1, sarake 8
        STORE [0xF897], R5        ; rivi 1, sarake 71
        STORE [0xF8A8], R5        ; rivi 2, sarake 8
        STORE [0xF8E7], R5        ; rivi 2, sarake 71

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
        CALL  draw_frame

        IRET

; =============================================================================
; MAIN — alustus ja pääsilmukka
; =============================================================================
main:
        ; --- Aseta INT 9 -käsittelijä (kellokeskeytys) ---
        READ  R0, clock_handler
        STORE [0x0009], R0

        ; --- Pysyvät vakiot ---
        READ  R2, 0x0020          ; musta välilyönti (BG=0, space)
        READ  R3, 1               ; VRAM-osoittimen askel
        READ  R12, 0              ; nollavakio

        ; --- 1) Täytä koko VRAM mustalla taustalla ---
        READ  R0, 0xF800          ; VRAM-alkuosoite
        READ  R1, 0xFF80          ; VRAM päättyy ennen kernelpinoaluetta
fill_loop:
        STORE [R0], R2
        ADD   R0, R3
        CMP   R0, R1
        JLT   fill_loop

        ; --- 2) Kirjoita tekstit (punainen mustalla) ---
        READ  R8, 0xF85D          ; rivi 1, sarake 13
        READ  R9, str_line1
        READ  R10, 0x0100
        CALL  write_str

        READ  R8, 0xF8B7          ; rivi 2, sarake 23
        READ  R9, str_line2
        READ  R10, 0x0100
        CALL  write_str

        ; --- 3) Piirrä kehys alkuun näkyvänä ---
        READ  R0, 1
        STORE [blink_flag], R0
        CALL  draw_frame

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
