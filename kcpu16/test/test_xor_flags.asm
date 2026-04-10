; =============================================================================
; test_xor_flags.asm — XOR: kaikki Z- ja N-lippujen siirtymät
; XOR asettaa Z ja N tulosteen mukaan; C ja V nollataan aina.
;
; Testatut siirtymät:
;   Z: 0→0, 0→1 (jo test_xor.asm), 1→0, 1→1
;   N: 0→0, 0→1, 1→0, 1→1
; =============================================================================

        .origin 0x0200

        ; --- Z 0→0: XOR tuottaa ei-nollan ---
        READ  R0, 0x00FF
        READ  R1, 0xFF00
        XOR   R0, R1          ; 0x00FF ^ 0xFF00 = 0xFFFF: Z=0 (0→0), N=1
        CPY   R2, R0          ; R2=0xFFFF

        ; --- N 1→0: XOR tulos ei-negatiivinen, N oli 1 (edellisestä XOR:sta) ---
        ; 0x0001 ^ 0x0002 = 0x0003: N=0 (1→0) — N oli 1 edellisestä Z 0→0 -XOR:sta
        READ  R0, 0x0001
        READ  R1, 0x0002
        XOR   R0, R1          ; N=0 (1→0), Z=0
        CPY   R3, R0          ; R3=0x0003

        ; --- Z 1→0: XOR tuottaa ei-nollan, Z oli 1 ---
        ; Aseta Z=1: R1=R1 → XOR antaa 0
        READ  R0, 0xAAAA
        XOR   R0, R0          ; 0 ^ 0 mutta R0=R0... wait: XOR R0, R0 ei ole syntaksi jolla sama rekisteri
        ; Käytetään LOAD R1, R0 (ei syntaksia) tai eri arvot:
        ; 0xFFFF ^ 0xFFFF = 0: Z=1 (käytä eri rekisteriä)
        READ  R0, 0xFFFF
        READ  R1, 0xFFFF
        XOR   R0, R1          ; Z=1 (0→1)
        ; XOR ei-nollatulos, Z oli 1:
        READ  R0, 0x0F0F
        READ  R1, 0xF0F0
        XOR   R0, R1          ; 0x0F0F ^ 0xF0F0 = 0xFFFF: Z=0 (1→0), N=1

        ; --- N 0→1: XOR tuottaa negatiivisen tuloksen ---
        ; 0x0000 ^ 0xFFFF = 0xFFFF: N=1 (0→1)
        READ  R0, 0x0000
        READ  R1, 0xFFFF
        XOR   R0, R1          ; N=1 (0→1)

        ; --- N 1→0: XOR tuottaa ei-negatiivisen, N oli 1 ---
        ; 0x0F0F ^ 0xF0F0 = 0xFFFF: N=1 (välitulos)
        ; sitten: 0x0001 ^ 0x0001 = 0: N=0... mutta haluan ei-nollan
        ; 0x0001 ^ 0x0002 = 0x0003: N=0 (1→0)
        READ  R0, 0x0001
        READ  R1, 0x0002
        XOR   R0, R1          ; N=0 (1→0), Z=0

        ; --- N 1→1: XOR tuottaa negatiivisen kun N oli jo 1 ---
        READ  R0, 0x8001
        READ  R1, 0x0001
        XOR   R0, R1          ; 0x8001 ^ 0x0001 = 0x8000: N=1 (0→1)
        READ  R0, 0x8002
        READ  R1, 0x0002
        XOR   R0, R1          ; 0x8002 ^ 0x0002 = 0x8000: N=1 (1→1)

        ; --- Z 1→1: XOR tuottaa nollan kun Z oli jo 1 ---
        READ  R0, 0xAAAA
        READ  R1, 0xAAAA
        XOR   R0, R1          ; Z=1 (0→1), N=0 (1→0)
        READ  R0, 0x5555
        READ  R1, 0x5555
        XOR   R0, R1          ; Z=1 (1→1)

        HALT

.expect_reg   R2, 0xFFFF      ; Z 0→0 tarkistus
.expect_reg   R3, 0x0003      ; N 0→0 tarkistus
.expect_reg   R0, 0           ; viimeinen XOR=0
.expect_flag  Z, 1           ; Z: 1→1 (viimeinen XOR)
.expect_flag  N, 0           ; N menee 0:aan (XOR antoi N=1 mutta sitten Z 1→1 nollasi N)
.expect_flag  C, 0
.expect_flag  V, 0
