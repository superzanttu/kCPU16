; =============================================================================
; lib-math.asm — Yleisiä matemaattisia apurutiineja
; =============================================================================
;
; KUVAUS:
;   Yleiskäyttöinen matematiikkakirjasto assembly-ohjelmille. Kokoaa yhteen
;   tyypilliset vertailu-, rajaus- ja lukusarjarutiinit, joita useissa demoissa
;   on toteutettu paikallisesti.
;
; TOIMINNOT:
;   math_abs       — Palauta itseisarvo
;   math_min       — Palauta pienempi kahdesta arvosta
;   math_max       — Palauta suurempi kahdesta arvosta
;   math_clamp     — Rajaa arvo annetulle välille
;   math_gcd       — Laske suurin yhteinen tekijä
;   math_factorial — Laske kertoma
;   math_fibonacci — Laske Fibonacci-luku
;
; HUOM:
;   Rutiinit on tarkoitettu helposti uudelleenkäytettäviksi rakennuspalikoiksi.
;   Ne eivät käsittele kaikkia mahdollisia ylivuotoja tai erikoistapauksia.
; =============================================================================

; =============================================================================
; math_abs
;
; Sisään:  R0 = etumerkillinen 16-bittinen arvo
; Ulos:    R0 = itseisarvo
; Clobbers: R1–R2
; =============================================================================

math_abs:
        READ  R1, 0x8000
        CPY   R2, R0
        AND   R2, R1
        READ  R1, 0
        CMP   R2, R1
        JZ    _math_abs_done
        NOT   R0
        READ  R1, 1
        ADD   R0, R1
_math_abs_done:
        RET

; =============================================================================
; math_min
;
; Sisään:  R0 = arvo A, R1 = arvo B
; Ulos:    R0 = pienempi arvo
; Clobbers: —
; =============================================================================

math_min:
        CMP   R0, R1
        JLE   _math_min_done
        CPY   R0, R1
_math_min_done:
        RET

; =============================================================================
; math_max
;
; Sisään:  R0 = arvo A, R1 = arvo B
; Ulos:    R0 = suurempi arvo
; Clobbers: —
; =============================================================================

math_max:
        CMP   R0, R1
        JGE   _math_max_done
        CPY   R0, R1
_math_max_done:
        RET

; =============================================================================
; math_clamp
;
; Sisään:  R0 = arvo, R1 = minimi, R2 = maksimi
; Ulos:    R0 = rajattu arvo
; Clobbers: —
; =============================================================================

math_clamp:
        CMP   R0, R1
        JGE   _math_clamp_check_max
        CPY   R0, R1
        RET
_math_clamp_check_max:
        CMP   R0, R2
        JLE   _math_clamp_done
        CPY   R0, R2
_math_clamp_done:
        RET

; =============================================================================
; math_gcd
;
; Sisään:  R0 = arvo A, R1 = arvo B
; Ulos:    R0 = suurin yhteinen tekijä
; Clobbers: R1–R3
;
; Toteuttaa vähennykseen perustuvan Eukleideen algoritmin.
; =============================================================================

math_gcd:
        PUSH  R1
        CALL  math_abs
        POP   R1
        PUSH  R0
        CPY   R0, R1
        CALL  math_abs
        CPY   R1, R0
        POP   R0
        READ  R2, 0
_math_gcd_outer:
        CMP   R1, R2
        JZ    _math_gcd_done
_math_gcd_reduce:
        CMP   R0, R1
        JLT   _math_gcd_swap
        SUB   R0, R1
        JUMP  _math_gcd_reduce
_math_gcd_swap:
        CPY   R3, R0
        CPY   R0, R1
        CPY   R1, R3
        JUMP  _math_gcd_outer
_math_gcd_done:
        RET

; =============================================================================
; math_factorial
;
; Sisään:  R0 = n
; Ulos:    R0 = n!
; Clobbers: R1–R2
; =============================================================================

math_factorial:
        READ  R1, 1
        READ  R2, 1
_math_factorial_loop:
        CMP   R0, R2
        JLE   _math_factorial_done
        MUL   R1, R0
        SUB   R0, R2
        JUMP  _math_factorial_loop
_math_factorial_done:
        CPY   R0, R1
        RET

; =============================================================================
; math_fibonacci
;
; Sisään:  R0 = n
; Ulos:    R0 = fibonacci(n)
; Clobbers: R1–R4
; =============================================================================

math_fibonacci:
        READ  R1, 0
        READ  R2, 1
        READ  R3, 0
        CMP   R0, R3
        JZ    _math_fib_return_prev
        READ  R3, 1
        CMP   R0, R3
        JZ    _math_fib_return_curr
        READ  R3, 1
_math_fib_loop:
        CMP   R3, R0
        JGE   _math_fib_return_curr
        CPY   R4, R1
        ADD   R4, R2
        CPY   R1, R2
        CPY   R2, R4
        READ  R4, 1
        ADD   R3, R4
        JUMP  _math_fib_loop
_math_fib_return_prev:
        CPY   R0, R1
        RET
_math_fib_return_curr:
        CPY   R0, R2
        RET
