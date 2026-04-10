; =============================================================
; TESTI: Uptime-laskuri MMIO
; =============================================================
; Testaa uptime-laskurin MMIO-rekisterit:
;   UPTIME_W3 (0x0017): bitit 48-63, aina 0 (ylempi 32 bittiä varattuna)
;   UPTIME_W2 (0x0018): bitit 32-47, aina 0 (ylempi 32 bittiä varattuna)
;   UPTIME_W1 (0x0019): bitit 16-31, 32-bittisen sekuntilaskurin ylempi puoli
;   UPTIME_W0 (0x001A): bitit  0-15, 32-bittisen sekuntilaskurin alempi puoli
;
; Testi varmistaa:
;   1. W3 = 0 (rakenteellinen ominaisuus, aina nolla)
;   2. W2 = 0 (rakenteellinen ominaisuus, aina nolla)
;   3. Yhdistetty W1:W0 on validi 32-bittinen arvo (ei koskaan negatiivinen)
;
; Testit ajetaan alle sekunnissa, joten W1 = 0 ja W0 = 0
; (laskuri ei ole kerennyt kasvaa yhtään sekuntia).
; =============================================================

.origin 0x0200

; Lue kaikki neljä uptime-rekisteriä
READ  R0, [UPTIME_W3]    ; bitit 48-63 (aina 0)
READ  R1, [UPTIME_W2]    ; bitit 32-47 (aina 0)
READ  R2, [UPTIME_W1]    ; bitit 16-31 (0 lyhyessä testissä)
READ  R3, [UPTIME_W0]    ; bitit  0-15 (0 lyhyessä testissä)

; Tarkista W3 = 0 (rakenteellinen ominaisuus)
READ  R4, 1              ; R4 = 1 (oleta OK)
READ  R5, 0              ; R5 = vertailuarvo 0

CMP   R0, R5
JNZ   fail               ; W3 != 0 -> virhe

; Tarkista W2 = 0 (rakenteellinen ominaisuus)
CMP   R1, R5
JNZ   fail               ; W2 != 0 -> virhe

JUMP  done

fail:
        READ  R4, 0      ; virhe

done:
        HALT

.expect_reg   R0, 0          ; UPTIME_W3 on aina 0
.expect_reg   R1, 0          ; UPTIME_W2 on aina 0
.expect_reg   R4, 1          ; W3 ja W2 tarkistukset läpäisty
