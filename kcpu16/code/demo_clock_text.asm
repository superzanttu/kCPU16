; =============================================================================
; clock_demo.asm — Reaaliaikainen päivämäärä ja kellonaika näytöllä
; =============================================================================
;
; KUVAUS:
;   Näyttää jatkuvasti päivitetyn päivämäärän ja kellonajan
;   näytön keskellä muodossa:
;
;       DD.MM.YYYY HH:MM:SS.MSS
;
;   Lukee arvot suoraan MMIO-kellon rekistereistä ja kirjoittaa
;   ne VRAM-muistiin. Kellokeskeytys (CTMR, Int 9) päivittää
;   näyttöä 500 ms välein ja vilkuttaa ':'-merkkejä 1 Hz:llä.
;
; NÄYTTÖASETTELU:
;   Näyttö: 80 saraketta x 24 riviä
;   Merkkijono on 23 merkkiä pitkä → sarake (80-23)/2 = 28
;   Rivi: 11 (näytön pystysuuntainen keskikohta)
;   VRAM-osoite: $FB8C  (= $F800 + 11*80 + 28)
;
; VRAM-SANAN RAKENNE:
;   Bitit  0–7:  ASCII-merkki
;   Bitit  8–10: Edustaväri FG (3 bittiä, 0–7)
;   Bitit 11–13: Taustaväri BG (3 bittiä, 0–7)
;   Bitti 14:    Lihavointi
;   Bitti 15:    Varattu (0)
;
;   Käytetty väri: keltainen teksti, musta tausta, ei lihavointia
;     FG=3 (keltainen) → bitit 8–10 = 011 → 0x0300
;     BG=0 (musta)     → bitit 11–13 = 000 → 0x0000
;     Yhdistetty attribuutti: 0x0300
;     Perusnumero '0' (ASCII 0x30): 0x0300 | 0x30 = 0x0330
;
; REKISTERIEN KÄYTTÖ (pysyvät koko ohjelman ajan):
;   R0  = VRAM-kirjoitusosoitin (asetetaan R2:sta draw_clock-kutsussa)
;         sekä väliaikainen arvo kellokäsittelijässä
;   R1  = luettava arvo (syöte aliohjelmille write2/write3/write4)
;   R2  = VRAM-kantaosoite ($FB8C, ei koskaan muutu)
;   R3  = vakio 1 (osoittimen kasvatus)
;   R4  = vakio 10 (jako kymmenjärjestelmässä)
;   R5  = '0' + väri = $0330 (perusnumero '0' keltaisella)
;   R6  = erottajamerkki tai vilkku-vertailu (alikutsut)
;   R7–R11 = aritmetiikka-scratch aliohjelmissa
;
; ALIOHJELMAT:
;   draw_clock  — Piirrä koko päivämäärä + kellonaika VRAM:iin
;   write_colon — Kirjoita ':' (vilkku päällä) tai ' ' (vilkku pois)
;   write2      — Kirjoita 2-numero (00–99), R0 += 2
;   write3      — Kirjoita 3-numero (000–999), R0 += 3
;   write4      — Kirjoita 4-numero (0000–9999), R0 += 4
;
; KESKEYTYKSET:
;   Int 9 (CTMR) joka 500 ms:
;     - vaihtaa blink_flag (0↔1)
;     - kutsuu draw_clock
;
; =============================================================================

        .origin 0x0200

; =============================================================================
; ALUSTUS: Aseta Int 9 -käsittelijä ja pysyvät vakiorekisterit
; =============================================================================

        LOAD  R0, clock_handler
        STORE [0x0009], R0    ; Int 9 -vektori → clock_handler

        LOAD  R2, 0xFB8C      ; VRAM-kantaosoite: rivi 11, sarake 28
        LOAD  R3, 1           ; osoittimen askel (1 sana kerrallaan)
        LOAD  R4, 10          ; jakaja (kymmenjärjestelmä)
        LOAD  R5, 0x0330      ; perusmerkki: '0' + keltainen (FG=3, BG=0)

; Aseta blink_flag = 1 (kaksoispisteet näkyvissä alustuksessa)
        LOAD  R0, 1
        STORE [blink_flag], R0

; Ensimmäinen piirto ennen keskeytyksiä
        CALL  draw_clock

; Aseta kellokeskeytys 500 ms välein (→ 1 Hz vilkku)
        LOAD  R0, 500
        SCTMR R0

; Salli laitteistokeskeytykset
        STI

; =============================================================================
; PÄÄSILMUKKA: odota keskeytyksiä
; =============================================================================
main_loop:
        NOP
        JUMP  main_loop

; =============================================================================
; KELLOKESKEYTYKSEN KÄSITTELIJÄ (Int 9, laukeaa joka 500 ms)
; =============================================================================
clock_handler:
        ; Vaihda blink_flag: 0 → 1 tai 1 → 0
        LOAD  R0, [blink_flag]
        LOAD  R6, 1
        XOR   R0, R6
        STORE [blink_flag], R0

        ; Piirrä kello (lukee aina tuoreimmat CLOCK-arvot)
        CALL  draw_clock

        IRET

; =============================================================================
; draw_clock: Piirrä koko kellonäyttö VRAM:iin
;   Käyttää: R0–R11 (R2–R5 ovat pysyviä vakioita)
; =============================================================================
draw_clock:
        CPY   R0, R2          ; R0 = VRAM-kantaosoite

        ; ------ DD: Päivä (01–31) ------
        LOAD  R1, [CLOCK_DAY]
        CALL  write2

        ; '.' erottaja
        LOAD  R6, 0x032E      ; '.' keltainen
        STORE [R0], R6
        ADD   R0, R3

        ; ------ MM: Kuukausi (01–12) ------
        LOAD  R1, [CLOCK_MONTH]
        CALL  write2

        ; '.' erottaja
        LOAD  R6, 0x032E
        STORE [R0], R6
        ADD   R0, R3

        ; ------ YYYY: Vuosi (esim. 2026) ------
        LOAD  R1, [CLOCK_YEAR]
        CALL  write4

        ; ' ' välilyönti
        LOAD  R6, 0x0320      ; ' ' keltainen (väriattribuutti + välilyönti)
        STORE [R0], R6
        ADD   R0, R3

        ; ------ HH: Tunti (00–23) ------
        LOAD  R1, [CLOCK_HOUR]
        CALL  write2

        ; ':' vilkkuva erottaja (HH:MM)
        CALL  write_colon

        ; ------ MM: Minuutti (00–59) ------
        LOAD  R1, [CLOCK_MINUTE]
        CALL  write2

        ; ':' vilkkuva erottaja (MM:SS)
        CALL  write_colon

        ; ------ SS: Sekunti (00–59) ------
        LOAD  R1, [CLOCK_SECOND]
        CALL  write2

        ; '.' erottaja (ennen millisekunteja)
        LOAD  R6, 0x032E      ; '.' keltainen
        STORE [R0], R6
        ADD   R0, R3

        ; ------ MSS: Millisekunti (000–999) ------
        LOAD  R1, [CLOCK_MILLIS]
        CALL  write3

        RET

; =============================================================================
; ALIOHJELMA: write_colon
; Kirjoita ':' jos blink_flag=1, ' ' jos blink_flag=0.
; R0 kasvaa yhdellä (kuten muut kirjoittavat aliohjelmat).
;
; Sisään: R0 = VRAM-osoitin, R3 = 1, blink_flag muistissa
; Ulos:   R0 = R0 + 1
; Muuttaa: R6
; =============================================================================
write_colon:
        LOAD  R6, [blink_flag]
        CMP   R6, R3          ; R3 = 1: Z=1 jos blink_flag == 1
        JZ    colon_visible
        LOAD  R6, 0x0320      ; ' ' keltainen (kaksoispiste piilotettu)
        JUMP  colon_store
colon_visible:
        LOAD  R6, 0x033A      ; ':' keltainen
colon_store:
        STORE [R0], R6
        ADD   R0, R3
        RET

; =============================================================================
; ALIOHJELMA: write2
; Kirjoita 2-numeroinen luku VRAM-osoittimeen (esim. 09, 31, 23)
;
; Sisään: R1 = luku (0–99), R0 = VRAM-osoitin
;         R3 = 1, R4 = 10, R5 = perusmerkki ('0'+väri)
; Ulos:   R0 = R0 + 2
; Muuttaa: R6, R7, R8, R9
; =============================================================================
write2:
        CPY   R6, R1          ; R6 = luku
        DIV   R6, R4          ; R6 = kymmenet  (luku / 10)
        CPY   R7, R6
        MUL   R7, R4          ; R7 = kymmenet * 10
        CPY   R8, R1
        SUB   R8, R7          ; R8 = ykköset  (luku − kymmenet×10)

        ; Kirjoita kymmenet-merkki
        CPY   R9, R5
        ADD   R9, R6          ; R9 = '0' + kymmenet + väriattribuutti
        STORE [R0], R9
        ADD   R0, R3

        ; Kirjoita ykköset-merkki
        CPY   R9, R5
        ADD   R9, R8          ; R9 = '0' + ykköset + väriattribuutti
        STORE [R0], R9
        ADD   R0, R3
        RET

; =============================================================================
; ALIOHJELMA: write3
; Kirjoita 3-numeroinen luku VRAM-osoittimeen (esim. 042, 999)
;
; Sisään: R1 = luku (0–999), R0 = VRAM-osoitin
;         R3 = 1, R4 = 10, R5 = perusmerkki
; Ulos:   R0 = R0 + 3
; Muuttaa: R6, R7, R8, R9, R10, R11
; =============================================================================
write3:
        LOAD  R10, 100
        CPY   R6, R1
        DIV   R6, R10         ; R6 = sadat  (luku / 100)
        CPY   R11, R6
        MUL   R11, R10        ; R11 = sadat * 100
        CPY   R7, R1
        SUB   R7, R11         ; R7 = jäännös (kymmenet + ykköset)

        CPY   R8, R7
        DIV   R8, R4          ; R8 = kymmenet  (jäännös / 10)
        CPY   R11, R8
        MUL   R11, R4         ; R11 = kymmenet * 10
        SUB   R7, R11         ; R7 = ykköset

        ; Kirjoita sadat
        CPY   R11, R5
        ADD   R11, R6
        STORE [R0], R11
        ADD   R0, R3

        ; Kirjoita kymmenet
        CPY   R11, R5
        ADD   R11, R8
        STORE [R0], R11
        ADD   R0, R3

        ; Kirjoita ykköset
        CPY   R11, R5
        ADD   R11, R7
        STORE [R0], R11
        ADD   R0, R3
        RET

; =============================================================================
; ALIOHJELMA: write4
; Kirjoita 4-numeroinen luku VRAM-osoittimeen (esim. 2026)
;
; Sisään: R1 = luku (0–9999), R0 = VRAM-osoitin
;         R3 = 1, R4 = 10, R5 = perusmerkki
; Ulos:   R0 = R0 + 4
; Muuttaa: R6, R7, R8, R9, R10, R11
; =============================================================================
write4:
        LOAD  R10, 1000
        CPY   R6, R1
        DIV   R6, R10         ; R6 = tuhannet  (luku / 1000)
        CPY   R11, R6
        MUL   R11, R10        ; R11 = tuhannet * 1000
        CPY   R7, R1
        SUB   R7, R11         ; R7 = jäännös

        LOAD  R10, 100
        CPY   R8, R7
        DIV   R8, R10         ; R8 = sadat  (jäännös / 100)
        CPY   R11, R8
        MUL   R11, R10        ; R11 = sadat * 100
        SUB   R7, R11         ; R7 = jäännös (kymmenet + ykköset)

        CPY   R9, R7
        DIV   R9, R4          ; R9 = kymmenet  (jäännös / 10)
        CPY   R11, R9
        MUL   R11, R4         ; R11 = kymmenet * 10
        SUB   R7, R11         ; R7 = ykköset

        ; Kirjoita tuhannet
        CPY   R11, R5
        ADD   R11, R6
        STORE [R0], R11
        ADD   R0, R3

        ; Kirjoita sadat
        CPY   R11, R5
        ADD   R11, R8
        STORE [R0], R11
        ADD   R0, R3

        ; Kirjoita kymmenet
        CPY   R11, R5
        ADD   R11, R9
        STORE [R0], R11
        ADD   R0, R3

        ; Kirjoita ykköset
        CPY   R11, R5
        ADD   R11, R7
        STORE [R0], R11
        ADD   R0, R3
        RET

; =============================================================================
; DATA
; =============================================================================
blink_flag:
        .db 0                 ; vilkkutila: 0 = ':' piilotettu, 1 = ':' näkyvissä
