; =============================================================================
; exit_demo.asm - Prosessin hallittu lopetus EXIT-käskyllä
; =============================================================================
;
; KUVAUS:
;   Demonstroi EXIT-käskyä, joka on tarkoitettu user-tilan ohjelman
;   hallittuun lopetukseen. EXIT eroaa HALT-käskystä:
;
;   HALT:
;     - Pysäyttää koko prosessorin
;     - Vaatii Kernel-tilan (etuoikeutettu)
;     - Käytetään kun kone sammutetaan
;
;   EXIT:
;     - Lopettaa vain nykyisen prosessin
;     - Sallittu User-tilassa
;     - Laukaisee keskeytyksen INT 8
;     - Käyttöjärjestelmä saa tiedon lopetuksesta
;
; OHJELMA:
;   Laskee summan 1 + 2 + 3 + 4 + 5 = 15 silmukalla
;   ja lopettaa sitten EXIT-käskyllä.
;
; REKISTERIEN KÄYTTÖ:
;   R0 = Summa (kasvatettava tulos)
;   R1 = Laskuri (1 -> 5)
;   R2 = Yläraja (5)
;   R3 = Askelkoko (1)
;   FP = Näyttöpointteri
;   SP = Väliaikainen merkki
;
; TULOS:
;   R0 = 15 (summa 1+2+3+4+5)
;   process_exit_requested = True (CPU:n tila)
;
; =============================================================================

        ; -----------------------------------------------
        ; Alusta rekisterit
        ; -----------------------------------------------
        LOAD  R0, 0     ; summa = 0
        LOAD  R1, 1     ; laskuri = 1 (aloitetaan ykkösestä)
        LOAD  R2, 5     ; yläraja = 5 (lopetetaan viiteen)
        LOAD  R3, 1     ; askelkoko = 1

        ; -----------------------------------------------
        ; Alusta näyttöpointteri ja tulosta aloitusmerkki
        ; -----------------------------------------------
        LOAD  FP, 0xF880 ; FP = näyttöpointteri (rivi 2)
        LOAD  SP, 0xE045 ; SP = 'E' (valkoinen)
        STORE_IND FP, SP ; Kirjoita 'E' näytölle
        ADD   FP, R3     ; Siirry seuraavaan paikkaan

; =============================================================================
; PÄÄSILMUKKA - Laske summa 1+2+3+4+5
; =============================================================================
loop:
        ; -----------------------------------------------
        ; Lisää laskuri summaan
        ; summa = summa + laskuri
        ; -----------------------------------------------
        ADD   R0, R1    ; R0 = R0 + R1

        ; -----------------------------------------------
        ; Tulosta piste '.' edistymisen merkiksi
        ; -----------------------------------------------
        LOAD  SP, 0xE02E ; SP = '.' (valkoinen)
        STORE_IND FP, SP ; Kirjoita '.'
        ADD   FP, R3     ; Siirry seuraavaan paikkaan

        ; -----------------------------------------------
        ; Tarkista onko yläraja saavutettu
        ; CMP asettaa Z=1 jos R1 == R2 (laskuri == 5)
        ; -----------------------------------------------
        CMP   R1, R2    ; Vertaa: laskuri - yläraja
        JZ    done      ; Jos yhtäsuuret (Z=1), hyppää done

        ; -----------------------------------------------
        ; Kasvata laskuria ja jatka silmukkaa
        ; -----------------------------------------------
        ADD   R1, R3    ; laskuri++
        JUMP  loop      ; Hyppää takaisin

; =============================================================================
; LOPETUS - Hallittu prosessin päättäminen
; =============================================================================
done:
        ; -----------------------------------------------
        ; Tulosta lopetusmerkki 'X'
        ; -----------------------------------------------
        LOAD  SP, 0xE058 ; SP = 'X' (valkoinen)
        STORE_IND FP, SP ; Kirjoita 'X'

        ; -----------------------------------------------
        ; Lopeta prosessi EXIT-käskyllä
        ;
        ; EXIT:
        ; 1. Asettaa process_exit_requested = True
        ; 2. Laukaisee keskeytyksen INT 8
        ; 3. Käyttöjärjestelmä saa tiedon ja voi
        ;    siivota prosessin resurssit
        ;
        ; Tulos: R0 = 15
        ; -----------------------------------------------
        EXIT
