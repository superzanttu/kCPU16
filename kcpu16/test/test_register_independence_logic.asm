; =============================================================================
; test_register_independence_logic.asm — logiikka- ja siirtokäskyt
; Varmistaa, että AND/OR/XOR/SHL/SHR muuttavat vain kohderekisterin.
; NOT-käskyssä lähde on sama kuin kohde (1 operandi), joten testaamme
; sen vaikutuksen muihin rekistereihin.
; =============================================================================

        .origin 0x0200

        ; Lataa kaikki rekisterit eri arvoilla
        JARI  R0, 0x1234
        JARI  R1, 0xABCD
        JARI  R2, 0x5678
        JARI  R3, 0xF0F0
        JARI  FP, 0x0400

        ; AND R0, R1: vain R0 muuttuu, R1/R2/R3/FP säilyvät
        AND   R0, R1          ; R0 = 0x1234 & 0xABCD = 0x0204

        ; OR R2, R3: vain R2 muuttuu
        OR    R2, R3          ; R2 = 0x5678 | 0xF0F0 = 0xF6F8

        ; XOR R0, R2: vain R0 muuttuu, R2 pysyy ennallaan
        XOR   R0, R2          ; R0 = 0x0204 ^ 0xF6F8 = 0xF4FC

        ; SHL R1, R3 (R3=0xF0F0 → siirtomäärä & 0xFFFF, mutta yli 16 → 0)
        ; Käytä pientä siirtomäärää: lataa R3=2
        JARI  R3, 2
        SHL   R1, R3          ; R1 = 0xABCD << 2 = 0xAF34 (& 0xFFFF)
                              ; vain R1 muuttuu

        ; SHR R0, R3: vain R0 muuttuu
        SHR   R0, R3          ; R0 = 0xF4FC >> 2 = 0x3D3F
                              ; vain R0 muuttuu, R3 pysyy 2

        ; NOT R2: vain R2 muuttuu
        NOT   R2              ; R2 = ~0xF6F8 = 0x0907

        HALT

; Tarkista rekisteriarvot
.expect_reg   R0, 0x3D3F      ; SHR-tulos
.expect_reg   R1, 0xAF34      ; SHL-tulos (0xABCD=43981 << 2 = 175924 = 0x2AF34, katkaistaan 16 bittiin → 0xAF34)
.expect_reg   R2, 0x0907      ; NOT-tulos (~0xF6F8 = 0x0907)
.expect_reg   R3, 2           ; R3 muuttui vain kun teimme JARI R3, 2
.expect_reg   FP, 0x0400      ; FP muuttumaton kaikkien operaatioiden läpi
