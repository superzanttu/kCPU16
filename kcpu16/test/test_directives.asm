; =============================================================
; TESTI: .origin, .db, .dstr, .at -direktiivit
; =============================================================
; Testaa assembler-direktiivien oikea toiminta:
; - .origin asettaa ohjelman aloitusosoitteen
; - .db tallentaa raakadataa muistiin
; - .dstr tallentaa null-terminoidun merkkijonon
; - .at vaihtaa segmentin uuteen osoitteeseen
; =============================================================

.origin 0x0200

; --- .db testi: raakadata osoitteesta DATA_BYTES ---
JUMP start

DATA_BYTES:
    .db 0x41, 0x42, 0x43     ; A, B, C (65, 66, 67)

DATA_NUMS:
    .db 0, 127, 255           ; reunatapaukset

STR_DATA:
    .dstr "Hi"                ; H=72, i=105, null=0 -> 3 sanaa

start:
; Lue .db-data
READ R0, [DATA_BYTES]  ; mem[DATA_BYTES] = 0x41 = 65
READ R1, [DATA_NUMS]  ; mem[DATA_NUMS] = 0
; Lue .dstr-data
READ R2, [STR_DATA]  ; mem[STR_DATA] = 72 ('H')

; Lue .at-segmenttiin kirjoitettu data
READ R3, [0x0400]  ; .at-segmentistä: 0xBE

HALT

; --- .at testi: data eri segmenttiin ---
.at 0x0400
AT_DATA:
    .db 0xBE, 0xEF

; --- Odotukset ---
.expect_reg   R0, 65         ; 'A' = 0x41
.expect_reg   R1, 0          ; ensimmäinen DATA_NUMS-arvo
.expect_reg   R2, 72         ; 'H' = 0x48
.expect_reg   R3, 0xBE       ; .at-segmentin data
.expect_mem   0x0202, 65     ; DATA_BYTES = 0x0200 + 2 (JUMP on 2 sanaa)
.expect_mem   0x0400, 0xBE
.expect_mem   0x0401, 0xEF
