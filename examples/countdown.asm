; countdown.asm
; Laske R0 alaspain 10:sta 0:aan SUB+JNZ-silmukalla.
; Tulos: R0 = 0

        LOAD  R0, 10      ; R0 = laskuri
        LOAD  R1, 1       ; R1 = askelkoko
        LOAD  R2, 0xF810  ; R2 = nayttopointteri

        ; Tulosta aloitusarvo "10 "
        LOAD  R3, 0xE031  ; '1'
        STORE_IND R2, R3
        ADD   R2, R1
        LOAD  R3, 0xE030  ; '0'
        STORE_IND R2, R3
        ADD   R2, R1
        LOAD  R3, 0xE020  ; ' '
        STORE_IND R2, R3
        ADD   R2, R1

loop:
        SUB   R0, R1      ; R0--

        ; Tulosta nykyinen arvo yhtena numerona (9..0)
        CPY   R3, R0
        LOAD  FP, 0xE030
        ADD   R3, FP
        STORE_IND R2, R3
        ADD   R2, R1

        ; Erotin
        LOAD  R3, 0xE020  ; ' '
        STORE_IND R2, R3
        ADD   R2, R1

        ; Jatka kunnes laskuri on 0
        LOAD  FP, 0
        CMP   R0, FP
        JNZ   loop

        HALT
