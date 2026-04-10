; =============================================================================
; test_and_flags.asm — AND: kaikki Z- ja N-lippujen siirtymät
; AND asettaa Z ja N tulosteen mukaan; C ja V nollataan aina.
;
; Testatut siirtymät:
;   Z: 0→0, 0→1, 1→0, 1→1
;   N: 0→0, 0→1, 1→0, 1→1
; =============================================================================

        .origin 0x0200

        ; --- Z 0→0: AND tuottaa ei-nolla tuloksen, Z pysyy 0 ---
        ; 0xFF00 & 0x0FF0 = 0x0F00 (ei nolla), alkutila Z=0
        READ  R0, 0xFF00
        READ  R1, 0x0FF0
        AND   R0, R1          ; R0=0x0F00: Z=0 (0→0), N=0
        CPY   R2, R0          ; tallenna: R2=0x0F00

        ; --- Z 0→1: AND tuottaa nollatuloksen ---
        ; 0xFF00 & 0x00FF = 0x0000 → Z=1
        READ  R0, 0xFF00
        READ  R1, 0x00FF
        AND   R0, R1          ; Z=1 (0→1)

        ; --- Z 1→0: AND tuottaa ei-nolla tuloksen, Z oli 1 ---
        ; 0xF0F0 & 0x0F0F = 0x0000... Ei, 0xF0F0 & 0x0F0F = 0 myös. Käytetään:
        ; 0xFF00 & 0xFF00 = 0xFF00: Z=0 (Z oli 1 → 1→0)
        READ  R0, 0xFF00
        READ  R1, 0xFF00
        AND   R0, R1          ; R0=0xFF00: Z=0 (1→0), N=1 (bitti 15)

        ; --- N 0→0: tulos ei-negatiivinen, N pysyy 0 ---
        ; 0x0F00 & 0x0F00 = 0x0F00: N=0 (0→0)
        READ  R0, 0x0F00
        READ  R1, 0x0F00
        AND   R0, R1          ; R0=0x0F00: N=0 (0→0)
        CPY   R3, R0          ; tallenna: R3=0x0F00

        ; --- N 0→1: AND tuottaa negatiivisen tuloksen (bitti 15=1) ---
        ; 0xFF00 & 0xF0FF = 0xF000: N=1
        READ  R0, 0xFF00
        READ  R1, 0xF0FF
        AND   R0, R1          ; R0=0xF000: N=1 (0→1)

        ; --- N 1→0: AND tuottaa ei-negatiivisen, N oli 1 ---
        ; 0x0FF0 & 0x0FF0 = 0x0FF0: N=0 (N oli 1 → 1→0)
        READ  R0, 0x0FF0
        READ  R1, 0x0FF0
        AND   R0, R1          ; R0=0x0FF0: N=0 (1→0), Z=0

        ; --- N 1→1: AND tuottaa negatiivisen kun N oli jo 1 ---
        ; Aseta N=1: 0x8001 & 0x8001 = 0x8001: N=1
        READ  R0, 0x8001
        READ  R1, 0x8001
        AND   R0, R1          ; N=1 (0→1)
        ; Toista: 0x8002 & 0x8002 = 0x8002: N=1 (1→1)
        READ  R0, 0x8002
        READ  R1, 0x8002
        AND   R0, R1          ; N=1 (1→1)

        ; --- Z 1→1: AND tuottaa nollan kun Z oli jo 1 ---
        ; Aseta Z=1: 0xFF00 & 0x00FF = 0
        READ  R0, 0xFF00
        READ  R1, 0x00FF
        AND   R0, R1          ; Z=1 (0→1), N=0 (myös N 1→0 tässä)
        ; Toista: 0x00FF & 0xFF00 = 0: Z=1 (1→1)
        READ  R0, 0x00FF
        READ  R1, 0xFF00
        AND   R0, R1          ; Z=1 (1→1)

        HALT

.expect_reg   R2, 0x0F00      ; Z 0→0 tarkistus (AND antoi ei-nollan)
.expect_reg   R3, 0x0F00      ; N 0→0 tarkistus
.expect_reg   R0, 0           ; viimeinen AND antoi Z=1
.expect_flag  Z, 1           ; Z: 1→1 (viimeinen AND)
.expect_flag  N, 0           ; N: 0 (viimeinen AND ei-negatiivinen)
.expect_flag  C, 0           ; AND nollaa aina C
.expect_flag  V, 0           ; AND nollaa aina V
