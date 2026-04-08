; =============================================================================
; countdown.asm - Laskuri alaspäin silmukalla
; =============================================================================
;
; KUVAUS:
;   Demonstroi silmukkarakennetta (loop) käyttäen SUB ja JNZ -käskyjä.
;   Laskee R0:n arvon 10:stä 0:aan ja tulostaa jokaisen arvon näytölle.
;
; SILMUKKARAKENNE:
;   loop:
;       SUB R0, R1          ; Vähennä laskurista 1
;       ... (tulosta arvo)
;       CMP R0, FP          ; Vertaa: onko R0 == 0?
;       JNZ loop            ; Jos ei, hyppää takaisin loop-labeliin
;
; REKISTERIEN KÄYTTÖ:
;   R0 = Laskuri (10 -> 0)
;   R1 = Askelkoko (1)
;   R2 = Näyttöpointteri (kasvaa jokaisella tulostuksella)
;   R3 = Väliaikainen merkki
;   FP = Väliaikainen vertailuarvo
;
; NÄYTTÖ:
;   Tulostaa: "10 9 8 7 6 5 4 3 2 1 0 "
;   Jokainen numero on erillinen merkki + välilyönti
;
; TULOS:
;   R0 = 0 (laskuri on nollassa kun silmukka päättyy)
;
; =============================================================================

        ; -----------------------------------------------
        ; Alusta rekisterit
        ; -----------------------------------------------
        JARI  R0, 10      ; R0 = laskuri, aloita arvosta 10
        JARI  R1, 1       ; R1 = askelkoko (vähennetään 1 kerrallaan)
        JARI  R2, 0xF810  ; R2 = näyttöpointteri (rivi 0, sarake 16)

        ; -----------------------------------------------
        ; Tulosta aloitusarvo "10 " (kaksinumeroinen erikoistapaus)
        ; -----------------------------------------------
        JARI  R3, 0xE031  ; R3 = '1' (valkoinen)
        STORE [R2], R3  ; [R2] = '1'
        ADD   R2, R1      ; R2++ (seuraava näyttöpaikka)

        JARI  R3, 0xE030  ; R3 = '0'
        STORE [R2], R3  ; [R2] = '0'
        ADD   R2, R1      ; R2++

        JARI  R3, 0xE020  ; R3 = ' ' (välilyönti)
        STORE [R2], R3  ; [R2] = ' '
        ADD   R2, R1      ; R2++

; =============================================================================
; PÄÄSILMUKKA - Laske 9:stä 0:aan
; =============================================================================
loop:
        ; -----------------------------------------------
        ; Vähennä laskuria yhdellä
        ; -----------------------------------------------
        SUB   R0, R1      ; R0 = R0 - 1

        ; -----------------------------------------------
        ; Tulosta nykyinen arvo (9..0) yhtenä numerona
        ; Muunnetaan numero merkiksi: '0' + R0
        ; ASCII '0' = 0x30, joten numero + 0x30 = merkki
        ; Valkoinen väri: 0xE000, joten 0xE030 + numero
        ; -----------------------------------------------
        CPY   R3, R0      ; R3 = R0 (laskurin kopio)
        JARI  FP, 0xE030  ; FP = valkoinen '0' -pohja
        ADD   R3, FP      ; R3 = 0xE030 + numero = merkki
        STORE [R2], R3  ; [R2] = merkki
        ADD   R2, R1      ; R2++ (seuraava näyttöpaikka)

        ; -----------------------------------------------
        ; Tulosta välilyönti erottimeksi
        ; -----------------------------------------------
        JARI  R3, 0xE020  ; R3 = ' ' (valkoinen välilyönti)
        STORE [R2], R3  ; [R2] = ' '
        ADD   R2, R1      ; R2++

        ; -----------------------------------------------
        ; Jatka silmukkaa kunnes laskuri on 0
        ; CMP asettaa Zero-lipun (Z) jos R0 == FP
        ; JNZ hyppää takaisin jos Z == 0 (ei ollut sama)
        ; -----------------------------------------------
        JARI  FP, 0       ; FP = 0 (vertailuarvo)
        CMP   R0, FP      ; Vertaa: R0 - 0, aseta liput
        JNZ   loop        ; Jos Z=0 (R0 != 0), hyppää loop

        ; -----------------------------------------------
        ; Silmukka päättyi, laskuri on nyt 0
        ; -----------------------------------------------
        HALT
