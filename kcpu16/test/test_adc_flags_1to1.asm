; =============================================================================
; test_adc_flags_1to1.asm — ADC: Z, C liput 1→1
; ADC käyttää carry-lipun syötteenä JA tuottaa uuden carry-lipun.
; Demonstraatio: jos C=1 ennen ADC:ta ja ADC tuottaa C=1, se on C:1→1.
;
; Käytetään: ADD → C=1, sitten ADC 0xFFFF + 0 + C(1) = 0x10000 → Z=1, C=1
; Toistetaan → Z:1→1, C:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1 ADD:lla
        JARI  R0, 0xFFFF
        JARI  R1, 1
        ADD   R0, R1          ; 0xFFFF+1=0x10000→0: C=1, Z=1, N=0, V=0

        ; Vaihe 2: ADC ylivuotaa → Z=1, C=1 (Z:1→1, C:1→1)
        JARI  R0, 0xFFFF
        JARI  R1, 0
        ADC   R0, R1          ; 0xFFFF+0+1(C)=0x10000→0: Z=1, C=1

        ; Vaihe 3: ADC ylivuotaa uudelleen → Z:1→1, C:1→1
        JARI  R0, 0xFFFF
        JARI  R1, 0
        ADC   R0, R1          ; 0xFFFF+0+1(C)=0x10000→0: Z=1, C=1 (1→1)

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  C, 1           ; C: 1→1
.expect_flag  N, 0
.expect_flag  V, 0
