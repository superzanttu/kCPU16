; factorial.asm
; Laske 5! = 120 kayttamalla aliohjelmaa (CALL / RET).
;
; Paaohjelma:
;   R0 = 5  (syote)
;   CALL fact_iter
;   R0 = 120 (tulos)
;   Naytolle tulostuu: 5 4 3 2 1 = 120
;
; Aliohjelma fact_iter:
;   Sisaanmeno:  R0 = n
;   Ulostulo:    R0 = n!
;   Muuttaa:     R1 (laskuri), R2 (vakio 1)

        LOAD  R0, 5     ; R0 = n = 5
        LOAD  R3, 0xF840 ; nayttopointteri
        CALL  fact_iter ; R0 = 5!
        LOAD  R2, 1
        LOAD  FP, 0xE031 ; '1'
        STORE_IND R3, FP
        ADD   R3, R2
        LOAD  FP, 0xE032 ; '2'
        STORE_IND R3, FP
        ADD   R3, R2
        LOAD  FP, 0xE030 ; '0'
        STORE_IND R3, FP
        HALT

; --- fact_iter -------------------------------------------
; Iteratiivinen kertoma: R0 = R0 * (R0-1) * ... * 1
fact_iter:
        CPY   R1, R0    ; R1 = n  (laskee alas kohti 1)
        LOAD  R0, 1     ; R0 = 1  (kasvava tulos)
        LOAD  R2, 1     ; R2 = 1  (vakio dekrementille)

fact_loop:
        ; Tulosta laskurin numero (5..1)
        STORE R0, 0x0212
        CPY   FP, R1
        LOAD  R0, 0xE030
        ADD   FP, R0
        READ  R0, 0x0212
        STORE_IND R3, FP
        ADD   R3, R2

        ; Erotin
        LOAD  FP, 0xE020
        STORE_IND R3, FP
        ADD   R3, R2

        MUL   R0, R1    ; tulos *= laskuri
        SUB   R1, R2    ; laskuri--
        JNZ   fact_loop ; jatka kunnes laskuri = 0

        RET             ; palaa: R0 = n!
