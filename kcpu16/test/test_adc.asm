; =============================================================================
; test_adc.asm — ADC regD, regS
; Yhteenlasku carry-lipun kanssa: regD = regD + regS + C.
; Asetetaan ensin C=1 tekemällä ylivuotava ADD, sitten testataan ADC.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: Aseta carry=1 kaatumalla yli 0xFFFF
        JARI  R0, 0xFFFF
        JARI  R1, 1
        ADD   R0, R1          ; 0xFFFF + 1 → R0=0, C=1

        ; Vaihe 2: ADC käyttää C=1:n
        JARI  R2, 10
        JARI  R3, 5
        ADC   R2, R3          ; 10 + 5 + 1(carry) = 16

        HALT

.expect_reg   R2, 16
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
