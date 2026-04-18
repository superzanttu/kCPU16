; =============================================================================
; lib-input.asm — Näppäimistösyötteen perusrutiinit
; =============================================================================
;
; KUVAUS:
;   Kevyt apukirjasto näppäimistön pollaamiseen. Sopii tilanteisiin, joissa
;   ei haluta rakentaa omaa keskeytyskäsittelijää tai täyttä tekstisyötettä.
;
; TOIMINNOT:
;   input_has_key     — Tarkista onko puskurissa tapahtumia
;   input_read_event  — Lue seuraava raakadata-arvo
;   input_split_event — Erottele koodi ja vapautuslippu
;   input_read_press  — Lue seuraava painallus ja ohita vapautukset
;   input_wait_press  — Odota kunnes painallus saadaan
;   input_clear_buffer — Tyhjennä kaikki jonossa olevat tapahtumat
;
; ARKKITEHTUURIVAKIOT:
;   KBD_DATA, KBD_STATUS, KBD_RELEASE_BIT, KBD_KEY_CODE_MASK
; =============================================================================

; =============================================================================
; input_has_key
;
; Sisään:  —
; Ulos:    R0 = 1 jos puskurissa on tapahtumia, 0 jos ei
; Clobbers: R1
; =============================================================================

input_has_key:
        READ  R0, [KBD_STATUS]
        READ  R1, 0
        CMP   R0, R1
        JZ    _input_has_key_no
        READ  R0, 1
        RET
_input_has_key_no:
        READ  R0, 0
        RET

; =============================================================================
; input_read_event
;
; Sisään:  —
; Ulos:    R0 = tapahtuma, R1 = 1 jos luettiin, 0 jos puskuri oli tyhjä
; Clobbers: —
; =============================================================================

input_read_event:
        READ  R0, [KBD_STATUS]
        READ  R1, 0
        CMP   R0, R1
        JZ    _input_read_event_empty
        READ  R0, [KBD_DATA]
        READ  R1, 1
        RET
_input_read_event_empty:
        READ  R0, 0
        READ  R1, 0
        RET

; =============================================================================
; input_split_event
;
; Sisään:  R0 = raakadata KBD_DATA:sta
; Ulos:    R0 = näppäinkoodi, R1 = 1 jos vapautus, 0 jos painallus
; Clobbers: R2
; =============================================================================

input_split_event:
        CPY   R2, R0
        READ  R1, KBD_KEY_CODE_MASK
        AND   R0, R1
        READ  R1, KBD_RELEASE_BIT
        AND   R2, R1
        READ  R1, 0
        CMP   R2, R1
        JZ    _input_split_done
        READ  R1, 1
_input_split_done:
        RET

; =============================================================================
; input_read_press
;
; Sisään:  —
; Ulos:    R0 = näppäinkoodi, R1 = 1 jos painallus löytyi, 0 jos ei
; Clobbers: R2
; =============================================================================

input_read_press:
_input_read_press_loop:
        CALL  input_read_event
        READ  R2, 0
        CMP   R1, R2
        JZ    _input_read_press_empty
        CALL  input_split_event
        CMP   R1, R2
        JZ    _input_read_press_found
        JUMP  _input_read_press_loop
_input_read_press_empty:
        READ  R0, 0
        READ  R1, 0
        RET
_input_read_press_found:
        READ  R1, 1
        RET

; =============================================================================
; input_wait_press
;
; Sisään:  —
; Ulos:    R0 = seuraava painallus
; Clobbers: R1–R2
; =============================================================================

input_wait_press:
_input_wait_press_loop:
        CALL  input_read_press
        READ  R2, 0
        CMP   R1, R2
        JZ    _input_wait_press_loop
        RET

; =============================================================================
; input_clear_buffer
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0–R1
; =============================================================================

input_clear_buffer:
_input_clear_loop:
        READ  R0, [KBD_STATUS]
        READ  R1, 0
        CMP   R0, R1
        JZ    _input_clear_done
        READ  R0, [KBD_DATA]
        JUMP  _input_clear_loop
_input_clear_done:
        RET
