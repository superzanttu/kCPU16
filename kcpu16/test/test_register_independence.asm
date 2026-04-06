; =============================================================================
; test_register_independence.asm — rekisterit R0–R3 ja FP ovat itsenäisiä
; Varmistaa että operaatio yhteen rekisteriin ei korruptoi muita rekistereitä.
; Testataan:
;   - ADD kohderekisteri muuttuu, lähde pysyy ennallaan
;   - SUB kohderekisteri muuttuu, muut pysyvät ennallaan
;   - CPY kirjoittaa kohteen, lähde ja muut rekisterit muuttumattomia
;   - LOAD yhteen rekisteriin ei vaikuta muihin
;   - FP on itsenäinen R0–R3:sta
; =============================================================================

.origin 0x0200

; Lataa kaikki rekisterit eri arvoilla
LOAD  R0, 0x1111
LOAD  R1, 0x2222
LOAD  R2, 0x3333
LOAD  R3, 0x4444
LOAD  FP, 0x0500

; ADD R0, R1: vain R0 muuttuu, R1/R2/R3/FP säilyvät
ADD   R0, R1          ; R0 = 0x1111 + 0x2222 = 0x3333

; SUB R2, R1: vain R2 muuttuu, R0/R1/R3/FP säilyvät
SUB   R2, R1          ; R2 = 0x3333 - 0x2222 = 0x1111

; CPY R3, R0: vain R3 muuttuu, R0 on lähde joten se pysyy, R1/R2/FP säilyvät
CPY   R3, R0          ; R3 = 0x3333

; LOAD R1 ei vaikuta muihin
LOAD  R1, 0x9999      ; R1 = 0x9999, muut ennallaan

HALT

.expect_reg   R0, 0x3333     ; ADD-tulos (0x1111 + 0x2222)
.expect_reg   R1, 0x9999     ; LOAD:n arvo
.expect_reg   R2, 0x1111     ; SUB-tulos (0x3333 - 0x2222)
.expect_reg   R3, 0x3333     ; CPY:n arvo (kopio R0:sta)
.expect_reg   FP, 0x0500     ; FP muuttumaton kaikkien operaatioiden läpi
