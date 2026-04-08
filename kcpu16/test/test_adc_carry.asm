; =============================================================================
; test_adc_carry.asm — ADC oma carry-lippu
; ADC tuottaa itse carry:n kun tulos ylittää 16-bitin rajan.
; Carry asetetaan ensin ADD:lla, sitten ADC:n oma tulos myös ylivuotaa.
; 0xFFFE + 1 + C(1) = 0x10000 → R2=0, C=1, Z=1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: Aseta C=1 ylivuotavalla ADD:lla
        JARI  R0, 0xFFFF
        JARI  R1, 1
        ADD   R0, R1          ; 0xFFFF + 1 → R0=0, C=1

        ; Vaihe 2: ADC ylivuotaa itse — oma carry syntyy
        JARI  R2, 0xFFFE
        JARI  R3, 1
        ADC   R2, R3          ; 0xFFFE + 1 + 1(carry) = 0x10000 → R2=0, C=1

        HALT

.expect_reg   R2, 0
.expect_flag  Z, 1
.expect_flag  C, 1
.expect_flag  N, 0
.expect_flag  V, 0
