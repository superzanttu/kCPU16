; =============================================================================
; big_clock.asm — Iso pikselikello näytöllä BIG-fontilla
; =============================================================================
;
; KUVAUS:
;   Piirtää kellonajan muodossa HH:MM:SS näytön keskelle käyttäen
;   font_big.asm-tiedoston 6×8-pikselifonttia. Jokainen fonttipikselisi
;   vastaa yhtä VRAM-merkkiä (space + keltainen taustav = kiinteä keltainen lohko).
;   Kellokeskeytys (Int 9) laukeaa 500 ms:n välein ja vaihtaa blink_flag-arvoa,
;   jolloin ':'-merkit vilkkuvat 1 Hz:llä.
;
; NÄYTTÖASETTELU:
;   Näyttö: 80 saraketta × 24 riviä
;   Merkkejä kellossa: HH:MM:SS = 8 isoa merkkiä, kukin 6 pikseliä leveä
;   Kokonaisleveys: 8 × 6 = 48 saraketta
;   Kokonaiskorkeus: 8 riviä (fontin riviluku)
;   Aloitussarake: (80 − 48) / 2 = 16
;   Aloitusrivi:   (24 −  8) / 2 = 8
;   VRAM-kantaosoite: $F800 + 8×80 + 16 = $FA90
;
; PIKSELIKOODAUS (VRAM-sanan rakenne):
;   PIXEL_ON  = 0x1820  välilyönti + keltainen taustav (BG=3, FG=0)
;   PIXEL_OFF = 0x0020  välilyönti + musta taustav (BG=0, FG=0)
;
;   Fonttibitti b (5..0) kuvaa saraketta (5−b):
;     bitti 5 = sarake 0 (vasen)
;     bitti 4 = sarake 1
;     ...
;     bitti 0 = sarake 5 (oikea, aina 0)
;
; REKISTERIEN KÄYTTÖ:
;   draw_clock:              R0–R5 (scratch; delegoi check_and_draw_digit:lle)
;   check_and_draw_digit:    R0 (VRAM-ptr), R1 (uusi idx), R2 (prev-osoite),
;                            R3 (edellinen arvo); delegoi draw_big_char:lle
;   draw_big_char:           R1–R8 (kaikki vapaana)
;   draw_pixel_row:          R9–R14 (kaikki vapaana)
;
; OPTIMOINTI:
;   Jokaista merkkiä (H1 H2 M1 M2 S1 S2) ja blink-tilaa verrataan
;   edelliseen piirrettyyn arvoon (prev_H1…prev_S2, prev_blink).
;   VRAM:iin kirjoitetaan vain muuttuneet merkit.
;
; KESKEYTYKSET:
;   Int 9 (CTMR) joka 500 ms:
;     - vaihtaa blink_flag (0↔1)
;     - kutsuu draw_clock
;
; =============================================================================

        .origin 0x0200

; =============================================================================
; VAKIOT
; =============================================================================

; VRAM-kantaosoite kellolle: rivi 8, sarake 16
; $F800 + 8×80 + 16 = $F800 + $290 = $FA90
.const VRAM_CLOCK_ORIGIN, 0xFA90

; Pikseliarvot VRAM:iin
; PIXEL_ON:  välilyönti + keltainen tausta (BG=3 → bitit 11–13 = 011 → 3<<11 = 0x1800)
; PIXEL_OFF: välilyönti + musta tausta (BG=0)
.const PIXEL_ON,  0x1820
.const PIXEL_OFF, 0x0020

; VRAM-osoitteet jokaiselle merkille (6 pikseliä per merkki)
; VRAM_CLOCK_ORIGIN + merkki_nro × 6
.const VRAM_H1, 0xFA90       ; H1 (tuntien kymmenet)
.const VRAM_H2, 0xFA96       ; H2 (tuntien ykköset)
.const VRAM_C1, 0xFA9C       ; ':' (ensimmäinen, HH:MM)
.const VRAM_M1, 0xFAA2       ; M1 (minuuttien kymmenet)
.const VRAM_M2, 0xFAA8       ; M2 (minuuttien ykköset)
.const VRAM_C2, 0xFAAE       ; ':' (toinen, MM:SS)
.const VRAM_S1, 0xFAB4       ; S1 (sekuntien kymmenet)
.const VRAM_S2, 0xFABA       ; S2 (sekuntien ykköset)

; =============================================================================
; ALUSTUS
; =============================================================================

        ; Aseta kellokeskeytyksen käsittelijä (Int 9 -vektori osoitteeseen $0009)
        LOAD  R0, clock_handler
        STORE [0x0009], R0

        ; blink_flag = 1 → ':' näkyvissä aluksi
        LOAD  R0, 1
        STORE [blink_flag], R0

        ; Ensimmäinen piirto ennen kellokeskeytyksen käynnistystä
        CALL  draw_clock

        ; Käynnistä 500 ms kellokeskeytys (→ 1 Hz vilkku)
        LOAD  R0, 500
        SCTMR R0

        ; Salli keskeytykset
        STI

; =============================================================================
; PÄÄSILMUKKA — odota keskeytyksiä
; =============================================================================
main_loop:
        NOP
        JUMP  main_loop

; =============================================================================
; KELLOKESKEYTYKSEN KÄSITTELIJÄ (Int 9, laukeaa 500 ms välein)
; =============================================================================
clock_handler:
        ; Vaihda blink_flag: 0 → 1 tai 1 → 0
        LOAD  R0, [blink_flag]
        LOAD  R1, 1
        XOR   R0, R1
        STORE [blink_flag], R0

        ; Piirrä kello uudelleen
        CALL  draw_clock

        IRET

; =============================================================================
; draw_clock — Lue HH:MM:SS kellolta, piirrä vain muuttuneet merkit
;
; Vertaa jokaista numeroa (H1 H2 M1 M2 S1 S2) ja blink_flag:ia edelliseen
; piirrettyyn arvoon (prev_H1…prev_S2, prev_blink). Piirtää vain muuttuneet.
;
; Käyttää: R0 (VRAM-ptr), R1 (uusi idx), R2 (prev-osoite), R3–R5 (scratch)
; =============================================================================
draw_clock:
        ; --- HH (tunti) ---
        LOAD  R1, [CLOCK_HOUR]        ; R1 = tunti (0–23)
        LOAD  R2, 10
        CPY   R3, R1
        DIV   R3, R2                  ; R3 = H1 (kymmenet)
        CPY   R4, R3
        MUL   R4, R2
        CPY   R5, R1
        SUB   R5, R4                  ; R5 = H2 (ykköset)
        PUSH  R5                      ; säilytä H2 pinossa

        LOAD  R0, VRAM_H1
        CPY   R1, R3                  ; R1 = H1
        LOAD  R2, prev_H1             ; R2 = prev_H1-osoite
        CALL  check_and_draw_digit

        LOAD  R0, VRAM_H2
        POP   R1                      ; R1 = H2
        LOAD  R2, prev_H2
        CALL  check_and_draw_digit

        ; --- ':'-merkit — piirretään molemmat yhtä aikaa kun blink muuttuu ---
        LOAD  R3, [blink_flag]
        LOAD  R4, [prev_blink]
        CMP   R3, R4
        JZ    dc_skip_colons          ; blink ei muuttunut → ohita
        STORE [prev_blink], R3        ; päivitä edellinen tila
        LOAD  R4, 1
        CMP   R3, R4
        JZ    dc_col_on
        LOAD  R1, 12                  ; ' ' (vilkku pois, fontti-idx 12)
        JUMP  dc_draw_colons
dc_col_on:
        LOAD  R1, 10                  ; ':' (vilkku päällä, fontti-idx 10)
dc_draw_colons:
        LOAD  R0, VRAM_C1
        PUSH  R1                      ; säilytä idx (draw_big_char hävittää R1)
        CALL  draw_big_char
        POP   R1
        LOAD  R0, VRAM_C2
        CALL  draw_big_char
dc_skip_colons:

        ; --- MM (minuutti) ---
        LOAD  R1, [CLOCK_MINUTE]      ; R1 = minuutti (0–59)
        LOAD  R2, 10
        CPY   R3, R1
        DIV   R3, R2                  ; R3 = M1
        CPY   R4, R3
        MUL   R4, R2
        CPY   R5, R1
        SUB   R5, R4                  ; R5 = M2
        PUSH  R5

        LOAD  R0, VRAM_M1
        CPY   R1, R3
        LOAD  R2, prev_M1
        CALL  check_and_draw_digit

        LOAD  R0, VRAM_M2
        POP   R1
        LOAD  R2, prev_M2
        CALL  check_and_draw_digit

        ; --- SS (sekunti) ---
        LOAD  R1, [CLOCK_SECOND]      ; R1 = sekunti (0–59)
        LOAD  R2, 10
        CPY   R3, R1
        DIV   R3, R2                  ; R3 = S1
        CPY   R4, R3
        MUL   R4, R2
        CPY   R5, R1
        SUB   R5, R4                  ; R5 = S2
        PUSH  R5

        LOAD  R0, VRAM_S1
        CPY   R1, R3
        LOAD  R2, prev_S1
        CALL  check_and_draw_digit

        LOAD  R0, VRAM_S2
        POP   R1
        LOAD  R2, prev_S2
        CALL  check_and_draw_digit

        RET

; =============================================================================
; check_and_draw_digit — Piirrä numero vain jos arvo on muuttunut
;
; Sisään:  R0 = VRAM-osoite (top-left tälle merkille)
;          R1 = uusi numeron indeksi (0–9)
;          R2 = "edellinen"-muistisolun osoite (esim. prev_H1)
; Ulos:    – (R0–R14 kaikki mahdollisesti turmeltu)
;
; Toiminta:
;   [R2] == R1  → ei muutosta, palataan välittömästi
;   [R2] != R1  → STORE [R2]=R1, tail-call draw_big_char
; =============================================================================
check_and_draw_digit:
        LOAD  R3, [R2]                ; R3 = edellinen arvo
        CMP   R1, R3                  ; uusi == vanha?
        JZ    cdd_no_change           ; sama → ei piirretä
        STORE [R2], R1                ; päivitä "edellinen"
        JUMP  draw_big_char           ; tail call → draw_big_char:n RET palaa kutsuun
cdd_no_change:
        RET

; =============================================================================
; draw_big_char — Piirrä 6×8 pikselikirjain VRAM:iin
;
; Sisään:  R0 = VRAM-osoite ylhäällä vasemmalla (top-left)
;          R1 = fontti-indeksi (0–12)
; Ulos:    R0 = R0 + 6  (seuraavan merkin aloituspaikka)
;
; Käyttää: R1–R8 vapaasti (ei säilytä niitä kutsujan puolesta)
; Tallentaa R0 väliaikaisesti pinoon palatakseen oikein.
;
; Algoritmi:
;   font_addr = BIG_FONT + R1 * BIG_WORDS_PER_CHAR   (= indeksi * 8)
;   row_start = R0
;   for row_i in 0..7:
;     R5 = MEM[font_addr + row_i]   ; yksi 6-bittinen rivipatroon
;     draw_pixel_row(R0=row_start, R5)
;     row_start += 80
;   paluuarvo R0 = alkuperäinen R0 + 6
; =============================================================================
draw_big_char:
        ; Laske fonttiosoitin: R1 = BIG_FONT + R1 * BIG_WORDS_PER_CHAR
        LOAD  R6, BIG_WORDS_PER_CHAR  ; R6 = 8
        MUL   R1, R6                  ; R1 = indeksi * 8
        LOAD  R6, BIG_FONT            ; R6 = BIG_FONT:n osoite
        ADD   R1, R6                  ; R1 = fontti-datan osoitin

        CPY   R2, R0                  ; R2 = rivin aloitusosoite (row_start)
        LOAD  R3, 8                   ; R3 = rivilaskuri (8 riviä per merkki)
        LOAD  R7, 80                  ; R7 = näyttöleveys (rivin askel)
        LOAD  R8, 1                   ; R8 = vakio 1

        PUSH  R0                      ; tallenna alkuperäinen R0 paluuarvoa varten

dbc_row_loop:
        LOAD  R5, [R1]                ; R5 = rivipikselit (6 bittiä)
        ADD   R1, R8                  ; seuraava fonttibytte

        CPY   R0, R2                  ; R0 = rivin alku
        CALL  draw_pixel_row          ; piirrä 6 pikseliä (R0 += 6 sisäisesti, ei tarvita)
        ADD   R2, R7                  ; row_start += 80

        SUB   R3, R8                  ; rivilaskuri--
        JNZ   dbc_row_loop            ; jatka jos rivejä jäljellä

        POP   R0                      ; palauta alkuperäinen R0
        LOAD  R6, 6
        ADD   R0, R6                  ; R0 += 6 (seuraavan merkin paikka)
        RET

; =============================================================================
; draw_pixel_row — Piirrä 6 pikseliä yhdeltä fonttisanariviltä
;
; Sisään:  R0 = VRAM-osoite (sarakkeen alku)
;          R5 = 6-bittinen rivibitti (bitti 5 = sarake 0, bitti 0 = sarake 5)
; Ulos:    R0 = R0 + 6
;
; Käyttää: R9–R14 vapaasti (ei säilytä niitä)
;
; Huom: bitti 0 (sarake 5) on aina 0 fontissa → kirjoittaa PIXEL_OFF
; =============================================================================
draw_pixel_row:
        LOAD  R9,  5                  ; R9  = bittipaikka (aloitetaan bitistä 5)
        LOAD  R10, 6                  ; R10 = sarakeslurikka (6 saraketta)
        LOAD  R11, 1                  ; R11 = vakio 1
        LOAD  R12, PIXEL_ON           ; R12 = lit-pikselin VRAM-arvo
        LOAD  R13, PIXEL_OFF          ; R13 = tyhjän pikselin VRAM-arvo

dpr_loop:
        CPY   R14, R5                 ; R14 = kopio rivibitistä
        SHR   R14, R9                 ; R14 >>= bittipaikka
        AND   R14, R11                ; R14 &= 1  (eristä yksi bitti)
        JZ    dpr_off
        STORE [R0], R12               ; kirjoita PIXEL_ON
        JUMP  dpr_next
dpr_off:
        STORE [R0], R13               ; kirjoita PIXEL_OFF
dpr_next:
        ADD   R0, R11                 ; R0++  (seuraava sarake)
        SUB   R9, R11                 ; bittipaikka--
        SUB   R10, R11                ; sarakeslurikka--
        JNZ   dpr_loop                ; jatka jos sarakkeita jäljellä

        RET

; =============================================================================
; DATA
; =============================================================================
blink_flag:
        .db 0                         ; vilkkutila: 0 = ':' piilotettu, 1 = ':' näkyvissä
prev_blink:
        .db 0xFF                      ; edellinen blink-tila  (0xFF = ei piirretty)
prev_H1:
        .db 0xFF                      ; edellinen H1  (0xFF = ei piirretty)
prev_H2:
        .db 0xFF
prev_M1:
        .db 0xFF
prev_M2:
        .db 0xFF
prev_S1:
        .db 0xFF
prev_S2:
        .db 0xFF

; =============================================================================
; FONTTILIITOS — BIG_FONT-data sijoittuu tänne koodin perään
; =============================================================================

        .include "font_big.asm"
