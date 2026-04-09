; =============================================================================
; tut_bitops.asm — Bitti-operaatiot (Bitwise Operations)
; =============================================================================
;
; KUVAUS:
;   Demonstroi kCPU16:n bitti-operaatiot arvojen laskennalla ja
;   tulosten esittämisellä heksadesimaalimuodossa näytöllä.
;
; KÄSKYT:
;   AND Rd, Rs  — bittitason JA:     Rd = Rd & Rs
;   OR  Rd, Rs  — bittitason TAI:    Rd = Rd | Rs
;   XOR Rd, Rs  — bittitason EXOR:   Rd = Rd ^ Rs
;   NOT Rd      — bittitason käänne: Rd = ~Rd
;   SHL Rd, Rs  — siirto vasemmalle: Rd = Rd << Rs
;   SHR Rd, Rs  — siirto oikealle:   Rd = Rd >> Rs
;
; NÄYTTÖASETTELU:
;   Rivi 0   Otsikko
;   Rivi 2   AND: 0xFF0F & 0x0F0F = 0x????
;   Rivi 3   OR:  0x00FF | 0xFF00 = 0x????
;   Rivi 4   XOR: 0xFF00 ^ 0xF0F0 = 0x????
;   Rivi 5   NOT: ~0x0F0F          = 0x????
;   Rivi 6   SHL: 0x0001 << 8      = 0x????
;   Rivi 7   SHR: 0x8000 >> 4      = 0x????
;
; REKISTERIEN KÄYTTÖ:
;   R0, R1  = operandit laskuihin
;   R5, R6  = väliaikainen write_nibble/write_hex4-subroutineille
;   R8      = VRAM-kirjoitusosoitin
;   R9      = merkkijono-osoitin (write_str)
;   R10     = väriattribuutti
;   R11     = väliaikainen merkki (write_str)
;   R12     = 0  (nollavakio)
;   R13     = 1  (inkrementtivakio)
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA
; =============================================================================

STR_TITLE:
        .dstr "BITTI-OPERAATIOT (Bitwise Ops)"
STR_UNDER:
        .dstr "=============================="

STR_AND:
        .dstr "AND: 0xFF0F & 0x0F0F = 0x"
STR_OR:
        .dstr "OR:  0x00FF | 0xFF00 = 0x"
STR_XOR:
        .dstr "XOR: 0xFF00 ^ 0xF0F0 = 0x"
STR_NOT:
        .dstr "NOT: ~0x0F0F          = 0x"
STR_SHL:
        .dstr "SHL: 0x0001 << 8      = 0x"
STR_SHR:
        .dstr "SHR: 0x8000 >> 4      = 0x"

; =============================================================================
; ALIOHJELMA: write_str
; =============================================================================
write_str:
        LOAD  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        ADD   R8, R13
        ADD   R9, R13
        JUMP  write_str
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: write_nibble
; Kirjoittaa R5:n alimman nibble-arvon heksana näytölle.
; Sisään: R5 (muokataan), R8=VRAM-osoitin, R10=väri, R13=1
; Ulkoon:  R8 += 1
; =============================================================================
write_nibble:
        LOAD  R6, 0x000F
        AND   R5, R6          ; pidä vain alin nibble (0–15)
        LOAD  R6, 9
        CMP   R5, R6          ; onko nibble > 9 (= A–F)?
        JGT   wn_alpha
        LOAD  R6, 0x0030      ; '0' = 0x30
        JUMP  wn_store
wn_alpha:
        LOAD  R6, 0x0037      ; 'A'−10 = 0x37  (A=0xA+0x37=0x41 ✓)
wn_store:
        ADD   R5, R6          ; ASCII-merkki
        OR    R5, R10         ; lisää väri
        STORE [R8], R5        ; kirjoita VRAM:iin
        ADD   R8, R13         ; R8++
        RET

; =============================================================================
; ALIOHJELMA: write_hex4
; Kirjoittaa R1:n 16-bittisen arvon 4-numeroisena heksana näytölle.
; Sisään: R1=arvo, R8=VRAM-osoitin, R10=väri, R13=1
; Ulkoon:  R8 += 4
; Käyttää: R5, R6 (molemmat tuhotaan)
; =============================================================================
write_hex4:
        ; Nibble 3 (ylin):  R1 >> 12
        CPY   R5, R1
        LOAD  R6, 12
        SHR   R5, R6
        CALL  write_nibble

        ; Nibble 2:  R1 >> 8
        CPY   R5, R1
        LOAD  R6, 8
        SHR   R5, R6
        CALL  write_nibble

        ; Nibble 1:  R1 >> 4
        CPY   R5, R1
        LOAD  R6, 4
        SHR   R5, R6
        CALL  write_nibble

        ; Nibble 0 (alin):  R1
        CPY   R5, R1
        CALL  write_nibble
        RET

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        LOAD  R12, 0          ; nollavakio
        LOAD  R13, 1          ; inkrementtivakio

        ; --- Otsikko: rivi 0, sarake 24 = 0xF818 ---
        LOAD  R8, 0xF818
        LOAD  R9, STR_TITLE
        LOAD  R10, 0x4300     ; bold keltainen
        CALL  write_str

        ; --- Viiva: rivi 1, sarake 24 = 0xF868 ---
        LOAD  R8, 0xF868
        LOAD  R9, STR_UNDER
        LOAD  R10, 0x0700     ; valkoinen
        CALL  write_str

; --- AND: 0xFF0F & 0x0F0F = 0x0F0F ---
; Rivi 2, sarake 0 = 0xF8A0

        LOAD  R8, 0xF8A0
        LOAD  R9, STR_AND
        LOAD  R10, 0x0600     ; syaani
        CALL  write_str       ; kirjoittaa otsikon, R8 osoittaa tulokselle

        LOAD  R0, 0xFF0F
        LOAD  R1, 0x0F0F
        AND   R0, R1          ; R0 = 0xFF0F & 0x0F0F = 0x0F0F
        CPY   R1, R0
        LOAD  R10, 0x4200     ; bold vihreä (tulos)
        CALL  write_hex4

; --- OR: 0x00FF | 0xFF00 = 0xFFFF ---
; Rivi 3, sarake 0 = 0xF8F0

        LOAD  R8, 0xF8F0
        LOAD  R9, STR_OR
        LOAD  R10, 0x0600
        CALL  write_str

        LOAD  R0, 0x00FF
        LOAD  R1, 0xFF00
        OR    R0, R1          ; R0 = 0x00FF | 0xFF00 = 0xFFFF
        CPY   R1, R0
        LOAD  R10, 0x4200
        CALL  write_hex4

; --- XOR: 0xFF00 ^ 0xF0F0 = 0x0FF0 ---
; Rivi 4, sarake 0 = 0xF940

        LOAD  R8, 0xF940
        LOAD  R9, STR_XOR
        LOAD  R10, 0x0600
        CALL  write_str

        LOAD  R0, 0xFF00
        LOAD  R1, 0xF0F0
        XOR   R0, R1          ; R0 = 0xFF00 ^ 0xF0F0 = 0x0FF0
        CPY   R1, R0
        LOAD  R10, 0x4200
        CALL  write_hex4

; --- NOT: ~0x0F0F = 0xF0F0 ---
; Rivi 5, sarake 0 = 0xF990

        LOAD  R8, 0xF990
        LOAD  R9, STR_NOT
        LOAD  R10, 0x0600
        CALL  write_str

        LOAD  R0, 0x0F0F
        NOT   R0              ; R0 = ~0x0F0F = 0xF0F0
        CPY   R1, R0
        LOAD  R10, 0x4200
        CALL  write_hex4

; --- SHL: 0x0001 << 8 = 0x0100 ---
; Rivi 6, sarake 0 = 0xF9E0

        LOAD  R8, 0xF9E0
        LOAD  R9, STR_SHL
        LOAD  R10, 0x0600
        CALL  write_str

        LOAD  R0, 0x0001
        LOAD  R1, 8
        SHL   R0, R1          ; R0 = 0x0001 << 8 = 0x0100
        CPY   R1, R0
        LOAD  R10, 0x4200
        CALL  write_hex4

; --- SHR: 0x8000 >> 4 = 0x0800 ---
; Rivi 7, sarake 0 = 0xFA30

        LOAD  R8, 0xFA30
        LOAD  R9, STR_SHR
        LOAD  R10, 0x0600
        CALL  write_str

        LOAD  R0, 0x8000
        LOAD  R1, 4
        SHR   R0, R1          ; R0 = 0x8000 >> 4 = 0x0800
        CPY   R1, R0
        LOAD  R10, 0x4200
        CALL  write_hex4

        HALT
