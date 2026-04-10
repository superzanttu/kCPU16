; =============================================================================
; fibonacci.asm - Fibonacci-lukujen laskenta iteratiivisesti
; =============================================================================
;
; KUVAUS:
;   Laskee Fibonacci-lukujonon ensimmäiset 10 lukua (F(0)..F(9))
;   ja tulostaa ne näytölle.
;
; FIBONACCI-LUKUJONO:
;   F(0) = 0
;   F(1) = 1
;   F(n) = F(n-1) + F(n-2)  kun n >= 2
;
;   Jono: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
;
; ALGORITMI (iteratiivinen):
;   a = 0          ; F(n-2)
;   b = 1          ; F(n-1)
;   for i = 2 to 9:
;       temp = b
;       b = a + b  ; F(n) = F(n-2) + F(n-1)
;       a = temp   ; Siirrä vanhaa b:tä a:han
;
; REKISTERIEN KÄYTTÖ:
;   R0 = a = F(n-2), edellisen edellinen
;   R1 = b = F(n-1), edellinen (ja lopulta tulos)
;   R2 = kierroslaskuri (8 kierrosta: F(2)..F(9))
;   R3 = vakio 1 (dekrementti ja näytön siirto)
;   FP = näyttöpointteri
;   SP = väliaikainen merkki
;
; NÄYTTÖ:
;   Tulostaa: "0 1 1 2 3 5 8 13 21 34 "
;
; TULOS:
;   R1 = 34 (F(9))
;
; =============================================================================

        ; -----------------------------------------------
        ; Alusta Fibonacci-muuttujat
        ; -----------------------------------------------
        READ  R0, 0       ; a = F(0) = 0
        READ  R1, 1       ; b = F(1) = 1
        READ  R2, 8       ; 8 kierrosta tuottaa F(2)..F(9)
        READ  R3, 1       ; vakio +1 (dekrementti ja osoittimen siirto)
        READ  FP, 0xF820  ; näyttöpointteri (rivi 0, sarake 32)

        ; -----------------------------------------------
        ; Tulosta F(0) ja F(1): "0 1 "
        ; -----------------------------------------------
        READ  SP, 0xE030  ; '0'
        STORE [FP], SP  ; Tulosta '0'
        ADD   FP, R3      ; Seuraava paikka

        READ  SP, 0xE020  ; ' ' (välilyönti)
        STORE [FP], SP
        ADD   FP, R3

        READ  SP, 0xE031  ; '1'
        STORE [FP], SP
        ADD   FP, R3

        READ  SP, 0xE020  ; ' '
        STORE [FP], SP
        ADD   FP, R3

; =============================================================================
; FIBONACCI-SILMUKKA
; Laskee F(2), F(3), ..., F(9)
; =============================================================================
fib_loop:
        ; -----------------------------------------------
        ; Laske seuraava Fibonacci-luku:
        ; uusi_b = a + b
        ; uusi_a = vanha_b
        ;
        ; Käytetään muistia väliaikaiseen tallennukseen
        ; koska meillä ei ole tarpeeksi rekistereitä
        ; -----------------------------------------------
        STORE [0x0210], R1  ; Tallenna b muistiin (väliaikainen)
        ADD   R1, R0      ; b = a + b (uusi Fibonacci-luku)
        READ R0, [0x0210]  ; a = vanha b

        ; -----------------------------------------------
        ; Tulosta nykyinen Fibonacci-luku (R1)
        ; Käsitellään erikseen kaksinumeroiset: 13, 21, 34
        ; -----------------------------------------------

        ; Tarkista onko 13
        READ  SP, 13
        CMP   R1, SP
        JZ    print_13

        ; Tarkista onko 21
        READ  SP, 21
        CMP   R1, SP
        JZ    print_21

        ; Tarkista onko 34
        READ  SP, 34
        CMP   R1, SP
        JZ    print_34

        ; -----------------------------------------------
        ; Yksinumeroinen (1, 2, 3, 5, 8)
        ; Muunna numero merkiksi: '0' + numero
        ; -----------------------------------------------
        STORE [0x0211], R0  ; Tallenna a (koska tarvitsemme R0:aa)
        CPY   SP, R1      ; SP = Fibonacci-luku
        READ  R0, 0xE030  ; R0 = valkoinen '0' -pohja
        ADD   SP, R0      ; SP = '0' + luku = merkki
        READ R0, [0x0211]  ; Palauta a
        STORE [FP], SP  ; Tulosta merkki
        ADD   FP, R3
        JUMP  print_space

; -----------------------------------------------
; Kaksinumeroisten tulostus
; -----------------------------------------------
print_13:
        READ  SP, 0xE031  ; '1'
        STORE [FP], SP
        ADD   FP, R3
        READ  SP, 0xE033  ; '3'
        STORE [FP], SP
        ADD   FP, R3
        JUMP  print_space

print_21:
        READ  SP, 0xE032  ; '2'
        STORE [FP], SP
        ADD   FP, R3
        READ  SP, 0xE031  ; '1'
        STORE [FP], SP
        ADD   FP, R3
        JUMP  print_space

print_34:
        READ  SP, 0xE033  ; '3'
        STORE [FP], SP
        ADD   FP, R3
        READ  SP, 0xE034  ; '4'
        STORE [FP], SP
        ADD   FP, R3

; -----------------------------------------------
; Tulosta välilyönti ja jatka silmukkaa
; -----------------------------------------------
print_space:
        READ  SP, 0xE020  ; ' '
        STORE [FP], SP
        ADD   FP, R3

        ; Vähennä kierroslaskuria ja jatka jos > 0
        SUB   R2, R3
        JNZ   fib_loop

        ; -----------------------------------------------
        ; Valmis! R1 = F(9) = 34
        ; -----------------------------------------------
        HALT
