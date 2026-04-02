; stack_demo.asm
; Demonstroi LIFO-pinoa (PUSH / POP).
;
; Tyonnetaan pinoon jarjestyksessa: 1, 2, 3
; Haetaan takaisin LIFO-jarjestyksessa: 3, 2, 1
; Tulos: R0 = 3, R1 = 2, R2 = 1

        LOAD  FP, 0xF860 ; nayttopointteri
        LOAD  R3, 0xE053 ; 'S'
        STORE_IND FP, R3

        LOAD  R0, 1     ; R0 = 1
        LOAD  R1, 2     ; R1 = 2
        LOAD  R2, 3     ; R2 = 3

        PUSH  R0        ; pino: [1]
        PUSH  R1        ; pino: [1, 2]
        PUSH  R2        ; pino: [1, 2, 3]

        LOAD  R3, 0xE050 ; 'P'
        STORE R3, 0xF861

        POP   R0        ; R0 = 3  (pinon huippu)
        POP   R1        ; R1 = 2
        POP   R2        ; R2 = 1

        LOAD  R3, 0xE04F ; 'O'
        STORE R3, 0xF862

        ; R0 = 3,  R1 = 2,  R2 = 1
        HALT
