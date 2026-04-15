; =============================================================================
; lib-screen.asm — Tekstiterminallikirjasto (A-grafiikkatila, 80×24)
; =============================================================================
;
; KUVAUS:
;   Kirjasto A-grafiikkatilan (tekstitila) käyttöön kuten yksinkertainen
;   terminaali: tekstin tulostus automaattisella rivinvaihdolla ja skrollauksella
;   sekä käyttäjän syötteen lukeminen näppäimistöltä.
;
; VAATIMUKSET:
;   - A-grafiikkatila (GFX_MODE_REG = 0). Kirjasto ei tarkista tilaa.
;   - Kutsutaan Kernel-tilasta (scr_input käyttää KBD_MMIO:ta, joka on User-tilassa ok).
;
; TOIMINNOT (julkiset):
;   scr_cls        — Tyhjennä näyttö, nollaa kursori
;   scr_set_color  — Aseta väriattribuutti (R0 = VRAM värisana, bitit 8–14)
;   scr_print      — Tulosta null-terminoitu merkkijono (R0 = osoitin)
;   scr_input      — Lue syöterivin käyttäjältä (R0=kehote, R1=puskuri, R2=max)
;
; TILAMUUTTUJAT (kirjoitettavissa suoraan):
;   scr_cursor_col — Sarake (0–79)
;   scr_cursor_row — Rivi (0–23)
;   scr_color      — Väriattribuutti (VRAM bittikentät 8–14, esim. 0x0700 = valkoinen)
;
; REKISTERIKÄYTTÖ (clobbers):
;   scr_cls:       R0–R2
;   scr_set_color: — (ei yhtään)
;   scr_print:     R0–R3
;   scr_input:     R0–R3  (R0 = paluuarvo: merkkien lukumäärä)
;   Sisäiset apufunktiot (_scr_*): dokumentoitu kunkin yhteydessä.
;
; VÄRIATTRIBUUTIT (scr_color):
;   Bitti 8–10 = edustaväri (FG), 3 bittiä: 0=musta…7=valkoinen
;   Bitti 11–13 = taustaväri (BG), 3 bittiä
;   Bitti 14 = lihavointi
;   Esimerkki: VRAM_FG_SHIFT = 8, COLOR_WHITE = 7
;     valkoinen/musta: 0x0700,  vihreä/musta: 0x0200,  keltainen/musta: 0x0300
;
; ERIKOISMERKIT (scr_print):
;   \n (0x0A) — rivi loppuu, kursori siirtyy seuraavan rivin alkuun
;   \r (0x0D) — ohitetaan (carriage return, ei toimintoa)
;   \t (0x09) — tabulaattori: etenee seuraavaan 8:n monikertaan
;   Muut merkit kirjoitetaan sellaisenaan.
;
; KÄYTTÖESIMERKKI:
;
;   ; Aseta tekstitila
;   READ  R0, 0
;   STORE [GFX_MODE_REG], R0
;
;   ; Aseta väri: vihreä teksti mustalla (FG=2 → 2 << 8 = 0x0200)
;   READ  R0, 0x0200
;   CALL  scr_set_color
;
;   ; Tyhjennä näyttö
;   CALL  scr_cls
;
;   ; Tulosta teksti
;   READ  R0, str_hello
;   CALL  scr_print
;
;   ; Lue syöte
;   READ  R0, str_prompt   ; kehote
;   READ  R1, input_buf    ; puskuriosoite
;   READ  R2, 41           ; max 40 merkkiä + null
;   CALL  scr_input        ; R0 = merkkien lukumäärä
;
;   str_hello:  .dstr "Hei, maailma!\n"
;   str_prompt: .dstr "> "
;   input_buf:  .db 0, 0, 0, ...  ; (41 sanaa varattu)
;
; ARKKITEHTUURIVAKIOT (automaattisesti saatavilla assemblerista):
;   VRAM_START (0xF800), VRAM_END (0xFF7F), VRAM_WORDS (1920)
;   SCREEN_COLS (80), SCREEN_ROWS (24)
;   GFX_MODE_REG (0xFF80), GFX_MODE_A (0)
;   KBD_DATA (0x0020), KBD_STATUS (0x0021)
;   KBD_RELEASE_BIT (0x80), KBD_KEY_CODE_MASK (0x7F)
;
; =============================================================================

; =============================================================================
; TILAMUUTTUJAT
; =============================================================================

scr_cursor_col:
        .db  0          ; Nykyinen sarake (0–79)

scr_cursor_row:
        .db  0          ; Nykyinen rivi (0–23)

scr_color:
        .dw  0x0700     ; Väriattribuutti: FG=7 (valkoinen), BG=0 (musta)

scr_cursor_blink_enabled:
        .db  0          ; 1 = vilkutus käytössä, 0 = pois

scr_cursor_blink_visible:
        .db  0          ; 1 = kursori piirretty ruudulle

scr_cursor_blink_saved_addr:
        .dw  0          ; VRAM-osoite, johon kursori viimeksi piirrettiin

scr_cursor_blink_saved_word:
        .dw  0          ; Alkuperäinen VRAM-sana kursori-solussa

scr_cursor_blink_counter:
        .dw  0          ; Pollauslaskuri vilkutuksen ajoitukseen

scr_cursor_blink_period:
        .dw  6000       ; Togglausväli scr_input-pollauskierroksina

; =============================================================================
; Cursor blink API
;
; scr_cursor_blink_on   — Ota vilkutus käyttöön (näytä kursori heti)
; scr_cursor_blink_off  — Poista vilkutus käytöstä (palauta solu)
; =============================================================================

_scr_cursor_addr:
        ; Out: R0 = VRAM-osoite nykyiselle kursoripaikalle
        PUSH  R1
        PUSH  R2
        READ  R0, [scr_cursor_row]
        READ  R1, SCREEN_COLS
        MUL   R0, R1
        READ  R2, [scr_cursor_col]
        ADD   R0, R2
        READ  R1, VRAM_START
        ADD   R0, R1
        POP   R2
        POP   R1
        RET

_scr_cursor_hide:
        ; Palauta aiemmin korvattu solu, jos kursori näkyy
        PUSH  R0
        PUSH  R1
        READ  R0, [scr_cursor_blink_visible]
        READ  R1, 0
        CMP   R0, R1
        JZ    _sc_hide_done
        READ  R0, [scr_cursor_blink_saved_addr]
        READ  R1, [scr_cursor_blink_saved_word]
        STORE [R0], R1
        READ  R1, 0
        STORE [scr_cursor_blink_visible], R1
_sc_hide_done:
        POP   R1
        POP   R0
        RET

_scr_cursor_show:
        ; Piirrä kursori nykyiseen paikkaan (alaviiva)
        PUSH  R0
        PUSH  R1
        PUSH  R2
        READ  R0, [scr_cursor_blink_visible]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _sc_show_done
        CALL  _scr_cursor_addr
        STORE [scr_cursor_blink_saved_addr], R0
        READ  R1, [R0]
        STORE [scr_cursor_blink_saved_word], R1
        READ  R2, [scr_color]
        READ  R1, 95               ; '_'
        OR    R1, R2
        STORE [R0], R1
        READ  R1, 1
        STORE [scr_cursor_blink_visible], R1
_sc_show_done:
        POP   R2
        POP   R1
        POP   R0
        RET

_scr_cursor_tick:
        ; Togglaa kursori näkyviin/piiloon periodin välein (pollauspohjainen)
        PUSH  R0
        PUSH  R1
        PUSH  R2
        READ  R0, [scr_cursor_blink_enabled]
        READ  R1, 0
        CMP   R0, R1
        JNZ   _sc_tick_count
        CALL  _scr_cursor_hide
        JUMP  _sc_tick_done
_sc_tick_count:
        READ  R0, [scr_cursor_blink_counter]
        READ  R1, 1
        ADD   R0, R1
        STORE [scr_cursor_blink_counter], R0
        READ  R1, [scr_cursor_blink_period]
        CMP   R0, R1
        JLT   _sc_tick_done
        READ  R2, 0
        STORE [scr_cursor_blink_counter], R2
        READ  R0, [scr_cursor_blink_visible]
        CMP   R0, R2
        JZ    _sc_tick_show
        CALL  _scr_cursor_hide
        JUMP  _sc_tick_done
_sc_tick_show:
        CALL  _scr_cursor_show
_sc_tick_done:
        POP   R2
        POP   R1
        POP   R0
        RET

scr_cursor_blink_on:
        PUSH  R0
        READ  R0, 1
        STORE [scr_cursor_blink_enabled], R0
        READ  R0, 0
        STORE [scr_cursor_blink_counter], R0
        CALL  _scr_cursor_hide
        CALL  _scr_cursor_show
        POP   R0
        RET

scr_cursor_blink_off:
        PUSH  R0
        READ  R0, 0
        STORE [scr_cursor_blink_enabled], R0
        STORE [scr_cursor_blink_counter], R0
        CALL  _scr_cursor_hide
        POP   R0
        RET

; =============================================================================
; scr_set_color — Aseta väriattribuutti
;
; Sisään:  R0 = uusi värisana (VRAM bitit 8–14, esim. 0x0700 = valkoinen/musta)
; Ulos:    —
; Clobbers: —
; =============================================================================

scr_set_color:
        STORE [scr_color], R0
        RET

; =============================================================================
; scr_cls — Tyhjennä näyttö ja nollaa kursori
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R2
;
; Tyhjentää koko VRAM:n (0xF800–0xFF7F) arvolla 0 (musta, tyhjä merkki).
; Palauttaa kursorin vasempaan yläkulmaan (0, 0).
; =============================================================================

scr_cls:
        READ  R0, VRAM_START
        READ  R1, VRAM_END
        READ  R2, 0
        FILL  R0, R1, R2            ; VRAM = 0 (musta, null-merkki)
        STORE [scr_cursor_col], R2  ; R2 = 0 → sarake 0
        STORE [scr_cursor_row], R2  ; R2 = 0 → rivi 0
        RET

; =============================================================================
; _scr_scroll — Vieritä näyttöä yhden rivin verran ylöspäin (sisäinen)
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R2  (R3 ja R4 säilytetään push/pop:lla)
;
; Kopioi rivit 1–23 riveille 0–22 (1840 sanaa), tyhjentää rivin 23.
; =============================================================================

_scr_scroll:
        PUSH  R3
        PUSH  R4
        READ  R0, VRAM_START        ; R0 = kohdeosoite (rivi 0 alku)
        READ  R1, VRAM_START        ; R1 = lähdeosoite
        READ  R2, SCREEN_COLS       ; R2 = 80
        ADD   R1, R2                ; R1 = VRAM_START + 80 (rivi 1 alku = 0xF850)
        READ  R2, 1840              ; R2 = laskuri (23 × 80 = 1840 sanaa)
        READ  R4, 1                 ; R4 = askellusarvo
_scr_scroll_copy:
        READ  R3, [R1]              ; R3 = *lähde
        STORE [R0], R3              ; *kohde = R3
        ADD   R0, R4                ; kohde++
        ADD   R1, R4                ; lähde++
        SUB   R2, R4                ; laskuri--
        JNZ   _scr_scroll_copy      ; silmukka kunnes laskuri = 0
        ; R0 = VRAM_START + 1840 = 0xFF30 (rivin 23 ensimmäinen solu)
        ; R2 = 0 (käytetään täyttöarvona)
        READ  R1, VRAM_END          ; R1 = 0xFF7F (VRAM loppu)
        FILL  R0, R1, R2            ; tyhjennä rivi 23 (0xFF30–0xFF7F) arvolla 0
        POP   R4
        POP   R3
        RET

; =============================================================================
; _scr_newline — Rivinvaihto (sisäinen)
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0  (R1 säilytetään push/pop:lla)
;
; Asettaa sarakkeen 0:ksi, kasvattaa riviä 1:llä.
; Jos rivi ylittäisi 23 (SCREEN_ROWS - 1), kutsuu _scr_scroll:ia
; ja pitää rivin arvona 23.
; =============================================================================

_scr_newline:
        PUSH  R1
        READ  R0, 0
        STORE [scr_cursor_col], R0  ; sarake = 0
        READ  R0, [scr_cursor_row]  ; R0 = nykyinen rivi
        READ  R1, 1
        ADD   R0, R1                ; R0 = rivi + 1
        READ  R1, SCREEN_ROWS       ; R1 = 24
        CMP   R0, R1                ; (rivi+1) vs 24
        JLT   _nl_store             ; rivi+1 < 24 → tallennetaan
        ; rivi+1 >= 24 → skrollaus tarvitaan
        CALL  _scr_scroll           ; clobbers R0–R2 (R3,R4 ok)
        READ  R0, SCREEN_ROWS       ; R0 = 24
        READ  R1, 1
        SUB   R0, R1                ; R0 = 23
_nl_store:
        STORE [scr_cursor_row], R0
        POP   R1
        RET

; =============================================================================
; _scr_putchar — Kirjoita yksi merkki kursoriin ja etene (sisäinen)
;
; Sisään:  R0 = ASCII-merkki (bitit 0–7)
; Ulos:    —
; Clobbers: R0–R2  (R1, R2, R3 säilytetään push/pop:lla)
;
; Laskee VRAM-osoitteen: VRAM_START + rivi×80 + sarake.
; Yhdistää merkin scr_color-attribuuttiin (OR).
; Kirjoittaa VRAM:iin ja kasvattaa sarakepointerrista 1:llä.
; Jos sarake ylittää 79, kutsuu _scr_newline:ä.
; =============================================================================

_scr_putchar:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        ; Laske VRAM-osoite: VRAM_START + rivi×SCREEN_COLS + sarake
        READ  R1, [scr_cursor_row]  ; R1 = rivi
        READ  R2, SCREEN_COLS       ; R2 = 80
        MUL   R1, R2                ; R1 = rivi × 80
        READ  R2, [scr_cursor_col]  ; R2 = sarake
        ADD   R1, R2                ; R1 = rivi×80 + sarake
        READ  R2, VRAM_START
        ADD   R1, R2                ; R1 = VRAM-osoite
        ; Yhdistä väri
        READ  R2, [scr_color]       ; R2 = väriattribuutti
        OR    R0, R2                ; R0 = merkki | väri
        STORE [R1], R0              ; kirjoita VRAM:iin
        ; Etene sarake
        READ  R1, [scr_cursor_col]
        READ  R2, 1
        ADD   R1, R2                ; uusi sarake = sarake + 1
        READ  R3, SCREEN_COLS       ; R3 = 80
        CMP   R1, R3                ; uusi sarake vs 80
        JLT   _putchar_ok           ; < 80 → tallennetaan
        ; sarake >= 80: rivinvaihto
        READ  R1, 0
        STORE [scr_cursor_col], R1  ; sarake = 0
        POP   R3
        POP   R2
        POP   R1
        CALL  _scr_newline          ; R0 clobbered; R1 säilytetään _scr_newlinessa
        RET
_putchar_ok:
        STORE [scr_cursor_col], R1  ; tallenna uusi sarake
        POP   R3
        POP   R2
        POP   R1
        RET

; =============================================================================
; _scr_cursor_left — Siirry kursori yhdellä vasemmalle (sisäinen)
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0  (R1 säilytetään push/pop:lla)
;
; Jos sarake > 0: sarake--
; Jos sarake = 0 ja rivi > 0: rivi--, sarake = 79
; Jos sarake = 0 ja rivi = 0: ei toimintoa (jo alussa)
; =============================================================================

_scr_cursor_left:
        PUSH  R1
        READ  R0, [scr_cursor_col]  ; R0 = sarake
        READ  R1, 0
        CMP   R0, R1                ; sarake vs 0
        JZ    _cl_wrap              ; sarake = 0 → mene edelliselle riville
        READ  R1, 1
        SUB   R0, R1                ; sarake--
        STORE [scr_cursor_col], R0
        POP   R1
        RET
_cl_wrap:
        ; sarake = 0: edellinen rivi, sarake = 79
        READ  R0, [scr_cursor_row]
        READ  R1, 0
        CMP   R0, R1                ; rivi = 0?
        JZ    _cl_done              ; jo alussa → ei toimintoa
        READ  R1, 1
        SUB   R0, R1                ; rivi--
        STORE [scr_cursor_row], R0
        READ  R0, SCREEN_COLS       ; R0 = 80
        READ  R1, 1
        SUB   R0, R1                ; R0 = 79
        STORE [scr_cursor_col], R0
_cl_done:
        POP   R1
        RET

; =============================================================================
; _scr_write_noadvance — Kirjoita merkki kursoriin ilman etenemistä (sisäinen)
;
; Sisään:  R0 = ASCII-merkki (bitit 0–7)
; Ulos:    —
; Clobbers: R0  (R1, R2 säilytetään push/pop:lla)
;
; Sama kuin _scr_putchar, mutta ei muuta kursoripaikkaa.
; Käytetään backspace-toiminnossa kirjoittamaan välilyönti poistetun merkin
; tilalle.
; =============================================================================

_scr_write_noadvance:
        PUSH  R1
        PUSH  R2
        READ  R1, [scr_cursor_row]
        READ  R2, SCREEN_COLS
        MUL   R1, R2                ; R1 = rivi × 80
        READ  R2, [scr_cursor_col]
        ADD   R1, R2                ; R1 = rivi×80 + sarake
        READ  R2, VRAM_START
        ADD   R1, R2                ; R1 = VRAM-osoite
        READ  R2, [scr_color]
        OR    R0, R2                ; R0 = merkki | väri
        STORE [R1], R0
        POP   R2
        POP   R1
        RET

; =============================================================================
; scr_print — Tulosta null-terminoitu merkkijono
;
; Sisään:  R0 = osoitin null-terminoituun merkkijonoon
; Ulos:    —
; Clobbers: R0–R3
;
; Käy läpi merkkijonon merkki kerrallaan:
;   0x00 (\0) — pysähtyy
;   0x0A (\n) — rivinvaihto (kutsuu _scr_newline)
;   0x0D (\r) — ohitetaan
;   0x09 (\t) — tabulaattori: kirjoittaa välilyöntejä seuraavaan 8:n
;               sarakemonikertaan (esim. sarake 5 → 3 välilyöntiä → sarake 8)
;   Muut      — kirjoittaa merkin VRAM:iin (kutsuu _scr_putchar)
;
; Rekisteriasetus silmukan aikana:
;   R1 = merkkijono-osoitin (säilyy _scr_putchar:n push/pop:lla)
;   R2 = vakio/tarkistusarvo (luetaan uudelleen joka iteraatiossa)
;   R3 = tabulaattorilaskuri (säilyy _scr_putchar:n push/pop:lla)
; =============================================================================

scr_print:
        PUSH  R1
        PUSH  R2
        PUSH  R3
        CPY   R1, R0                ; R1 = merkkijono-osoitin
_sp_loop:
        READ  R0, [R1]              ; R0 = seuraava merkki
        READ  R2, 0
        CMP   R0, R2                ; merkki = null?
        JZ    _sp_done              ; kyllä → loppu
        READ  R2, 10                ; '\n'
        CMP   R0, R2
        JZ    _sp_nl
        READ  R2, 13                ; '\r'
        CMP   R0, R2
        JZ    _sp_skip              ; ohita CR
        READ  R2, 9                 ; '\t'
        CMP   R0, R2
        JZ    _sp_tab
        ; Tulostettava merkki
        CALL  _scr_putchar          ; R0=merkki; säilyttää R1,R2,R3
        JUMP  _sp_skip              ; etene osoittimessa
_sp_nl:
        CALL  _scr_newline          ; säilyttää R1 (push/pop sisäisesti)
        JUMP  _sp_skip
_sp_tab:
        ; Laske välilyöntien lukumäärä seuraavaan 8:n monikertaan
        READ  R3, [scr_cursor_col]  ; R3 = nykyinen sarake
        READ  R2, 7
        AND   R3, R2                ; R3 = sarake & 7 (etäisyys edellisestä tab-pysäkistä)
        READ  R2, 8
        SUB   R2, R3                ; R2 = spaces = 8 − (sarake & 7)
        CPY   R3, R2                ; R3 = silmukkalasku (säilyy _scr_putchar:n kautta)
_sp_tab_loop:
        READ  R0, 0x20              ; välilyönti
        CALL  _scr_putchar          ; säilyttää R1,R2,R3
        READ  R2, 1
        SUB   R3, R2                ; lasku--
        JNZ   _sp_tab_loop          ; kirjoita seuraavaksi välilyönti jos lasku > 0
        ; langea _sp_skip:iin (laineri voi jäädä pois, koska _sp_skip on heti seuraava)
_sp_skip:
        ; Etene merkkijono-osoitinta
        READ  R2, 1
        ADD   R1, R2                ; osoitin++
        JUMP  _sp_loop
_sp_done:
        POP   R3
        POP   R2
        POP   R1
        RET

; =============================================================================
; scr_input — Lue syötteen käyttäjältä (pollaus, pysäyttävä)
;
; Sisään:  R0 = kehote-merkkijono-osoitin (null-terminoitu; 0 = ei kehotetta)
;          R1 = syötepuskurin osoitin
;          R2 = puskurin maksimikapasiteetti sanoina (sisältää null-terminaattorin)
;              esim. R2 = 41 → max 40 merkkiä + null
; Ulos:    R0 = luettujen merkkien lukumäärä (ilman null-terminaattoria)
; Clobbers: R0–R3
;
; Toiminta:
;   1. Tulostaa kehotteen kutsumalla scr_print.
;   2. Odottaa näppäintapahtumia pollaamalla KBD_STATUS / KBD_DATA.
;   3. Näppäimen vapautustapahtumat ohitetaan (tarkistetaan KBD_RELEASE_BIT).
;   4. ASCII-koodi saadaan: tapahtuma & KBD_KEY_CODE_MASK.
;   5. Enter (0x0D tai 0x0A) lopettaa syötön.
;   6. Backspace (0x08): jos puskurissa on merkkejä, poistaa viimeisen
;      ja pyyhkii sen näytöltä.
;   7. Muut merkit: jos puskuritila riittää, tallennetaan ja kaiutetaan.
;   8. Syötön päätyttyä lisää null-terminaattorin ja siirtyy uudelle riville
;      (jos kursori ei jo ole rivin alussa).
;
; Rekisteriasetus (persistenttirekisterit R9–R13, eivät aliohjelmien kosketettavissa):
;   R9  = buf_ptr_alku   (puskurin osoite alussa, viite)
;   R10 = max_len        (R2:n kopio)
;   R11 = count          (luettujen merkkien lukumäärä, 0 alussa)
;   R12 = 1              (vakio)
;   R13 = write_ptr      (seuraavan kirjoitussanan osoite puskurissa)
;
; Huom: Funkio tyhjentää KBD_STATUS:n pollaamalla — se ei vaadi INT 6 -käsittelijää.
; =============================================================================

scr_input:
        PUSH  R9
        PUSH  R10
        PUSH  R11
        PUSH  R12
        PUSH  R13
        ; Aseta persistenttirekisterit
        CPY   R9,  R1               ; R9  = buf_ptr (alku)
        CPY   R10, R2               ; R10 = max_len
        READ  R11, 0                ; R11 = count = 0
        READ  R12, 1                ; R12 = 1 (vakio)
        CPY   R13, R1               ; R13 = write_ptr (= buf_ptr alussa)
        ; Tulosta kehote (R0 = kehote-osoitin)
        ; scr_print säilyttää R9–R13 (clobbers R0–R3, ei koske R9+)
        CALL  scr_print
_si_poll:
        CALL  _scr_cursor_tick
        ; Pollaa näppäimistöä
        READ  R0, [KBD_STATUS]      ; tapahtumien määrä puskurissa
        READ  R1, 0
        CMP   R0, R1
        JZ    _si_poll              ; 0 tapahtumaa → odota
        READ  R0, [KBD_DATA]        ; Lue tapahtuma (poistaa sen puskurista)
        READ  R1, KBD_RELEASE_BIT   ; 0x80
        AND   R1, R0                ; testaa vapautusbitti
        JNZ   _si_poll              ; vapautustapahtuma → ohita
        READ  R1, KBD_KEY_CODE_MASK ; 0x7F
        AND   R0, R1                ; R0 = ASCII-koodi
        ; Enter (CR tai LF)?
        READ  R1, 13                ; 0x0D = CR
        CMP   R0, R1
        JZ    _si_done
        READ  R1, 10                ; 0x0A = LF
        CMP   R0, R1
        JZ    _si_done
        ; Backspace (0x08)?
        READ  R1, 8
        CMP   R0, R1
        JNZ   _si_printable
        ; --- Backspace ---
        CALL  _scr_cursor_hide
        READ  R1, 0
        CMP   R11, R1               ; count = 0 → ei poistettavaa
        JZ    _si_poll
        ; Pyyhi merkki näytöltä
        CALL  _scr_cursor_left      ; siirry vasemmalle; clobbers R0–R1; R9–R13 OK
        READ  R0, 0x20              ; välilyönti
        CALL  _scr_write_noadvance  ; kirjoita välilyönti kursoriin; R9–R13 OK
        ; Päivitä puskuri ja lasku
        SUB   R13, R12              ; write_ptr--
        SUB   R11, R12              ; count--
        JUMP  _si_poll
_si_printable:
        ; Onko puskuritila täynnä? (count >= max_len − 1)
        CPY   R1, R10               ; R1 = max_len
        SUB   R1, R12               ; R1 = max_len − 1
        CMP   R11, R1               ; count vs (max_len − 1)
        JGE   _si_poll              ; täynnä → ohita
        ; Tallenna merkkiä puskuriin ja kaiuta näytölle
        CALL  _scr_cursor_hide
        STORE [R13], R0             ; buf[count] = merkki (R0 = ASCII)
        ADD   R13, R12              ; write_ptr++
        ADD   R11, R12              ; count++
        CALL  _scr_putchar          ; kaiuta merkki; R0=merkki; R9–R13 OK
        JUMP  _si_poll
_si_done:
        CALL  _scr_cursor_hide
        ; Null-terminoi puskuri
        READ  R0, 0
        STORE [R13], R0
        ; Siirry uudelle riville jos ei jo rivin alussa
        READ  R0, [scr_cursor_col]
        READ  R1, 0
        CMP   R0, R1
        JZ    _si_no_nl
        CALL  _scr_newline          ; siirry seuraavalle riville; R9–R13 OK
_si_no_nl:
        CPY   R0, R11               ; R0 = count (paluuarvo)
        POP   R13
        POP   R12
        POP   R11
        POP   R10
        POP   R9
        RET
