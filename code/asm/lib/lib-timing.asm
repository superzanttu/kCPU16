; =============================================================================
; lib-timing.asm — Kellon ja ajastuksen apurutiinit
; =============================================================================
;
; KUVAUS:
;   Kokoaa yhteen tavallisimmat kelloon perustuvat apurutiinit. Kirjasto sopii
;   demoihin, peleihin ja mittausohjelmiin, joissa tarvitaan odotusta,
;   sekuntirajojen tunnistusta tai ajastinkeskeytyksen asetusta.
;
; TOIMINNOT:
;   time_get_date         — Lue päiväys
;   time_get_clock        — Lue kellonaika
;   time_get_clock_full   — Lue kellonaika millisekunteineen
;   time_wait_next_second — Odota seuraavaa sekuntia
;   time_wait_seconds     — Odota useita sekunteja
;   time_wait_millis_tick — Odota millisekunnin muutosta
;   time_set_timer_interval — Aseta ajastinkeskeytyksen väli
;   time_stop_timer       — Pysäytä ajastinkeskeytys
; =============================================================================

; =============================================================================
; time_get_date
;
; Sisään:  —
; Ulos:    R0 = vuosi, R1 = kuukausi, R2 = päivä
; Clobbers: —
; =============================================================================

time_get_date:
        READ  R0, [CLOCK_YEAR]
        READ  R1, [CLOCK_MONTH]
        READ  R2, [CLOCK_DAY]
        RET

; =============================================================================
; time_get_clock
;
; Sisään:  —
; Ulos:    R0 = tunti, R1 = minuutti, R2 = sekunti
; Clobbers: —
; =============================================================================

time_get_clock:
        READ  R0, [CLOCK_HOUR]
        READ  R1, [CLOCK_MINUTE]
        READ  R2, [CLOCK_SECOND]
        RET

; =============================================================================
; time_get_clock_full
;
; Sisään:  —
; Ulos:    R0 = tunti, R1 = minuutti, R2 = sekunti, R3 = millisekunti
; Clobbers: —
; =============================================================================

time_get_clock_full:
        READ  R0, [CLOCK_HOUR]
        READ  R1, [CLOCK_MINUTE]
        READ  R2, [CLOCK_SECOND]
        READ  R3, [CLOCK_MILLIS]
        RET

; =============================================================================
; time_wait_next_second
;
; Sisään:  —
; Ulos:    R0 = uusi sekuntiarvo
; Clobbers: R1
; =============================================================================

time_wait_next_second:
        READ  R1, [CLOCK_SECOND]
_time_wait_next_second_loop:
        READ  R0, [CLOCK_SECOND]
        CMP   R0, R1
        JZ    _time_wait_next_second_loop
        RET

; =============================================================================
; time_wait_seconds
;
; Sisään:  R0 = odotettavien sekuntien määrä
; Ulos:    —
; Clobbers: R0–R1
; =============================================================================

time_wait_seconds:
        READ  R1, 0
_time_wait_seconds_loop:
        CMP   R0, R1
        JZ    _time_wait_seconds_done
        CALL  time_wait_next_second
        READ  R1, 1
        SUB   R0, R1
        READ  R1, 0
        JUMP  _time_wait_seconds_loop
_time_wait_seconds_done:
        RET

; =============================================================================
; time_wait_millis_tick
;
; Sisään:  —
; Ulos:    R0 = uusi millisekuntiarvo
; Clobbers: R1
; =============================================================================

time_wait_millis_tick:
        READ  R1, [CLOCK_MILLIS]
_time_wait_millis_loop:
        READ  R0, [CLOCK_MILLIS]
        CMP   R0, R1
        JZ    _time_wait_millis_loop
        RET

; =============================================================================
; time_set_timer_interval
;
; Sisään:  R0 = väli millisekunteina
; Ulos:    —
; Clobbers: —
; =============================================================================

time_set_timer_interval:
        SCTMR R0
        RET

; =============================================================================
; time_stop_timer
;
; Sisään:  —
; Ulos:    —
; Clobbers: R0
; =============================================================================

time_stop_timer:
        READ  R0, 0
        SCTMR R0
        RET
