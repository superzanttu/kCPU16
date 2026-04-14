; =============================================================================
; stack_demo.asm - Pinon (stack) demonstraatio PUSH/POP -käskyillä
; =============================================================================
;
; KUVAUS:
;   Demonstroi pinon LIFO-toimintaa (Last In, First Out).
;   Pino on tietorakenne, jossa viimeisenä lisätty poistetaan ensimmäisenä.
;
; PINON TOIMINTA:
;   PUSH reg:
;     1. [SP] = reg       (kirjoita pinon huipulle)
;     2. SP = SP - 1      (siirrä pinopointteria alas)
;
;   POP reg:
;     1. SP = SP + 1      (siirrä pinopointteria ylös)
;     2. reg = [SP]       (lue pinon huipulta)
;
; ESIMERKKI:
;   Työnnä: 1, 2, 3     Pino (pohja->huippu): [1, 2, 3]
;   Hae:    -> 3        Pino: [1, 2]
;   Hae:    -> 2        Pino: [1]
;   Hae:    -> 1        Pino: []
;
; REKISTERIEN KÄYTTÖ (alussa):
;   R0 = 1, R1 = 2, R2 = 3
;
; REKISTERIEN KÄYTTÖ (lopussa):
;   R0 = 3, R1 = 2, R2 = 1  (käänteinen järjestys!)
;
; NÄYTTÖ:
;   Tulostaa "SPO" (Stack Push/Pop Ok)
;
; =============================================================================

        ; -----------------------------------------------
        ; Alusta näyttö ja tulosta 'S' (Stack)
        ; -----------------------------------------------
        READ  FP, 0xF860 ; FP = näyttöpointteri
        READ  R3, 0xE053 ; R3 = 'S' (valkoinen)
        STORE [FP], R3  ; Kirjoita 'S' näytölle

        ; -----------------------------------------------
        ; Alusta rekisterit arvoilla 1, 2, 3
        ; -----------------------------------------------
        READ  R0, 1     ; R0 = 1
        READ  R1, 2     ; R1 = 2
        READ  R2, 3     ; R2 = 3

        ; -----------------------------------------------
        ; PUSH-vaihe: Työnnä arvot pinoon järjestyksessä
        ; Pino kasvaa: [] -> [1] -> [1,2] -> [1,2,3]
        ; -----------------------------------------------
        PUSH  R0        ; Työnnä 1 pinoon, pino: [1]
        PUSH  R1        ; Työnnä 2 pinoon, pino: [1, 2]
        PUSH  R2        ; Työnnä 3 pinoon, pino: [1, 2, 3]

        ; Tulosta 'P' (Push tehty)
        READ  R3, 0xE050 ; R3 = 'P'
        STORE [0xF861], R3  ; Suora osoitus näyttöön

        ; -----------------------------------------------
        ; POP-vaihe: Hae arvot pinosta (LIFO-järjestys)
        ; Pino pienenee: [1,2,3] -> [1,2] -> [1] -> []
        ; -----------------------------------------------
        POP   R0        ; R0 = 3 (pinon huippu)
        POP   R1        ; R1 = 2
        POP   R2        ; R2 = 1 (pinon pohja)

        ; Tulosta 'O' (Output ready)
        READ  R3, 0xE04F ; R3 = 'O'
        STORE [0xF862], R3

        ; -----------------------------------------------
        ; Lopputulos:
        ; R0 = 3 (oli viimeisenä pinossa, tuli ulos ensin)
        ; R1 = 2 (keskimmäinen)
        ; R2 = 1 (oli ensimmäisenä pinossa, tuli ulos viimeisenä)
        ;
        ; Tämä demonstroi LIFO-periaatteen:
        ; Last In, First Out - viimeisenä sisään, ensimmäisenä ulos
        ; -----------------------------------------------
        HALT
