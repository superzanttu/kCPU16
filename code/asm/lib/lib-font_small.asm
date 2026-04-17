; =============================================================================
; lib-font_small.asm — 4x5 pikselifontti (CHIP-8 0..F + printable ASCII)
; =============================================================================
;
; FONTTI:
;   - CHIP-8-yhteensopivat glyphit 0..9, A..F (indeksit 0..15)
;   - Jokainen glyphi on 4x5 pikselia
;   - Tallennusmuoto: 5 sanaa / glyphi, yksi sana per rivi
;   - Rivin alimmat 4 bittiä koodaavat pikselit vasemmalta oikealle
;     bit3=vasen ... bit0=oikea
;   - Kaikki tulostettavat ASCII-merkit (0x20..0x7E) palautetaan kelvollisena:
;       * '0'..'9', 'A'..'F', 'a'..'f' -> aidot heksaglyphit
;       * ' '                            -> tyhja glyphi
;       * muu printable ASCII            -> geneerinen "printable"-glyphi
;
; JULKINEN APURI:
;   font_small_get_glyph
;     Sisään:  R0 = ASCII-merkki (printable 0x20..0x7E)
;     Ulos:    R0 = glyph-osoite (font_small_data + idx*5)
;              R1 = 1 jos kelvollinen, 0 jos ei
; =============================================================================

font_small_data:
        ; 0
        .db 0xF, 0x9, 0x9, 0x9, 0xF
        ; 1
        .db 0x2, 0x6, 0x2, 0x2, 0x7
        ; 2
        .db 0xF, 0x1, 0xF, 0x8, 0xF
        ; 3
        .db 0xF, 0x1, 0xF, 0x1, 0xF
        ; 4
        .db 0x9, 0x9, 0xF, 0x1, 0x1
        ; 5
        .db 0xF, 0x8, 0xF, 0x1, 0xF
        ; 6
        .db 0xF, 0x8, 0xF, 0x9, 0xF
        ; 7
        .db 0xF, 0x1, 0x2, 0x4, 0x4
        ; 8
        .db 0xF, 0x9, 0xF, 0x9, 0xF
        ; 9
        .db 0xF, 0x9, 0xF, 0x1, 0xF
        ; A
        .db 0xF, 0x9, 0xF, 0x9, 0x9
        ; B
        .db 0xE, 0x9, 0xE, 0x9, 0xE
        ; C
        .db 0xF, 0x8, 0x8, 0x8, 0xF
        ; D
        .db 0xE, 0x9, 0x9, 0x9, 0xE
        ; E
        .db 0xF, 0x8, 0xF, 0x8, 0xF
        ; F
        .db 0xF, 0x8, 0xF, 0x8, 0x8

font_small_space:
        .db 0x0, 0x0, 0x0, 0x0, 0x0

font_small_printable_generic:
        .db 0xF, 0x8, 0xF, 0x8, 0xF

font_small_get_glyph:
        ; Oletus: invalid
        READ  R1, 0

        ; '0'..'9'
        READ  R2, 0x30
        CMP   R0, R2
        JLT   _fsg_upper
        READ  R3, 0x39
        CMP   R0, R3
        JGT   _fsg_upper
        SUB   R0, R2
        JUMP  _fsg_resolve

_fsg_upper:
        ; 'A'..'F'
        READ  R2, 0x41
        CMP   R0, R2
        JLT   _fsg_lower
        READ  R3, 0x46
        CMP   R0, R3
        JGT   _fsg_lower
        SUB   R0, R2
        READ  R4, 10
        ADD   R0, R4
        JUMP  _fsg_resolve

_fsg_lower:
        ; 'a'..'f'
        READ  R2, 0x61
        CMP   R0, R2
        JLT   _fsg_printable
        READ  R3, 0x66
        CMP   R0, R3
        JGT   _fsg_printable
        SUB   R0, R2
        READ  R4, 10
        ADD   R0, R4
        JUMP  _fsg_resolve

_fsg_printable:
        ; Kaikki tulostettavat ASCII-merkit 0x20..0x7E ovat kelvollisia.
        READ  R2, 0x20
        CMP   R0, R2
        JLT   _fsg_invalid
        READ  R3, 0x7E
        CMP   R0, R3
        JGT   _fsg_invalid

        ; Space -> tyhja glyphi
        READ  R2, 0x20
        CMP   R0, R2
        JZ    _fsg_space

        ; Muut printable-merkit -> geneerinen glyphi
        READ  R0, font_small_printable_generic
        READ  R1, 1
        RET

_fsg_space:
        READ  R0, font_small_space
        READ  R1, 1
        RET

_fsg_invalid:
        READ  R0, 0
        RET

_fsg_resolve:
        ; ptr = font_small_data + idx * 5
        READ  R2, 5
        MUL   R0, R2
        READ  R2, font_small_data
        ADD   R0, R2
        READ  R1, 1
        RET
