; screen_hello_fill.asm
; Tayttaa koko nayttomuistin (0xF800-0xFF7F, 1920 sanaa) toistuvalla
; merkkijonolla "HELLO! ". Jokainen merkki kirjoitetaan valkoisena (vari 7).
;
; Muuttujat:
;   R0 = nayttopointteri (VRAM-osoite)
;   R1 = jaljella olevat ruudut (1920)
;   R2 = pattern-pointteri
;   R3 = vakio 1
;   FP = valiaikainen merkki
;   SP = pattern-end (0x0207)
;
; Tulos: VRAM taynna tekstiA "HELLO! HELLO! ..."

        ; Alusta pattern RAM-alueelle 0x0200-0x0206
        ; 0xE000 = vari 7, ASCII alimmat bitit
        LOAD  R0, 0xE048      ; 'H'
        STORE R0, 0x0200
        LOAD  R0, 0xE045      ; 'E'
        STORE R0, 0x0201
        LOAD  R0, 0xE04C      ; 'L'
        STORE R0, 0x0202
        LOAD  R0, 0xE04C      ; 'L'
        STORE R0, 0x0203
        LOAD  R0, 0xE04F      ; 'O'
        STORE R0, 0x0204
        LOAD  R0, 0xE021      ; '!'
        STORE R0, 0x0205
        LOAD  R0, 0xE020      ; ' '
        STORE R0, 0x0206

        ; Alusta kirjoitussilmukka
        LOAD  R0, 0xF800      ; VRAM alku
        LOAD  R1, 1920        ; 80 x 24
        LOAD  R2, 0x0200      ; pattern alku
        LOAD  R3, 1
        LOAD  SP, 0x0207      ; pattern loppu (exclusive)

        ; Ajon aloitusmerkki
        LOAD  FP, 0xE053      ; 'S'
        STORE FP, 0xF8A0

fill_loop:
        READ_IND FP, R2       ; FP = [R2]
        STORE_IND R0, FP      ; [R0] = FP

        ADD   R0, R3          ; seuraava nayttosolu
        ADD   R2, R3          ; seuraava pattern-merkki

        CMP   R2, SP
        JNZ   no_wrap
        LOAD  R2, 0x0200

no_wrap:
        SUB   R1, R3
        JNZ   fill_loop

        ; Ajon lopetusmerkki
        LOAD  FP, 0xE044      ; 'D'
        STORE FP, 0xF8A1

        HALT
