; =============================================================
; TESTI: .dw ja .db direktiivit — kattava arvoalue
; =============================================================
; Testaa .dw ja .db direktiivien toiminta eri arvoilla:
;   .dw: etumerkitön (0–65535), heksadesimaali, etumerkillinen (-32768 – -1)
;   .db: etumerkitön (0–255), heksadesimaali, etumerkillinen (-128 – -1)
;
; Kaikki arvot maskataan 16- tai 8-bittisiksi ennen tallentamista
; (& 0xFFFF tai & 0xFF). Etumerkilliset arvot tulkitaan 2-komplementtina.
;
; Muistiosoitteet (origin 0x0200, JUMP start = 2 sanaa):
;   DW_DATA: 0x0202 – 0x0207  (6 x .dw)
;   DB_DATA: 0x0208 – 0x020D  (6 x .db)
;   start:   0x020E            (HALT)
; =============================================================

.origin 0x0200

    JUMP start

; --- .dw-data: 16-bittiset sanat ---
DW_DATA:
    .dw 0              ; 0x0202: nolla
    .dw 65535          ; 0x0203: maksimi etumerkitön (0xFFFF)
    .dw 0x1234         ; 0x0204: heksadesimaaliarvo
    .dw -1             ; 0x0205: -1 & 0xFFFF = 65535
    .dw -32768         ; 0x0206: -32768 & 0xFFFF = 32768 (0x8000)
    .dw 100            ; 0x0207: positiivinen desimaali

; --- .db-data: 8-bittiset arvot (maskattu 0xFF) ---
DB_DATA:
    .db 0              ; 0x0208: nolla
    .db 255            ; 0x0209: maksimi (0xFF)
    .db 0x41           ; 0x020A: 'A' = 65
    .db -1             ; 0x020B: -1 & 0xFF = 255
    .db -128           ; 0x020C: -128 & 0xFF = 128 (0x80)
    .db 127            ; 0x020D: maksimi etumerkillinen

start:
    HALT

; --- Odotukset: .dw ---
.expect_mem 0x0202, 0        ; .dw 0
.expect_mem 0x0203, 65535    ; .dw 65535 = 0xFFFF
.expect_mem 0x0204, 0x1234   ; .dw 0x1234 = 4660
.expect_mem 0x0205, 65535    ; .dw -1 → 0xFFFF
.expect_mem 0x0206, 32768    ; .dw -32768 → 0x8000
.expect_mem 0x0207, 100      ; .dw 100

; --- Odotukset: .db ---
.expect_mem 0x0208, 0        ; .db 0
.expect_mem 0x0209, 255      ; .db 255 = 0xFF
.expect_mem 0x020A, 65       ; .db 0x41 = 65
.expect_mem 0x020B, 255      ; .db -1 → 0xFF
.expect_mem 0x020C, 128      ; .db -128 → 0x80
.expect_mem 0x020D, 127      ; .db 127
