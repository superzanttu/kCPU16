; =============================================================================
; lib-string.asm — Null-terminoitujen merkkijonojen apurutiinit
; =============================================================================
;
; KUVAUS:
;   Tarjoaa pienet yleisrutiinit sana-ASCII-merkkijonoille. Useissa demoissa on
;   omia tulostus- ja vertailurutiineja; tämä kirjasto kokoaa yhteen niiden
;   pohjalle sopivat yleiset tekstinkäsittelytoiminnot.
;
; OLETUS:
;   Merkkijonot ovat null-terminoituja ja yksi merkki vie yhden sanan.
;
; TOIMINNOT:
;   str_len        — Laske pituus
;   str_copy       — Kopioi merkkijono kohteeseen
;   str_compare    — Vertaa kahta merkkijonoa
;   str_is_empty   — Tarkista onko merkkijono tyhjä
;   str_find_char  — Etsi ensimmäinen merkki merkkijonosta
; =============================================================================

; =============================================================================
; str_len
;
; Sisään:  R0 = merkkijonon osoite
; Ulos:    R0 = pituus ilman null-merkkiä
; Clobbers: R1–R3
; =============================================================================

str_len:
        CPY   R1, R0
        READ  R0, 0
        READ  R2, 1
        READ  R3, 0
_str_len_loop:
        READ  R3, [R1]
        READ  R2, 0
        CMP   R3, R2
        JZ    _str_len_done
        READ  R2, 1
        ADD   R1, R2
        ADD   R0, R2
        JUMP  _str_len_loop
_str_len_done:
        RET

; =============================================================================
; str_copy
;
; Sisään:  R0 = lähdeosoite, R1 = kohdeosoite
; Ulos:    R0 = alkuperäinen kohdeosoite
; Clobbers: R1–R4
; =============================================================================

str_copy:
        CPY   R2, R1
        READ  R4, 1
_str_copy_loop:
        READ  R3, [R0]
        STORE [R1], R3
        READ  R4, 0
        CMP   R3, R4
        JZ    _str_copy_done
        READ  R4, 1
        ADD   R0, R4
        ADD   R1, R4
        JUMP  _str_copy_loop
_str_copy_done:
        CPY   R0, R2
        RET

; =============================================================================
; str_compare
;
; Sisään:  R0 = merkkijono A, R1 = merkkijono B
; Ulos:    R0 = 0 jos samat, 1 jos eri
; Clobbers: R1–R4
; =============================================================================

str_compare:
        READ  R4, 0
_str_compare_loop:
        READ  R2, [R0]
        READ  R3, [R1]
        CMP   R2, R3
        JNZ   _str_compare_diff
        CMP   R2, R4
        JZ    _str_compare_same
        READ  R4, 1
        ADD   R0, R4
        ADD   R1, R4
        READ  R4, 0
        JUMP  _str_compare_loop
_str_compare_same:
        READ  R0, 0
        RET
_str_compare_diff:
        READ  R0, 1
        RET

; =============================================================================
; str_is_empty
;
; Sisään:  R0 = merkkijonon osoite
; Ulos:    R0 = 1 jos tyhjä, 0 jos ei
; Clobbers: R1
; =============================================================================

str_is_empty:
        READ  R1, [R0]
        READ  R0, 0
        CMP   R1, R0
        JZ    _str_is_empty_yes
        READ  R0, 0
        RET
_str_is_empty_yes:
        READ  R0, 1
        RET

; =============================================================================
; str_find_char
;
; Sisään:  R0 = merkkijonon osoite, R1 = etsittävä merkki
; Ulos:    R0 = osoite ensimmäiseen osumaan, 0 jos ei löytynyt
; Clobbers: R2–R3
; =============================================================================

str_find_char:
        CPY   R2, R0
        READ  R3, 0
_str_find_char_loop:
        READ  R0, [R2]
        CMP   R0, R3
        JZ    _str_find_char_not_found
        CMP   R0, R1
        JZ    _str_find_char_found
        READ  R0, 1
        ADD   R2, R0
        JUMP  _str_find_char_loop
_str_find_char_found:
        CPY   R0, R2
        RET
_str_find_char_not_found:
        READ  R0, 0
        RET
