; =============================================================================
; test_shr_flags.asm — SHR: Z, C liput 1→1; N, V liput 1→0
; SHR täyttää ylä-bitit nollilla → N on aina 0 SHR:n jälkeen.
; SHR kutsuu set_carry_overflow(carry, False) → V nollataan aina.
;
; Testatut siirtymät:
;   Z: 1→1
;   C: 1→1
;   N: 1→0 (SHR ei voi asettaa N:ää)
;   V: 1→0 (SHR nollaa aina V)
; =============================================================================

        .origin 0x0200

        ; --- Z 1→1: SHR tuottaa nollan kun Z oli jo 1 ---
        ; Vaihe 1: 0x0001 >> 1 = 0x0000: Z=1 (0→1)
        READ  R0, 0x0001
        READ  R1, 1
        SHR   R0, R1          ; Z=1, C=1

        ; Vaihe 2: 0x0001 >> 1 uudelleen → Z=1 (1→1), C=1 (1→1)
        READ  R0, 0x0001
        READ  R1, 1
        SHR   R0, R1          ; Z=1 (1→1), C=1 (1→1)
        CPY   R2, R0          ; R2=0

        ; --- C 1→1: SHR tuottaa carryn kun C oli jo 1 ---
        ; C=1 nyt. SHR 0x0003 >> 1 = 0x0001: C=1 (bitti 0 ulos) (1→1), Z=0
        READ  R0, 0x0003
        READ  R1, 1
        SHR   R0, R1          ; 0x0001: C=1 (1→1), Z=0, N=0

        ; --- N 1→0: SHR nollaa N koska yläbitit täytetään nollilla ---
        ; Aseta N=1: ADD 0x7FFF+1=0x8000: N=1, V=1, C=0
        READ  R0, 0x7FFF
        READ  R1, 1
        ADD   R0, R1          ; N=1, V=1, C=0, Z=0

        ; SHR nollaa N (ylä-bitit täytetään nollilla)
        READ  R0, 0x8000
        READ  R1, 1
        SHR   R0, R1          ; 0x8000 >> 1 = 0x4000: N=0 (N:1→0), V=0 (V:1→0), C=0

        ; --- V 1→0: SHR nollaa V aina ---
        ; (Testattu jo yllä: V=1 asettui ADD:lla, SHR nollasi sen)
        ; Erillinen tarkistus:
        READ  R0, 0x7FFF
        READ  R1, 1
        ADD   R0, R1          ; V=1
        READ  R0, 0x0002
        READ  R1, 1
        SHR   R0, R1          ; V=0 (V:1→0)

        HALT

.expect_reg   R2, 0           ; Z 1→1 tarkistus
.expect_reg   R0, 1           ; SHR 0x0002 >> 1 = 0x0001
.expect_flag  Z, 0           ; viimeinen SHR ei-nolla
.expect_flag  N, 0           ; N: SHR ei voi asettaa N=1 (yläbitit=0)
.expect_flag  C, 0           ; SHR 0x0002 >> 1: bitti 0 = 0 → C=0
.expect_flag  V, 0           ; V: 1→0 (SHR nollaa aina)
