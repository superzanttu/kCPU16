; =============================================================================
; demo_keyboard.asm — Interaktiivinen näppäimistödemo
; =============================================================================
;
; KUVAUS:
;   Näyttää jokaisen näppäimistötapahtuman reaaliajassa näytöllä.
;   Hyödyntää INT 6 -keskeytystä (näppäimistö) ja KBD_DATA MMIO:ta.
;
; TOIMINTA:
;   1. Alustetaan näyttö ja rekisterit
;   2. Rekisteröidään INT 6 -käsittelijä (kbd_handler)
;   3. Sallitaan keskeytykset (STI)
;   4. Pääsilmukka odottaa passiivisesti (JUMP idle)
;
; KESKEYTYSRUTIINI (INT 6):
;   - Lukee KBD_DATA (0x0020) MMIO:sta
;   - Bitti 7 = 1 → näppäimen vapautus  (punainen "VAPAUTETTU")
;   - Bitti 7 = 0 → näppäimen painallus (vihreä  "PAINETTU")
;   - Näyttää merkin ja sen heksadesimaalisen koodin
;   - Paina Q (koodi 0x51) lopettaaksesi (HALT)
;
; VRAM-ALUEET:
;   Rivi 0 sarake 28  : Otsikko
;   Rivi 2 sarake 0   : Kehote
;   Rivi 4 sarake 0   : "Merkki:" etiketti + merkki
;   Rivi 5 sarake 0   : "Koodi: " etiketti + hex-arvo
;   Rivi 6 sarake 0   : Tila (PAINETTU / VAPAUTETTU)
;
; REKISTERIEN KÄYTTÖ (globaalit, asetettu main:ssa):
;   R12 = 0  (nollavakio, ei muutu)
;   R13 = 1  (inkrementtivakio, ei muutu)
;
; HUOM: Vaatii TUI-tilan toimiakseen interaktiivisesti.
;       Aja: python main.py run kcpu16/code/demo_keyboard.asm
;
; MMIO-SYMBOLIT (automaattisesti saatavilla):
;   INT_KEYBOARD    = 0x0006  (keskeytyksen vektori)
;   KBD_DATA        = 0x0020  (näppäintapahtuma)
;   KBD_RELEASE_BIT = 0x0080  (vapautusbitti)
;   KBD_KEY_CODE_MASK = 0x007F (nappainkoodi maski)
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA
; =============================================================================

STR_TITLE:
        .dstr "=== NAUPPAIMISTODEMO ==="
STR_PROMPT:
        .dstr "Paina nappia! Q = lopeta."
STR_KEYLBL:
        .dstr "Merkki: "
STR_CODELBL:
        .dstr "Koodi:  0x"
STR_STATLBL:
        .dstr "Tila:   "
STR_PRESS:
        .dstr "PAINETTU    "   ; 12 merkkiä: peittää 12-merkkisen STR_IDLE
STR_RELEASE:
        .dstr "VAPAUTETTU  "   ; 12 merkkiä: peittää 12-merkkisen STR_IDLE
STR_IDLE:
        .dstr "Odotetaan..."

; =============================================================================
; ALIOHJELMA: write_str
; =============================================================================
write_str:
        READ  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        ADD   R8, R13
        ADD   R9, R13
        JUMP  write_str
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: write_nibble
; =============================================================================
write_nibble:
        READ  R6, 0x000F
        AND   R5, R6
        READ  R6, 9
        CMP   R5, R6
        JGT   wn_alpha
        READ  R6, 0x0030
        JUMP  wn_store
wn_alpha:
        READ  R6, 0x0037
wn_store:
        ADD   R5, R6
        OR    R5, R10
        STORE [R8], R5
        ADD   R8, R13
        RET

; =============================================================================
; ALIOHJELMA: write_hex4
; =============================================================================
write_hex4:
        CPY   R5, R1
        READ  R6, 12
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        READ  R6, 8
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        READ  R6, 4
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        CALL  write_nibble
        RET

; =============================================================================
; KESKEYTYSRUTIINI: kbd_handler (INT 6)
; Kutsutaan automaattisesti jokaisesta näppäintapahtumasta.
; R12=0, R13=1 asetetaan pääohjelmassa ennen STI:tä.
; =============================================================================
kbd_handler:
        READ  R0, [KBD_DATA]  ; lue näppäintapahtuma MMIO:sta

        ; Tarkista onko vapautustapahtuma (bitti 7)
        READ  R1, KBD_RELEASE_BIT  ; 0x80
        AND   R1, R0               ; R1 = release_bit & event
        JZ    kh_press             ; Z=1 → bitti ei asetettu → painallus

; --- Vapautus ---
        READ  R8, 0xF9E0      ; rivi 6, sarake 0 = 0xF800 + 6*80 = 0xF9E0
        READ  R9, STR_STATLBL
        READ  R10, 0x0600     ; syaani etiketti
        CALL  write_str
        READ  R9, STR_RELEASE
        READ  R10, 0x0100     ; punainen
        CALL  write_str
        IRET

; --- Painallus ---
kh_press:
        ; Näytä merkki (ASCII bit 6..0)
        READ  R8, 0xF948      ; rivi 4, col 8 = 0xF800+320+8 = 0xF948
        READ  R10, 0x4300     ; bold keltainen
        READ  R5, KBD_KEY_CODE_MASK  ; 0x7F (maskaa release-bitin)
        CPY   R1, R0
        AND   R1, R5          ; R1 = ASCII-koodi
        OR    R1, R10         ; lisää väri
        STORE [R8], R1        ; kirjoita merkki VRAM:iin

        ; Tyhjennä seuraavat paikat (jos edellinen merkki oli leveämpi)
        ADD   R8, R13
        READ  R1, 0x0020      ; välilyönti (BG=0)
        OR    R1, R10
        STORE [R8], R1

        ; Näytä hex-koodi
        READ  R8, 0xF990      ; rivi 5, sarake 0 = 0xF800 + 5*80 = 0xF990
        READ  R9, STR_CODELBL
        READ  R10, 0x0600     ; syaani
        CALL  write_str       ; kirjoittaa "Koodi:  0x", R8 osoittaa sen jälkeen

        READ  R5, KBD_KEY_CODE_MASK
        CPY   R1, R0
        AND   R1, R5          ; R1 = puhdas ASCII-koodi
        READ  R10, 0x4200     ; bold vihreä
        CALL  write_hex4      ; kirjoittaa 4 hex-numeroa

        ; Näytä tila
        READ  R8, 0xF9E0      ; rivi 6, sarake 0
        READ  R9, STR_STATLBL
        READ  R10, 0x0600
        CALL  write_str
        READ  R9, STR_PRESS
        READ  R10, 0x0200     ; vihreä
        CALL  write_str

        ; Paina Q (0x51) → lopeta
        READ  R5, KBD_KEY_CODE_MASK
        CPY   R1, R0
        AND   R1, R5
        READ  R5, 0x0051      ; 'Q'
        CMP   R1, R5
        JZ    kh_quit

        IRET

kh_quit:
        HALT                  ; Q painettu → pysäytä CPU

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        READ  R12, 0          ; nollavakio (write_str käyttää nullin tunnistukseen)
        READ  R13, 1          ; inkrementtivakio

        ; --- Otsikko: rivi 0, sarake 28 = 0xF81C ---
        READ  R8, 0xF81C
        READ  R9, STR_TITLE
        READ  R10, 0x4300     ; bold keltainen
        CALL  write_str

        ; --- Kehote: rivi 2, sarake 27 = 0xF8BB ---
        ; (80-25)/2 = 27, STR_PROMPT = 25 merkkiä
        READ  R8, 0xF8BB
        READ  R9, STR_PROMPT
        READ  R10, 0x0700     ; valkoinen
        CALL  write_str

        ; --- Etiketti "Merkki: ": rivi 4, sarake 0 = 0xF940 ---
        READ  R8, 0xF940
        READ  R9, STR_KEYLBL
        READ  R10, 0x0600     ; syaani
        CALL  write_str

        ; --- Etiketti "Koodi:  0x": rivi 5, sarake 0 = 0xF990 ---
        READ  R8, 0xF990
        READ  R9, STR_CODELBL
        READ  R10, 0x0600
        CALL  write_str

        ; --- "Odotetaan...": rivi 6, sarake 8 = 0xF9E8 ---
        READ  R8, 0xF9E8
        READ  R9, STR_IDLE
        READ  R10, 0x0300     ; keltainen
        CALL  write_str

        ; Rekisteröi INT 6 -käsittelijä
        READ  R0, kbd_handler
        STORE [INT_KEYBOARD], R0   ; INT_KEYBOARD = 0x0006

        ; Salli keskeytykset
        STI

        ; Pääsilmukka: odota passiivisesti keskeytyksiä
idle:
        JUMP  idle
