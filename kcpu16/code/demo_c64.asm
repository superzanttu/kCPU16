; =============================================================================
; demo_c64.asm — Commodore 64 -käynnistyssimu
; =============================================================================
;
; KUVAUS:
;   Matkii klassisen Commodore 64:n käynnistysnäyttöä.
;   Täyttää näytön sinisellä taustalla syaanilla tekstillä,
;   tulostaa C64:n klassisen BASIC V2 -tervehdyksen ja jää
;   ikuisesti vilkuttamaan kursoria kuten alkuperäinen C64.
;
; NÄYTTÖASETTELU (80×24, VRAM = $F800):
;
;   Rivi 0–1   tyhjä (sininen tausta)
;   Rivi 2     "    **** COMMODORE 64 BASIC V2 ****"   (sarake 22, valkoinen)
;   Rivi 3     tyhjä
;   Rivi 4     " 64K RAM SYSTEM  38911 BASIC BYTES FREE" (sarake 20, syaani)
;   Rivi 5     tyhjä
;   Rivi 6     "READY."                                 (sarake 22, syaani)
;   Rivi 7     vilkkuva kursori                         (sarake 22)
;   Rivit 8–23 tyhjä (sininen tausta)
;
; VÄRIT (VRAM-sana: bitti 14=bold, 13-11=BG, 10-8=FG, 7-0=ASCII):
;   Tausta:    FG=6 (syaani), BG=4 (sininen), space  → 0x2620
;   Otsikko:   FG=7 (valkoinen), BG=4 (sininen)      → 0x2700
;   Teksti:    FG=6 (syaani), BG=4 (sininen)          → 0x2600
;   Kursori ●: FG=4 (sininen), BG=6 (syaani), space  → 0x3420
;
; VRAM-OSOITTEET:
;   Rivi R, sar. C : $F800 + R*80 + C
;   Rivi 2,  sar 22: $F800 + 182  = $F8B6  ← otsikko
;   Rivi 4,  sar 20: $F800 + 340  = $F954  ← RAM-teksti
;   Rivi 6,  sar 22: $F800 + 502  = $F9F6  ← READY.
;   Rivi 7,  sar 22: $F800 + 582  = $FA46  ← kursori
;
; KESKEYTYKSET:
;   INT 9 (SCTMR, 500 ms): vaihtaa kursorin näkyvyyttä
;
; REKISTERIEN KÄYTTÖ:
;   R2   = taustatäyttöarvo 0x2620 (koko ohjelman ajan)
;   R3   = vakio 1 (VRAM-osoittimen askel, koko ohjelman ajan)
;   R8   = write_str: VRAM-kohde-osoitin (IN/OUT)
;   R9   = write_str: merkkijono-osoitin (IN/OUT)
;   R10  = write_str: väriattribuutti (IN)
;   R11  = write_str: väliaikainen
;   R12  = nollavakio, null-terminaattorin vert. (koko ohjelman ajan)
;   R0, R1 = scratch
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/demo_c64.asm
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; DATA
; =============================================================================

; Kursorin vilkku-tila: 0 = piilotettu, 1 = näkyvä  (vaihdetaan INT 9:ssä)
blink_flag:
        .db 0

; Null-terminoidut merkkijonot (yksi sana per merkki, 0 = loppu)
str_title:
        .dstr "    **** COMMODORE 64 BASIC V2 ****"

str_ram:
        .dstr " 64K RAM SYSTEM  38911 BASIC BYTES FREE"

str_ready:
        .dstr "READY."

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
; ALIOHJELMA: draw_cursor
; =============================================================================
; Piirtää kursorin (näkyvä/piilotettu) blink_flag:n mukaan.
;   Näkyvä (=1): space + FG=4, BG=6  → 0x3420  (käänteinen väri = "solid block")
;   Piilotettu(=0): space + FG=6, BG=4 → 0x2620  (sama kuin tausta)
; Kirjoitusosoite: $FA46  (rivi 7, sarake 22)
; Käyttää: R0, R1
; =============================================================================
draw_cursor:
        READ  R0, [blink_flag]
        READ  R1, 1
        CMP   R0, R1
        JZ    dc_show
dc_hide:
        READ  R0, 0x2620          ; tausta: syaani FG, sininen BG, space
        JUMP  dc_write
dc_show:
        READ  R0, 0x3420          ; kursori: sininen FG, syaani BG, space
dc_write:
        STORE [0xFA46], R0        ; rivi 7, sarake 22
        RET

; =============================================================================
; KELLOKESKEYTYKSEN KÄSITTELIJÄ  (INT 9, laukeaa joka 500 ms)
; =============================================================================
clock_handler:
        ; Vaihda blink_flag: 0 → 1 tai 1 → 0
        READ  R0, [blink_flag]
        READ  R1, 1
        XOR   R0, R1
        STORE [blink_flag], R0

        ; Päivitä kursori
        CALL  draw_cursor

        IRET

; =============================================================================
; MAIN — alustus ja pääsilmukka
; =============================================================================
main:
        ; --- Aseta INT 9 -käsittelijä (kellokeskeytys) ---
        READ  R0, clock_handler
        STORE [0x0009], R0

        ; --- Pysyvät vakiot ---
        READ  R2, 0x2620          ; taustatäyttöarvo (FG=6, BG=4, space)
        READ  R3, 1               ; VRAM-osoittimen askel (1 sana kerrallaan)
        READ  R12, 0              ; nollavakio (null-terminaattorin vertailu)

        ; --- 1) Täytä koko VRAM sinisellä taustalla ---
        READ  R0, 0xF800          ; VRAM-alkuosoite
        READ  R1, 0xFF80          ; VRAM päättyy ennen kernelipinoaluetta
fill_loop:
        STORE [R0], R2
        ADD   R0, R3
        CMP   R0, R1
        JLT   fill_loop

        ; --- 2) Otsikkorivi: "    **** COMMODORE 64 BASIC V2 ****" ---
        ;        Rivi 2, sarake 22 → $F8B6
        ;        Väri: FG=7 (valkoinen), BG=4 (sininen) = 0x2700
        READ  R8, 0xF8B6
        READ  R9, str_title
        READ  R10, 0x2700
        CALL  write_str

        ; --- 3) RAM-rivi: " 64K RAM SYSTEM  38911 BASIC BYTES FREE" ---
        ;        Rivi 4, sarake 20 → $F954
        ;        Väri: FG=6 (syaani), BG=4 (sininen) = 0x2600
        READ  R8, 0xF954
        READ  R9, str_ram
        READ  R10, 0x2600
        CALL  write_str

        ; --- 4) READY.: Rivi 6, sarake 22 → $F9F6 ---
        READ  R8, 0xF9F6
        READ  R9, str_ready
        READ  R10, 0x2600
        CALL  write_str

        ; --- 5) Kursorin alkutila: näkyvä ---
        READ  R0, 1
        STORE [blink_flag], R0
        CALL  draw_cursor

        ; --- 6) Aseta kellokeskeytys 500 ms välein → 1 Hz vilkku ---
        READ  R0, 500
        SCTMR R0

        ; --- 7) Salli laitteistokeskeytykset ---
        STI

; =============================================================================
; PÄÄSILMUKKA — odota ikuisesti keskeytyksiä
; =============================================================================
forever:
        NOP
        JUMP  forever
