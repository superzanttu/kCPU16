; =============================================================================
; factorial.asm - Kertoman laskenta aliohjelmalla (CALL/RET)
; =============================================================================
;
; KUVAUS:
;   Demonstroi aliohjelmien käyttöä CALL ja RET -käskyillä.
;   Laskee 5! = 5 * 4 * 3 * 2 * 1 = 120
;
; ALIOHJELMAN TOIMINTA:
;   CALL addr:
;     1. PUSH PC+kasky_koko  (tallenna paluuosoite pinoon)
;     2. PC = addr           (hyppää aliohjelmaan)
;
;   RET:
;     1. POP PC              (hae paluuosoite pinosta)
;     (jatka pääohjelmassa)
;
; OHJELMA:
;   Pääohjelma:
;     LOAD R0, 5       ; Syöte: n = 5
;     CALL fact_iter   ; Kutsu aliohjelmaa
;     ; Nyt R0 = 120   ; Tulos: 5!
;
;   Aliohjelma fact_iter:
;     Iteratiivinen algoritmi:
;     tulos = 1
;     while (laskuri > 0):
;         tulos *= laskuri
;         laskuri--
;     return tulos
;
; REKISTERIEN KÄYTTÖ:
;   R0 = Syöte/tulos (5 -> 120)
;   R1 = Laskuri aliohjelmassa (5 -> 0)
;   R2 = Vähennysvakio (1)
;   R3 = Näyttöpointteri
;   FP = Väliaikainen merkki
;
; NÄYTTÖ:
;   Tulostaa: "5 4 3 2 1 120"
;   (laskurin arvot ja lopputulos)
;
; TULOS:
;   R0 = 120 (5! = 120)
;
; =============================================================================

        ; -----------------------------------------------
        ; Pääohjelma: Alusta ja kutsu aliohjelmaa
        ; -----------------------------------------------
        LOAD  R0, 5     ; R0 = n = 5 (laskettava kertoma)
        LOAD  R3, 0xF840 ; R3 = näyttöpointteri (rivi 1, sarake 64)

        ; -----------------------------------------------
        ; Aliohjelmakutsu
        ; CALL tallentaa paluuosoitteen pinoon ja hyppää
        ; -----------------------------------------------
        CALL  fact_iter ; Kutsu aliohjelmaa, R0 = 5!

        ; -----------------------------------------------
        ; Aliohjelma palasi, R0 = 120
        ; Tulosta tulos "120" näytölle
        ; -----------------------------------------------
        LOAD  R2, 1        ; R2 = 1 (näyttöpoitnerin askel)

        LOAD  FP, 0xE031   ; '1'
        STORE_IND R3, FP
        ADD   R3, R2

        LOAD  FP, 0xE032   ; '2'
        STORE_IND R3, FP
        ADD   R3, R2

        LOAD  FP, 0xE030   ; '0'
        STORE_IND R3, FP

        ; -----------------------------------------------
        ; Lopeta ohjelma
        ; Tulos: R0 = 120
        ; -----------------------------------------------
        HALT

; =============================================================================
; ALIOHJELMA: fact_iter - Iteratiivinen kertoman laskenta
; =============================================================================
;
; Sisäänmeno:
;   R0 = n (laskettava luku, esim. 5)
;
; Ulostulo:
;   R0 = n! (kertoma, esim. 120)
;
; Muuttaa rekisterit:
;   R1 = laskuri (tyhjätään)
;   R2 = vakio 1
;   FP = väliaikainen
;
; Algoritmi:
;   R1 = n
;   R0 = 1
;   while (R1 > 0):
;       R0 = R0 * R1
;       R1 = R1 - 1
;   return R0
;
; =============================================================================
fact_iter:
        ; -----------------------------------------------
        ; Alusta aliohjelma
        ; -----------------------------------------------
        CPY   R1, R0    ; R1 = n (laskuri, laskee alaspäin)
        LOAD  R0, 1     ; R0 = 1 (tulos, kerrotaan ylöspäin)
        LOAD  R2, 1     ; R2 = 1 (vakio dekrementille)

; -----------------------------------------------
; Kertomissilmukka
; -----------------------------------------------
fact_loop:
        ; -----------------------------------------------
        ; Tulosta laskurin arvo näytölle (debug)
        ; Muunna numero merkiksi: '0' + laskuri
        ; -----------------------------------------------
        STORE R0, 0x0212   ; Tallenna tulos väliaikaisesti muistiin
        CPY   FP, R1       ; FP = laskurin kopio
        LOAD  R0, 0xE030   ; R0 = valkoinen '0' -pohja
        ADD   FP, R0       ; FP = '0' + laskuri = numeromerkki
        READ  R0, 0x0212   ; Palauta tulos R0:aan
        STORE_IND R3, FP   ; Kirjoita merkki näytölle
        ADD   R3, R2       ; Seuraava näyttöpaikka

        ; Tulosta välilyönti
        LOAD  FP, 0xE020   ; ' '
        STORE_IND R3, FP
        ADD   R3, R2

        ; -----------------------------------------------
        ; Laske tulos = tulos * laskuri
        ; -----------------------------------------------
        MUL   R0, R1    ; R0 = R0 * R1

        ; -----------------------------------------------
        ; Vähennä laskuria ja jatka jos > 0
        ; -----------------------------------------------
        SUB   R1, R2    ; R1 = R1 - 1
        JNZ   fact_loop ; Jos R1 != 0, jatka silmukkaa

        ; -----------------------------------------------
        ; Palaa pääohjelmaan
        ; RET hakee paluuosoitteen pinosta
        ; R0 sisältää nyt n!
        ; -----------------------------------------------
        RET
