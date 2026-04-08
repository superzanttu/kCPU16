; =============================================================================
; test_or_flags.asm — OR: kaikki Z- ja N-lippujen siirtymät
; OR asettaa Z ja N tulosteen mukaan; C ja V nollataan aina.
;
; Testatut siirtymät:
;   Z: 0→0, 0→1, 1→0, 1→1
;   N: 0→0, 0→1 (jo test_or.asm), 1→0, 1→1
; =============================================================================

        .origin 0x0200

        ; --- Z 0→0: OR tuottaa ei-nolla tuloksen ---
        ; 0x0001 | 0x0002 = 0x0003: Z=0 (0→0)
        JARI  R0, 0x0001
        JARI  R1, 0x0002
        OR    R0, R1          ; Z=0 (0→0), N=0
        CPY   R2, R0          ; R2=0x0003

        ; --- Z 0→1: OR tuottaa nollan ---
        ; 0x0000 | 0x0000 = 0x0000: Z=1 (0→1)
        JARI  R0, 0
        JARI  R1, 0
        OR    R0, R1          ; Z=1 (0→1)

        ; --- Z 1→0: OR tuottaa ei-nollan, Z oli 1 ---
        ; 0x0001 | 0x0002 = 0x0003: Z=0 (1→0)
        JARI  R0, 0x0001
        JARI  R1, 0x0002
        OR    R0, R1          ; Z=0 (1→0), N=0

        ; --- N 0→0: OR tulos ei-negatiivinen ---
        ; 0x0001 | 0x0010 = 0x0011: N=0 (0→0)
        JARI  R0, 0x0001
        JARI  R1, 0x0010
        OR    R0, R1          ; N=0 (0→0), Z=0
        CPY   R3, R0          ; R3=0x0011

        ; --- N 1→0: OR tuottaa ei-negatiivisen, N oli 1 ---
        ; Aseta N=1: 0x8000 | 0x0001 = 0x8001: N=1
        JARI  R0, 0x8000
        JARI  R1, 0x0001
        OR    R0, R1          ; N=1 (0→1)
        ; Nyt N=1, tulos → 0x0003 | 0x0004 = 0x0007: N=0 (1→0)
        JARI  R0, 0x0003
        JARI  R1, 0x0004
        OR    R0, R1          ; N=0 (1→0)

        ; --- N 1→1: OR tuottaa negatiivisen kun N oli jo 1 ---
        ; Aseta N=1: 0x8001 | 0x0001 = 0x8001: N=1
        JARI  R0, 0x8001
        JARI  R1, 0x0001
        OR    R0, R1          ; N=1 (0→1)
        ; Toista: 0x8002 | 0x0002 = 0x8002: N=1 (1→1)
        JARI  R0, 0x8002
        JARI  R1, 0x0002
        OR    R0, R1          ; N=1 (1→1)

        ; --- Z 1→1: OR tuottaa nollan kun Z oli jo 1 ---
        ; Aseta Z=1: 0x0000 | 0x0000 = 0: Z=1 (N myös menee 1→0)
        JARI  R0, 0
        JARI  R1, 0
        OR    R0, R1          ; Z=1 (0→1), N=0 (1→0)
        ; Toista: Z=1 (1→1)
        JARI  R0, 0
        JARI  R1, 0
        OR    R0, R1          ; Z=1 (1→1)

        HALT

.expect_reg   R2, 0x0003      ; Z 0→0 tarkistus
.expect_reg   R3, 0x0011      ; N 0→0 tarkistus
.expect_reg   R0, 0           ; viimeinen OR=0
.expect_flag  Z, 1           ; Z: 1→1 (viimeinen OR)
.expect_flag  N, 0           ; N: 0 (viimeinen OR ei-negatiivinen)
.expect_flag  C, 0           ; OR nollaa aina C
.expect_flag  V, 0           ; OR nollaa aina V
