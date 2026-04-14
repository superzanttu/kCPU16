; =============================================================================
; demo_screen.asm — lib-screen.asm-kirjaston esittely
; =============================================================================
;
; KUVAUS:
;   Esittelee lib-screen.asm-kirjaston keskeisimmät toiminnot:
;     - scr_cls:        Näytön tyhjennys
;     - scr_set_color:  Väriattribuutin asetus
;     - scr_print:      Null-terminoidun merkkijonon tulostus
;                       (tuki: \n rivinvaihto, \t tabulaattori)
;     - scr_input:      Interaktiivinen syötteen luku käyttäjältä
;
;   DEMOVAIHEET:
;     1. Otsikkosivu usealla värillä ja tabulaattorigridillä
;     2. Käyttäjän nimen kysyminen (scr_input)
;     3. Henkilökohtainen tervehdys sekä väridemo rivikohtaisesti
;     4. "Jatka"-odotus (mikä tahansa näppäin) → uudelleenkäynnistys
;
; GRAFIIKKATILA:
;   A-tila (tekstitila, 80×24). Ohjelma asettaa tilan itse käynnistyessä.
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/demo_screen.asm
;
; REKISTERIEN KÄYTTÖ (main):
;   R0–R3  = lib-screen-kutsujen parametrit / scratch
;   R9     = vakio 1 (pollaussilmikassa)
;   Kaikki muut rekisterit ovat lib-screen-kutsujen sisäisessä käytössä.
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; =============================================================================
; Kirjasto — tekstiterminalitoiminnot
; =============================================================================

        .include "../lib/lib-screen.asm"

; =============================================================================
; Merkkijonodata (null-terminoituja .dstr-merkkijonoja)
; =============================================================================

; --- Otsikko ja rakenne ---
str_title:
        .dstr "=== kCPU16 Screen Library Demo ===\n\n"

str_colors_header:
        .dstr "Supported text colors:\n"

str_white:
        .dstr "  FG=7  White (default)\n"

str_green:
        .dstr "  FG=2  Green\n"

str_yellow:
        .dstr "  FG=3  Yellow\n"

str_cyan:
        .dstr "  FG=6  Cyan\n"

str_red:
        .dstr "  FG=1  Red\n"

str_magenta:
        .dstr "  FG=5  Magenta\n"

str_nl:
        .dstr "\n"

; --- Tabulaattori-demo ---
str_tab_header:
        .dstr "Tab stops (every 8 columns):\n"

str_tab_row:
        .dstr "  Col:\t8\t16\t24\t32\t40\t48\n\n"

; --- Syöte ---
str_input_prompt:
        .dstr "> Enter your name: "

; --- Tervehdys ---
str_hello_prefix:
        .dstr "\nHello, "

str_hello_suffix:
        .dstr "!\n\n"

str_echo_label:
        .dstr "You typed "

str_echo_chars:
        .dstr " character(s).\n\n"

; --- Loppusivu ---
str_separator:
        .dstr "----------------------------------------\n"

str_done:
        .dstr "Demo complete. Press any key to restart.\n"

; --- Syötepuskuri (max 20 merkkiä + null-terminaattori = 21 sanaa) ---
input_buf:
        .dw  0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .dw  0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .dw  0

; =============================================================================
; main — Pääohjelma
;
; Käynnistää A-grafiikkatilan, kutsuu kirjaston toimintoja ja odottaa
; näppäintä ennen uudelleenkäynnistystä.
; =============================================================================

main:
        ; Aseta A-grafiikkatila (tekstitila, 0 = GFX_MODE_A)
        READ  R0, GFX_MODE_A
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

demo_start:
        ; --- Tyhjennä näyttö ja nollaa kursori ---
        CALL  scr_cls

        ; --- Otsikko: keltainen ---
        READ  R0, 0x0300
        CALL  scr_set_color
        READ  R0, str_title
        CALL  scr_print

        ; --- Väridemot --- otsikkorivi valkoisella ---
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_colors_header
        CALL  scr_print

        ; Valkoinen
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_white
        CALL  scr_print

        ; Vihreä
        READ  R0, 0x0200
        CALL  scr_set_color
        READ  R0, str_green
        CALL  scr_print

        ; Keltainen
        READ  R0, 0x0300
        CALL  scr_set_color
        READ  R0, str_yellow
        CALL  scr_print

        ; Syaani
        READ  R0, 0x0600
        CALL  scr_set_color
        READ  R0, str_cyan
        CALL  scr_print

        ; Punainen
        READ  R0, 0x0100
        CALL  scr_set_color
        READ  R0, str_red
        CALL  scr_print

        ; Magenta
        READ  R0, 0x0500
        CALL  scr_set_color
        READ  R0, str_magenta
        CALL  scr_print

        ; --- Tabulaattori-demo: valkoinen ---
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_nl
        CALL  scr_print

        READ  R0, str_tab_header
        CALL  scr_print

        READ  R0, 0x0600
        CALL  scr_set_color
        READ  R0, str_tab_row
        CALL  scr_print

        ; --- Syöte: pyydä käyttäjän nimi ---
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_input_prompt
        READ  R1, input_buf
        READ  R2, 21              ; max 20 merkkiä + null
        CALL  scr_input           ; R0 = luettujen merkkien lukumäärä

        ; Tallenna merkkiluku myöhempää tulostusta varten
        CPY   R3, R0              ; R3 = count

        ; --- Tervehdys: vihreällä ---
        READ  R0, 0x0200
        CALL  scr_set_color
        READ  R0, str_hello_prefix
        CALL  scr_print

        READ  R0, input_buf
        CALL  scr_print

        READ  R0, str_hello_suffix
        CALL  scr_print

        ; --- Merkkilukutieto: valkoisella ---
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_echo_label
        CALL  scr_print

        ; Tulosta merkkiluku numerona (yksinkertainen 1–20 alue → yksi numero tai kaksi)
        ; Kirjoita luku suoraan VRAM:iin käyttäen scr_print-kompatibelia tapaa:
        ; Muunna count numeromerkeiksi tilapufferiin
        ; Käytetään yksinkertaista menetelmää: jos count < 10, yksi merkki; muuten kaksi.
        READ  R0, R3              ; R0 = count
        READ  R1, 10
        CMP   R0, R1
        JLT   _print_single       ; count < 10 → yksi merkki

        ; Kaksi numeroa: kymmenet
        CPY   R2, R0
        DIV   R2, R1              ; R2 = count / 10
        READ  R1, 0x30
        ADD   R2, R1              ; R2 = ASCII '0' + kymmenet
        ; Kirjoita merkki via scr_putchar-tyylinen inline:
        ; Käytetään apupuskuria str_count_buf → ei, yksinkertaisemmin käytämme
        ; kirjasto-funktiota scr_print merkin avulla:
        STORE [count_char0], R2
        READ  R0, count_str0
        CALL  scr_print
        READ  R0, R3
        READ  R1, 10
        CPY   R2, R0
        DIV   R2, R1              ; R2 = kymmenet
        MUL   R2, R1              ; R2 = kymmenet * 10
        SUB   R0, R2              ; R0 = ykkösosa
        READ  R1, 0x30
        ADD   R0, R1              ; R0 = ASCII ykkönen
        STORE [count_char1], R0
        READ  R0, count_str1
        CALL  scr_print
        JUMP  _print_count_done

_print_single:
        ; Yksi numero
        READ  R1, 0x30
        ADD   R0, R1              ; R0 = ASCII-merkki
        STORE [count_char1], R0
        READ  R0, count_str1
        CALL  scr_print

_print_count_done:
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_echo_chars
        CALL  scr_print

        ; --- Erotinrivi + loppuviesti ---
        READ  R0, 0x0700
        CALL  scr_set_color
        READ  R0, str_separator
        CALL  scr_print

        READ  R0, 0x0300
        CALL  scr_set_color
        READ  R0, str_done
        CALL  scr_print

        ; --- Odota näppäintä (ohita release-tapahtumat) ---
_wait_key:
        READ  R0, [KBD_STATUS]
        READ  R1, 0
        CMP   R0, R1
        JZ    _wait_key
        READ  R0, [KBD_DATA]
        READ  R1, KBD_RELEASE_BIT
        AND   R1, R0
        JNZ   _wait_key           ; Vapautustapahtuma → ohita

        ; Uudelleenkäynnistys
        JUMP  demo_start

; --- Tilapuskuri luvun tulostusta varten ---
count_str0:
count_char0:
        .db  0x30                 ; kymmenet-ascii (päivitetään ajon aikana)
        .db  0                    ; null-terminaattori

count_str1:
count_char1:
        .db  0x30                 ; ykkönen-ascii (päivitetään ajon aikana)
        .db  0                    ; null-terminaattori
