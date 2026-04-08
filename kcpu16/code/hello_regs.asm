; =============================================================================
; hello_regs.asm - Peruslaskutoimitukset rekistereilla
; =============================================================================
;
; KUVAUS:
;   Tämä esimerkki näyttää miten kCPU16:lla tehdään peruslaskutoimituksia.
;   Lasketaan lauseke: (10 + 5) * 3 - 3 = 42
;
; REKISTERIEN KÄYTTÖ:
;   R0 = Päälaskurekisteri (lopputulos)
;   R1 = Ensimmäinen operandi (5)
;   R2 = Toinen operandi (3)
;   R3 = Väliaikainen näyttömerkkiä varten
;
; NÄYTÖLLE KIRJOITUS:
;   Ohjelma kirjoittaa näytön vasempaan yläkulmaan: "H+=42"
;   Näyttömuistin osoitteet: $F800 = 1. merkki, $F801 = 2. merkki, jne.
;   Merkkisanan rakenne: 0xE0XX, missä XX = ASCII-koodi
;   (0xE0 = valkoinen väri bitillä 13-15)
;
; TULOS:
;   R0 = 42 (0x002A)
;
; =============================================================================

        ; -----------------------------------------------
        ; Kirjoita aloitusmerkki 'H' näytön alkuun
        ; 0xE048 = valkoinen 'H' (ASCII 0x48 = 72)
        ; -----------------------------------------------
        JARI  R3, 0xE048      ; R3 = 'H' (valkoisena)
        STORE [0xF800], R3  ; Kirjoita näytön vasempaan yläkulmaan

        ; -----------------------------------------------
        ; Vaihe 1: Yhteenlasku 10 + 5 = 15
        ; -----------------------------------------------
        JARI  R0, 10    ; R0 = 10
        JARI  R1, 5     ; R1 = 5
        ADD   R0, R1    ; R0 = R0 + R1 = 10 + 5 = 15

        ; Kirjoita '+' merkki näytölle
        JARI  R3, 0xE02B      ; R3 = '+' (ASCII 0x2B = 43)
        STORE [0xF801], R3  ; Näyttöpaikka 2

        ; -----------------------------------------------
        ; Vaihe 2: Kertolasku 15 * 3 = 45
        ; -----------------------------------------------
        JARI  R2, 3     ; R2 = 3
        MUL   R0, R2    ; R0 = R0 * R2 = 15 * 3 = 45

        ; -----------------------------------------------
        ; Vaihe 3: Vähennyslasku 45 - 3 = 42
        ; -----------------------------------------------
        SUB   R0, R2    ; R0 = R0 - R2 = 45 - 3 = 42

        ; -----------------------------------------------
        ; Kirjoita tulos "=42" näytölle
        ; -----------------------------------------------
        JARI  R3, 0xE03D      ; R3 = '=' (ASCII 0x3D = 61)
        STORE [0xF802], R3  ; Näyttöpaikka 3

        JARI  R3, 0xE034      ; R3 = '4' (ASCII 0x34 = 52)
        STORE [0xF803], R3  ; Näyttöpaikka 4

        JARI  R3, 0xE032      ; R3 = '2' (ASCII 0x32 = 50)
        STORE [0xF804], R3  ; Näyttöpaikka 5

        ; -----------------------------------------------
        ; Pysäytä prosessori
        ; Tulos: R0 = 42
        ; -----------------------------------------------
        HALT
