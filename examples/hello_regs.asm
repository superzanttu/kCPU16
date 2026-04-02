; hello_regs.asm
; Peruslaskutoimitukset rekistereilla.
; Laskee: (10 + 5) * 3 - 3 = 42
; Tulos: R0 = 42

        ; Kirjoita aloitusmerkki naytolle
        LOAD  R3, 0xE048      ; 'H'
        STORE R3, 0xF800

        LOAD  R0, 10    ; R0 = 10
        LOAD  R1, 5     ; R1 = 5
        ADD   R0, R1    ; R0 = 10 + 5 = 15

        LOAD  R3, 0xE02B      ; '+'
        STORE R3, 0xF801

        LOAD  R2, 3     ; R2 = 3
        MUL   R0, R2    ; R0 = 15 * 3 = 45
        SUB   R0, R2    ; R0 = 45 - 3 = 42

        LOAD  R3, 0xE03D      ; '='
        STORE R3, 0xF802
        LOAD  R3, 0xE034      ; '4'
        STORE R3, 0xF803
        LOAD  R3, 0xE032      ; '2'
        STORE R3, 0xF804

        HALT
