; =============================================================================
; screen_hello_fill.asm - Näytön täyttäminen tekstillä
; =============================================================================
;
; KUVAUS:
;   Täyttää koko näyttömuistin (VRAM) toistuvalla tekstillä "HELLO! ".
;   Demonstroi näyttömuistin (Video RAM) käyttöä ja silmukkarakennetta.
;
; NÄYTTÖMUISTI (VRAM):
;   Osoitteet: $F800 - $FF7F (1920 sanaa)
;   Koko: 80 saraketta x 24 riviä = 1920 merkkiä
;   Jokainen sana = merkki + attribuutit
;
; MERKKISANAN RAKENNE (16 bittiä):
;   Bitit 0-7:   ASCII-merkki
;   Bitit 8-12:  Attribuutit (lihavointi, kursiivi, jne.)
;   Bitit 13-15: Värikoodi (0-7)
;
;   Esimerkki: 0xE048 = 1110 0000 0100 1000
;     Väri = 7 (valkoinen), ASCII = 0x48 = 'H'
;
; ALGORITMI:
;   1. Tallenna merkkijono "HELLO! " RAM-muistiin (pattern)
;   2. Käy läpi kaikki 1920 näyttöpaikkaa
;   3. Kopioi kullakin kierroksella yksi merkki patternista
;   4. Kun pattern loppuu, aloita alusta (wrap around)
;
; REKISTERIEN KÄYTTÖ:
;   R0 = Näyttöpointteri (VRAM-osoite, $F800 -> $FF7F)
;   R1 = Jäljellä olevat näyttöpaikat (1920 -> 0)
;   R2 = Pattern-pointteri (nykyinen merkki patternissa)
;   R3 = Vakio 1 (osoittimien kasvatukseen)
;   FP = Väliaikainen merkki
;   SP = Pattern-loppu (vertailuun)
;
; TULOS:
;   Näyttö täynnä tekstiä: "HELLO! HELLO! HELLO! ..."
;
; =============================================================================

        ; -----------------------------------------------
        ; Vaihe 1: Tallenna pattern RAM-alueelle
        ; Pattern: "HELLO! " (7 merkkiä)
        ; Tallennetaan osoitteisiin $0200-$0206
        ;
        ; Merkkiformat: 0xE0XX = valkoinen väri + ASCII
        ; -----------------------------------------------
        JARI  R0, 0xE048      ; 'H' (ASCII 0x48)
        STORE [0x0200], R0  ; [0x0200] = 'H'

        JARI  R0, 0xE045      ; 'E' (ASCII 0x45)
        STORE [0x0201], R0

        JARI  R0, 0xE04C      ; 'L' (ASCII 0x4C)
        STORE [0x0202], R0

        JARI  R0, 0xE04C      ; 'L'
        STORE [0x0203], R0

        JARI  R0, 0xE04F      ; 'O' (ASCII 0x4F)
        STORE [0x0204], R0

        JARI  R0, 0xE021      ; '!' (ASCII 0x21)
        STORE [0x0205], R0

        JARI  R0, 0xE020      ; ' ' (välilyönti, ASCII 0x20)
        STORE [0x0206], R0

        ; -----------------------------------------------
        ; Vaihe 2: Alusta kirjoitussilmukka
        ; -----------------------------------------------
        JARI  R0, 0xF800      ; R0 = VRAM alku
        JARI  R1, 1920        ; R1 = 80 x 24 = 1920 paikkaa
        JARI  R2, 0x0200      ; R2 = pattern alku
        JARI  R3, 1           ; R3 = vakio 1
        JARI  SP, 0x0207      ; SP = pattern loppu (exclusive)

        ; -----------------------------------------------
        ; Merkitse ajon aloitus kirjoittamalla 'S'
        ; (debug-tarkoituksiin)
        ; -----------------------------------------------
        JARI  FP, 0xE053      ; 'S' (Start)
        STORE [0xF8A0], FP  ; Kirjoita rivin 2 alkuun

; =============================================================================
; TÄYTTÖSILMUKKA - Kirjoita "HELLO! " toistuvasti
; =============================================================================
fill_loop:
        ; -----------------------------------------------
        ; Lue merkki patternista ja kirjoita näytölle
        ; -----------------------------------------------
        JARI FP, [R2]  ; FP = [R2] (pattern-merkki)
        STORE [R0], FP  ; [R0] = FP (kirjoita näyttöön)

        ; -----------------------------------------------
        ; Siirry seuraavaan näyttöpaikkaan ja pattern-merkkiin
        ; -----------------------------------------------
        ADD   R0, R3          ; R0++ (seuraava VRAM-osoite)
        ADD   R2, R3          ; R2++ (seuraava pattern-merkki)

        ; -----------------------------------------------
        ; Tarkista onko pattern lopussa
        ; Jos R2 == SP (0x0207), aloita pattern alusta
        ; -----------------------------------------------
        CMP   R2, SP
        JNZ   no_wrap         ; Jos ei lopussa, ohita wrap
        JARI  R2, 0x0200      ; Aloita pattern alusta

no_wrap:
        ; -----------------------------------------------
        ; Vähennä laskuria ja jatka kunnes kaikki 1920 tehty
        ; -----------------------------------------------
        SUB   R1, R3          ; R1-- (jäljellä olevat paikat)
        JNZ   fill_loop       ; Jos R1 != 0, jatka

        ; -----------------------------------------------
        ; Merkitse ajon lopetus kirjoittamalla 'D' (Done)
        ; -----------------------------------------------
        JARI  FP, 0xE044      ; 'D'
        STORE [0xF8A1], FP

        ; -----------------------------------------------
        ; Valmis! Näyttö on nyt täynnä "HELLO! " -tekstiä
        ; -----------------------------------------------
        HALT
