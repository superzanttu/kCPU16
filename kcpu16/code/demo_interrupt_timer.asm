; =============================================================================
; demo_interrupt_timer.asm — Keskeytylaskuri reaaliajassa
; =============================================================================
;
; KUVAUS:
;   Demonstroi kahta eri keskeytysmekanismia samanaikaisesti:
;
;   1. KELLOKESKEYTYS (INT 9, SCTMR):
;      - Käyttää reaaliaikakelloa (CTMR)
;      - Asetettu laukeamaan 500 ms välein
;      - Päivittää sekuntilaskurin joka toinen keskeytys (1 Hz)
;
;   2. AJASTINKESKEYTYS (INT 7, STMR):
;      - Käyttää käskyperustasta ajastinta (TMR)
;      - Laukeaa joka N:s käsky (asetettu 50 000)
;      - Laskee kokonaiskeskeytykset
;
;   Näyttää molempien laskureiden arvot reaaliajassa VRAM:iin.
;
; NÄYTTÖASETTELU:
;   Rivi 0   "=== KESKEYTYLASKURI ==="       (bold keltainen)
;   Rivi 2   "KELLOKESKEYTYS (INT 9, 500ms)" (syaani)
;   Rivi 3   "  Keskeytyksia: " + laskuri    (500ms välein kasvava)
;   Rivi 4   "  Sekunteja:    " + laskuri    (1s välein kasvava)
;   Rivi 6   "AJASTINKESKEYTYS (INT 7, TMR)" (syaani)
;   Rivi 7   "  Laskuri: " + laskuri         (harvemmin kasvava)
;   Rivi 10  "  [Paina Ctrl+C lopettaaksesi]"
;
; REKISTERIEN KÄYTTÖ (globaalit):
;   R12 = 0  (nollavakio)
;   R13 = 1  (inkrementtivakio)
;
; KÄSKYT:
;   SCTMR R0  — asettaa kellokeskeytyksen väliksi R0 millisekuntia
;               (INT_CLOCK_INTERVAL MMIO-kirjoitus: 0x001B)
;   STMR  R0  — asettaa TMR-ajastimen: keskeytys joka R0:s käsky
;   STI       — sallii laitteistokeskeytykset (I-lippu = 1)
;   IRET      — palaa keskeytysrutiinista
;
; =============================================================================

        .origin 0x0100

        JUMP  main

; =============================================================================
; MERKKIJONODATA
; =============================================================================

STR_TITLE:
        .dstr "=== KESKEYTYLASKURI ==="

STR_CLKHEAD:
        .dstr "KELLOKESKEYTYS (INT 9, 500 ms)"
STR_CLKCNT:
        .dstr "  Keskeytyksia: "
STR_CLKSEC:
        .dstr "  Sekunteja:    "

STR_TMRHEAD:
        .dstr "AJASTINKESKEYTYS (INT 7, TMR)"
STR_TMRCNT:
        .dstr "  Laskuri:      "

STR_HINT:
        .dstr "[Paina Ctrl+C lopettaaksesi]"

; =============================================================================
; MUUTTUJAT (1 sana kukin)
; =============================================================================

clock_count:
        .db 0    ; kellokeskeytyslaskuri (kasvaa 2 Hz:llä)
second_count:
        .db 0    ; sekuntilaskuri (kasvaa 1 Hz:llä)
timer_count:
        .db 0    ; TMR-ajastinkeskeytyslaskuri

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
; =============================================================================
write_nibble:
        LOAD  R6, 0x000F
        AND   R5, R6
        LOAD  R6, 9
        CMP   R5, R6
        JGT   wn_alpha
        LOAD  R6, 0x0030
        JUMP  wn_store
wn_alpha:
        LOAD  R6, 0x0037
wn_store:
        ADD   R5, R6
        OR    R5, R10
        STORE [R8], R5
        ADD   R8, R13
        RET

; =============================================================================
; ALIOHJELMA: write_hex4
; =============================================================================
write_hex4:
        CPY   R5, R1
        LOAD  R6, 12
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        LOAD  R6, 8
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        LOAD  R6, 4
        SHR   R5, R6
        CALL  write_nibble
        CPY   R5, R1
        CALL  write_nibble
        RET

; =============================================================================
; ALIOHJELMA: update_display
; Päivittää kaikkien kolmen laskurin arvon näytölle.
; Sisään: R12=0, R13=1
; Käyttää: R0, R1, R2, R5, R6, R8, R9, R10
; =============================================================================
update_display:
        ; Kellokeskeytykset: rivi 3, sarake 16 = 0xF8F0 + 16 = 0xF900
        LOAD  R8, 0xF900
        LOAD  R1, [clock_count]
        LOAD  R10, 0x4200     ; bold vihreä
        CALL  write_hex4

        ; Sekunnit: rivi 4, sarake 16 = 0xF940 + 16 = 0xF950
        LOAD  R8, 0xF950
        LOAD  R1, [second_count]
        LOAD  R10, 0x4200
        CALL  write_hex4

        ; TMR-laskuri: rivi 7, sarake 16 = 0xFA30 + 16 = 0xFA40
        LOAD  R8, 0xFA40
        LOAD  R1, [timer_count]
        LOAD  R10, 0x4200
        CALL  write_hex4

        RET

; =============================================================================
; KESKEYTYSRUTIINI: clock_handler (INT 9)
; Laukeaa joka 500 ms (= 2 Hz).
; Kasvattaa clock_count aina.
; Kasvattaa second_count joka toinen kerta (= 1 Hz).
; =============================================================================
clock_handler:
        LOAD  R0, [clock_count]
        ADD   R0, R13          ; clock_count++
        STORE [clock_count], R0

        ; Onko clock_count pariton? → second_count++
        ; Pariteetti: AND clock_count, 1 → JNZ = pariton → lisää sekunti
        LOAD  R1, 1
        AND   R1, R0           ; R1 = clock_count & 1
        JZ    ch_no_sec        ; Z=1 → parillinen → ei sekuntia
        LOAD  R2, [second_count]
        ADD   R2, R13
        STORE [second_count], R2
ch_no_sec:
        CALL  update_display
        IRET

; =============================================================================
; KESKEYTYSRUTIINI: timer_handler (INT 7)
; Laukeaa joka N:s käsky (asetettu STMR-arvolla).
; =============================================================================
timer_handler:
        LOAD  R0, [timer_count]
        ADD   R0, R13
        STORE [timer_count], R0
        CALL  update_display
        IRET

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        LOAD  R12, 0          ; nollavakio
        LOAD  R13, 1          ; inkrementtivakio

        ; --- Otsikko: rivi 0, sarake 29 = 0xF81D ---
        LOAD  R8, 0xF81D
        LOAD  R9, STR_TITLE
        LOAD  R10, 0x4300     ; bold keltainen
        CALL  write_str

        ; --- Kellokeskeytys-otsikko: rivi 2, sarake 24 = 0xF8B8 ---
        LOAD  R8, 0xF8B8
        LOAD  R9, STR_CLKHEAD
        LOAD  R10, 0x0600     ; syaani
        CALL  write_str

        ; --- "Keskeytyksia:" etiketti: rivi 3, sarake 0 = 0xF8F0 ---
        LOAD  R8, 0xF8F0
        LOAD  R9, STR_CLKCNT
        LOAD  R10, 0x0700     ; valkoinen
        CALL  write_str

        ; --- "Sekunteja:" etiketti: rivi 4, sarake 0 = 0xF940 ---
        LOAD  R8, 0xF940
        LOAD  R9, STR_CLKSEC
        LOAD  R10, 0x0700
        CALL  write_str

        ; --- TMR-otsikko: rivi 6, sarake 25 = 0xF9E9 ---
        LOAD  R8, 0xF9E9
        LOAD  R9, STR_TMRHEAD
        LOAD  R10, 0x0600
        CALL  write_str

        ; --- "TMR laskuri:" etiketti: rivi 7, sarake 0 = 0xFA30 ---
        LOAD  R8, 0xFA30
        LOAD  R9, STR_TMRCNT
        LOAD  R10, 0x0700
        CALL  write_str

        ; --- Vihje: rivi 10, sarake 26 = 0xFB20 + 26 = 0xFB3A ---
        LOAD  R8, 0xFB3A
        LOAD  R9, STR_HINT
        LOAD  R10, 0x0300     ; keltainen
        CALL  write_str

        ; --- Alusta näyttö nollilla ---
        CALL  update_display

        ; --- Rekisteröi INT 9 (kellokeskeytys) ---
        LOAD  R0, clock_handler
        STORE [0x0009], R0         ; INT_CLOCK = 9

        ; --- Rekisteröi INT 7 (TMR-ajastinkeskeytys) ---
        LOAD  R0, timer_handler
        STORE [0x0007], R0         ; INT_TIMER = 7

        ; --- Aseta kellokeskeytys: 500 ms välein ---
        LOAD  R0, 500
        SCTMR R0

        ; --- Aseta TMR-ajastin: joka 50000 käsky ---
        LOAD  R0, 50000
        STMR  R0

        ; --- Salli keskeytykset (I=1) ---
        STI

        ; --- Pääsilmukka: odota passiivisesti ---
idle:
        JUMP  idle
