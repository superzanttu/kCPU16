; =============================================================
; TESTI: CTMR edge caset (0 ms, 1 ms, 65535 ms)
; =============================================================
; Tavoite:
;   1) CTMR=0 ei laukaise kellokeskeytysta.
;   2) CTMR=1 ms laukeaa useasti kuormituksessa; handler poistaa
;      ajastimen kolmannen laukaisun jalkeen (deterministinen lopputila).
;   3) CTMR=65535 ms ei laukea ennenaikaisesti lyhyella suorituksella.
;
; Handler kasvattaa R7-laskuria jokaisesta INT9-keskeytyksesta.
; Kun R7 == 3, handler asettaa CTMR=0 (SCTMR R0) ja palaa.
; =============================================================

.origin 0x0200

; Aseta INT 9 handler (clock interrupt)
READ  R0, clock_handler
STORE [0x0009], R0

READ  R7, 0              ; INT9-laskuri
READ  R9, 0              ; vakiot: 0
READ  R10, 3             ; vakiot: 3
READ  R1, 1              ; vakiovahennys silmukoihin

; -------------------------------------------------------------
; Case 1: CTMR = 0 (pois paalta) -> ei keskeytyksia
; -------------------------------------------------------------
READ  R0, 0
SCTMR R0
STI
READ  R2, 1500
c1_loop:
        READ  R5, 0
        SUB   R2, R1
        JNZ   c1_loop
CMP   R7, R9
JNZ   fail

; -------------------------------------------------------------
; Case 2: CTMR = 1 ms -> 3 laukaisua, sitten handler poistaa
; -------------------------------------------------------------
READ  R0, 1
SCTMR R0
READ  R2, 9000
c2_loop:
        READ  R5, 0
        SUB   R2, R1
        JNZ   c2_loop
CMP   R7, R10
JNZ   fail
READ  R4, [CLOCK_INT_INTERVAL]
CMP   R4, R9
JNZ   fail

; -------------------------------------------------------------
; Case 3: CTMR = 65535 ms -> ei ennenaikaista laukaisua
; -------------------------------------------------------------
READ  R0, 65535
SCTMR R0
READ  R2, 3000
c3_loop:
        READ  R5, 0
        SUB   R2, R1
        JNZ   c3_loop
CMP   R7, R10
JNZ   fail

JUMP  pass

clock_handler:
        READ  R5, 1
        ADD   R7, R5
        CMP   R7, R10
        JNZ   ch_done
        CPY   R0, R9
        SCTMR R0
ch_done:
        IRET

fail:
        READ  R6, 0x0BAD
        HALT

pass:
        READ  R6, 0x0ACE
        HALT

.expect_reg   R6, 0x0ACE
.expect_reg   R7, 3
