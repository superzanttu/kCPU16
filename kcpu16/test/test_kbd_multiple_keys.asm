; =============================================================
; TESTI: Useat näppäinpainallukset peräkkäin (INT 6)
; =============================================================
; Testaa että jokainen inject_key laukaisee oman INT 6 -keskeytyksen,
; ja handler tallentaa painattujen näppäinten koodit oikein.
;
; Syötetään kolme näppäintä: 'A' (0x41), 'B' (0x42), 'C' (0x43).
; Handler tallentaa aina viimeisimmän koodin R1:een ja pitää
; kirjaa kokonaismäärästä R2:ssa.
; Lopputulos: R1 = 0x43 (viimeisin), R2 = 3 (kolme painallusta).
; =============================================================

.origin 0x0200

; Aseta INT 6 -handler
READ  R0, kbd_handler
STORE [INT_KEYBOARD], R0

; Alusta laskurit
READ  R1, 0          ; viimeisin näppäinkoodi
READ  R2, 0          ; painallustenlaskuri
READ  R3, 1          ; inkrementti

; Salli keskeytykset
STI

; Suorita tarpeeksi käskyjä jotta kaikki 3 keskeytystä ehtivät laueta.
; Jokainen käsky antaa INT-tarkistukselle mahdollisuuden laukaista.
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0
READ  R0, 0

HALT

kbd_handler:
    READ  R0, [KBD_DATA]       ; lue tapahtuma
    ; ohita vapautukset (bitti 7 = 1)
    READ  R4, KBD_RELEASE_BIT
    AND   R4, R0
    JNZ   kh_skip              ; vapautus -> ohita, ei lasketa
    ; painallus: tallenna koodi ja kasvata laskuria
    READ  R4, KBD_KEY_CODE_MASK
    AND   R0, R4               ; poista release-bitti varmuuden vuoksi
    CPY   R1, R0               ; R1 = viimeisin näppäinkoodi
    ADD   R2, R3               ; R2++
kh_skip:
    IRET

; Syötä kolme näppäintä ja niiden vapautukset
.inject_key         0x41   ; 'A' painallus
.inject_key_release 0x41   ; 'A' vapautus
.inject_key         0x42   ; 'B' painallus
.inject_key_release 0x42   ; 'B' vapautus
.inject_key         0x43   ; 'C' painallus
.inject_key_release 0x43   ; 'C' vapautus

.expect_reg  R1, 0x43      ; viimeisin painallus oli 'C'
.expect_reg  R2, 3         ; yhteensä 3 painallusta
