; =============================================================================
; keyboard_demo.asm — Näppäimistön käyttöesimerkki
; =============================================================================
;
; Ohjelma tulostaa painetut näppäimet VRAM-näytölle vasemmasta yläkulmasta.
; Jokainen painallus siirtää osoitinta eteenpäin. Vapautukset ohitetaan.
;
; Toimii yhdessä TUI:n (tai muun syötelähteen) kanssa, joka kutsuu
; KeyboardDevice.push_key() / push_key_release() laitteelle.
;
; REKISTERIEN KÄYTTÖ:
;   R0  = luettu näppäintapahtuma (KBD_DATA)
;   R1  = bitti-7-testi (KBD_RELEASE_BIT) / VRAM-sana
;   R2  = VRAM-kirjoitusosoitin (alkaa VRAM_START:sta)
;   R3  = näppäinkoodi ilman vapautusbittiä (maskattuna)
;   R4  = INT 6 -käsittelijan osoite
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/keyboard_demo.asm
;
; =============================================================================

        .origin 0x0200

; --- Alustus ------------------------------------------------------------------

start:
        ; Aseta INT 6 (näppäimistö) -käsittelija
        LOAD  R4, kbd_handler
        STORE [INT_KEYBOARD], R4    ; vektoriosoite 6 ← käsittelija

        ; Alusta VRAM-kirjoitusosoitin näytön vasempaan yläkulmaan
        LOAD  R2, VRAM_START        ; R2 = 0xF800

        ; Salli keskeytykset
        STI

; --- Pääsilmukka (odota keskeytyksiä) ----------------------------------------

idle:
        JUMP  idle                  ; pyöri paikallaan — keskeytykset hoitavat työn

; --- INT 6: näppäimistökäsittelija -------------------------------------------
;
; Kutsutaan aina kun näppäintapahtuma on saatavilla.
; Ohittaa vapautukset ja piirtää painallukset näytölle.
;
kbd_handler:
        LOAD  R0, [KBD_DATA]        ; lue ja poista tapahtuma puskurista

        ; Tarkista onko bitti 7 asetettu (= vapautus)
        LOAD  R1, KBD_RELEASE_BIT   ; R1 = 0x80
        AND   R1, R0                ; R1 = R0 & 0x80
        JNZ   kbd_done              ; bitti 7 = 1 → vapautus, ohita

        ; Painallus: maskaa pois bitti 7, jotta saadaan pelkkä näppäinkoodi
        LOAD  R3, KBD_KEY_CODE_MASK ; R3 = 0x7F
        AND   R3, R0                ; R3 = näppäinkoodi (0–127)

        ; Laadi VRAM-sana: ASCII-merkki valkoisella värillä (FG=7)
        ;   Väriattribuutti: FG=7 (valkoinen) → 0x0700
        ;   VRAM-sana = väri | merkki = 0x0700 | R3
        LOAD  R1, 0x0700            ; valkoinen edusta, musta tausta
        OR    R1, R3                ; R1 = VRAM-sana

        ; Kirjoita merkki näytölle ja siirry seuraavaan paikkaan
        STORE [R2], R1
        ADD   R2, 1

        ; Älä mene VRAM:n yli — aloita alusta jos täynnä
        LOAD  R1, VRAM_END
        CMP   R2, R1
        JGT   reset_cursor

kbd_done:
        IRET                        ; palaa keskeytyksestä

reset_cursor:
        LOAD  R2, VRAM_START        ; aloita alusta
        JUMP  kbd_done
