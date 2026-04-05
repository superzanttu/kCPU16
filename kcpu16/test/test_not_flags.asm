; =============================================================================
; test_not_flags.asm — NOT: kaikki Z- ja N-lippujen siirtymät
; NOT asettaa Z ja N tulosteen mukaan; C ja V nollataan aina.
;
; Testatut siirtymät:
;   Z: 0→0, 0→1 (jo test_not.asm), 1→0, 1→1
;   N: 0→0, 0→1, 1→0 (jo test_not.asm), 1→1
; Huom: test_not.asm tarkistaa lopputilana Z=1, N=0, mutta ei tarkista
;        N=1 eksplisiittisesti (vain välitiloissa).
; =============================================================================

        .origin 0x0200

        ; --- N 0→1: NOT tuottaa negatiivisen tuloksen ---
        ; ~0x0000 = 0xFFFF: N=1 (0→1)
        LOAD  R0, 0x0000
        NOT   R0              ; R0=0xFFFF: N=1 (0→1)
        CPY   R1, R0          ; tallenna: R1=0xFFFF

        ; --- N 1→1: NOT tuottaa negatiivisen kun N oli jo 1 ---
        ; ~0x0001 = 0xFFFE: N=1 (1→1)
        LOAD  R0, 0x0001
        NOT   R0              ; R0=0xFFFE: N=1 (1→1)

        ; --- Z 0→0: NOT tuottaa ei-nollan ---
        ; ~0x0001 = 0xFFFE (jo yllä), Z=0 (0→0)
        CPY   R2, R0          ; R2=0xFFFE (Z=0 tarkistus väliarvo)

        ; --- N 1→0: NOT tuottaa positiivisen, N oli 1 ---
        ; ~0xFFFF = 0x0000: Z=1, N=0 (N:1→0)
        LOAD  R0, 0xFFFF
        NOT   R0              ; R0=0x0000: Z=1, N=0 (N:1→0)
        CPY   R3, R0          ; R3=0 (Z 0→1 tarkistus)

        ; --- Z 1→0: NOT tuottaa ei-nollan, Z oli 1 ---
        ; ~0x0001 = 0xFFFE: Z=0 (Z:1→0, N:0→1)
        LOAD  R0, 0x0001
        NOT   R0              ; R0=0xFFFE: Z=0 (1→0), N=1 (0→1)

        ; --- Z 1→1: NOT tuottaa nollan kun Z oli jo 1 ---
        ; Ensin Z=1: ~0x7FFF = 0x8000: Z=0, N=1 — ei anna Z=1
        ; Z=1 saadaan: ~0xFFFF = 0x0000 (Z=1, N=0)
        LOAD  R0, 0xFFFF
        NOT   R0              ; Z=1 (0→1; mutta Z oli 0 juuri äsken)
        ; Nyt Z=1. NOT joka antaa Z=1 uudelleen:
        LOAD  R0, 0xFFFF
        NOT   R0              ; Z=1 (1→1)

        ; --- N 1→1 loppuarvo tarkistus ---
        ; Tehdään vielä yksi N:1→1 jonka voi tarkistaa lopputilassa
        ; Mutta Z on nyt 1 (0x0000). Teemme NOT joka antaa N=1 tarkistaaksemme N:1→1:
        ; Ensin aseta N=1 (Z oli 1 → N 0→1):
        LOAD  R0, 0x0001
        NOT   R0              ; ~0x0001=0xFFFE: N=1 (0→1), Z=0 (1→0)
        ; Nyt N=1. NOT joka antaa N=1 uudelleen:
        LOAD  R0, 0x0001
        NOT   R0              ; ~0x0001=0xFFFE: N=1 (1→1)

        HALT

.expect_reg   R0, 0xFFFE      ; viimeinen NOT: ~0x0001
.expect_reg   R1, 0xFFFF      ; N 0→1 tarkistus
.expect_reg   R2, 0xFFFE      ; Z 0→0 tarkistus
.expect_reg   R3, 0           ; N 1→0 + Z 0→1 tarkistus
.expect_flag  N, 1           ; N: 1→1 (viimeinen NOT)
.expect_flag  Z, 0           ; Z=0 (viimeinen NOT ei-nolla)
.expect_flag  C, 0
.expect_flag  V, 0
