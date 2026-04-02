; exit_demo.asm
; Demonstroi EXIT-kaskyä: user-tilan hallittu prosessin lopetus.
;
; Ohjelma laskee summan 1+2+3+4+5 = 15, tallentaa tuloksen R0:aan,
; ja lopettaa sitten hallitusti EXIT-kaaskyllä.
;
; EXIT triggeroi oman keskeytyksen INT 8, jonka kautta kernel saa
; tiedon prosessin lopetuksesta ilman koneen sammuttamista.
;
; Tulos: R0 = 15, process_exit_requested = True

        LOAD  R0, 0     ; summa = 0
        LOAD  R1, 1     ; laskuri = 1
        LOAD  R2, 5     ; yläraja = 5
        LOAD  R3, 1     ; askelkoko = 1
        LOAD  FP, 0xF880 ; nayttopointteri
        LOAD  SP, 0xE045 ; 'E'
        STORE_IND FP, SP
        ADD   FP, R3

loop:
        ADD   R0, R1    ; summa += laskuri
        LOAD  SP, 0xE02E ; '.'
        STORE_IND FP, SP
        ADD   FP, R3
        CMP   R1, R2    ; vertaa: laskuri == yläraja?
        JZ    done      ; jos yhtä suuret, lopeta silmukka
        ADD   R1, R3    ; laskuri++
        JUMP  loop

done:
        ; R0 = 15, hallittu lopetus user-tilassa
        LOAD  SP, 0xE058 ; 'X'
        STORE_IND FP, SP
        EXIT
