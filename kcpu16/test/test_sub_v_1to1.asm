; =============================================================================
; test_sub_v_1to1.asm — SUB: V-lippu 1→1 (itsenäinen tarkistus)
; 0x8000 - 1 = 0x7FFF:
;   V=1 (etumerkillinen ylivuoto: −32768 − 1 = −32769 → kääntyy +32767)
;   N=0 (tulos 0x7FFF, bitti 15 = 0)
; Toistetaan → V:1→1 erikseen N:n kanssa joka pysyy 0:ssa.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta V=1 (0→1)
        READ  R0, 0x8000
        READ  R1, 1
        SUB   R0, R1          ; 0x8000-1=0x7FFF: V=1, N=0, C=0, Z=0

        ; Vaihe 2: sama operaatio → V:1→1
        READ  R0, 0x8000
        READ  R1, 1
        SUB   R0, R1          ; 0x7FFF: V=1 (1→1)

        HALT

.expect_reg   R0, 0x7FFF
.expect_flag  V, 1           ; V: 1→1
.expect_flag  N, 0           ; N: 0→0 (tulos ei-negatiivinen)
.expect_flag  C, 0
.expect_flag  Z, 0
