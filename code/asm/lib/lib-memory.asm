; =============================================================================
; lib-memory.asm — Muisti- ja puskurirutiinit
; =============================================================================
;
; KUVAUS:
;   Tarjoaa yksinkertaiset osoite + pituus -muotoiset muistirutiinit.
;   Koneessa on jo COPY- ja FILL-käskyt, mutta ohjelmissa tarvitaan usein
;   helposti kutsuttavia aliohjelmia, jotka käyttävät yhtenäistä rajapintaa.
;
; TOIMINNOT:
;   mem_fill_words    — Täytä alue annetulla arvolla
;   mem_zero_words    — Täytä alue nollilla
;   mem_copy_words    — Kopioi alue lähteestä kohteeseen
;   mem_compare_words — Vertaa kahta aluetta
;   mem_find_word     — Etsi ensimmäinen arvo alueelta
;
; HUOM:
;   mem_copy_words on tarkoitettu erillisille tai eteenpäin kopioitaville
;   alueille. Päällekkäiset alueet kannattaa käsitellä erikseen.
; =============================================================================

; =============================================================================
; mem_fill_words
;
; Sisään:  R0 = alkuosoite, R1 = sanamäärä, R2 = täyttöarvo
; Ulos:    —
; Clobbers: R0–R3
; =============================================================================

mem_fill_words:
        READ  R3, 0
_mem_fill_loop:
        CMP   R1, R3
        JZ    _mem_fill_done
        STORE [R0], R2
        READ  R3, 1
        ADD   R0, R3
        SUB   R1, R3
        READ  R3, 0
        JUMP  _mem_fill_loop
_mem_fill_done:
        RET

; =============================================================================
; mem_zero_words
;
; Sisään:  R0 = alkuosoite, R1 = sanamäärä
; Ulos:    —
; Clobbers: R0–R3
; =============================================================================

mem_zero_words:
        READ  R2, 0
        CALL  mem_fill_words
        RET

; =============================================================================
; mem_copy_words
;
; Sisään:  R0 = lähdeosoite, R1 = kohdeosoite, R2 = sanamäärä
; Ulos:    —
; Clobbers: R0–R4
; =============================================================================

mem_copy_words:
        READ  R4, 0
_mem_copy_loop:
        CMP   R2, R4
        JZ    _mem_copy_done
        READ  R3, [R0]
        STORE [R1], R3
        READ  R4, 1
        ADD   R0, R4
        ADD   R1, R4
        SUB   R2, R4
        READ  R4, 0
        JUMP  _mem_copy_loop
_mem_copy_done:
        RET

; =============================================================================
; mem_compare_words
;
; Sisään:  R0 = alue A, R1 = alue B, R2 = sanamäärä
; Ulos:    R0 = 0 jos samat, 1 jos eri
; Clobbers: R1–R4
; =============================================================================

mem_compare_words:
        READ  R4, 0
_mem_compare_loop:
        CMP   R2, R4
        JZ    _mem_compare_same
        READ  R3, [R0]
        READ  R4, [R1]
        CMP   R3, R4
        JNZ   _mem_compare_diff
        READ  R4, 1
        ADD   R0, R4
        ADD   R1, R4
        SUB   R2, R4
        READ  R4, 0
        JUMP  _mem_compare_loop
_mem_compare_same:
        READ  R0, 0
        RET
_mem_compare_diff:
        READ  R0, 1
        RET

; =============================================================================
; mem_find_word
;
; Sisään:  R0 = alkuosoite, R1 = sanamäärä, R2 = etsittävä arvo
; Ulos:    R0 = osuman osoite, tai 0xFFFF jos ei löytynyt
; Clobbers: R1–R4
; =============================================================================

mem_find_word:
        CPY   R3, R0
        READ  R4, 0
_mem_find_loop:
        CMP   R1, R4
        JZ    _mem_find_not_found
        READ  R0, [R3]
        CMP   R0, R2
        JZ    _mem_find_found
        READ  R4, 1
        ADD   R3, R4
        SUB   R1, R4
        READ  R4, 0
        JUMP  _mem_find_loop
_mem_find_found:
        CPY   R0, R3
        RET
_mem_find_not_found:
        READ  R0, 0xFFFF
        RET
