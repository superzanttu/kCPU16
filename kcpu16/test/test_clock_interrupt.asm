; =============================================================
; TESTI: Kellokeskeytys (SCTMR + INT 9)
; =============================================================
; Testaa reaaliaikakelloon perustuva keskeytys:
;   - SCTMR asettaa kellokeskeytyksen välin millisekunteina
;   - STI sallii keskeytykset
;   - INT 9 laukeaa kun CTMR millisekuntia on kulunut
;
; Ajastetaan 1 ms välille ja suoritetaan 2000-kierroinen silmukka
; (noin 6000 käskyä, ~12 ms Python-tulkilla) jotta keskeytys
; ehtii laueta. Laskuri R2 on turvassa handlerilta (joka käyttää
; vain R0 ja R3).
; =============================================================

.origin 0x0200

; Aseta INT 9 handler (clock interrupt)
READ  R0, clock_handler
STORE [0x0009], R0

READ  R3, 0              ; R3 = 0 (handler asettaa 0xC10C)

; Aseta kellokeskeytys: 1 ms välein
READ  R0, 1
SCTMR R0

; Salli keskeytykset
STI

; Suorita silmukka (2000 kierrosta = noin 6000 käskyä, ~12 ms)
; jotta kellokeskeytys ehtii laueta.
READ  R2, 2000           ; silmukan laskuri
READ  R1, 1              ; vähennysarvo (ei muutu handlerin toimesta)
loop:
        READ  R0, 0          ; tyhjä käsky (viiveen kasvatus)
        SUB   R2, R1         ; R2 = R2 - 1; asettaa Z=1 kun R2=0
        JNZ   loop           ; jatka kunnes R2 = 0

HALT

clock_handler:
        READ  R3, 0xC10C       ; merkki: kellokeskeytys laukesi
        READ  R0, 0
        SCTMR R0               ; poista kellokeskeytys käytöstä
        IRET

.expect_reg   R3, 0xC10C     ; kellokeskeytys (INT 9) laukesi
