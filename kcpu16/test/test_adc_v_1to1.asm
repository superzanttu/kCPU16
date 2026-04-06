; =============================================================================
; test_adc_v_1to1.asm — ADC: V-lippu erikseen 1→1 (eksplisiittinen loppuarvo)
; Asetetaan V=1 ADD:lla, sitten ADC tuottaa V=1 uudelleen → V:1→1.
; ADD 0x8000+0x8000 → C=1, V=1
; ADC 0x7FFE+1+C(1)=0x8000 → V=1, N=1 (V:1→1)
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1, V=1 ADD:lla
        LOAD  R0, 0x8000
        LOAD  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; Vaihe 2: ADC tuottaa V=1 uudelleen → V:1→1
        ; 0x7FFE + 1 + 1(C) = 0x8000: +16382+1+1 = +16384... wait:
        ; a=0x7FFE(+32766), b=0x0001(+1), c=1 → 32768=0x8000 → V=1
        LOAD  R0, 0x7FFE
        LOAD  R1, 1
        ADC   R0, R1          ; 0x8000: V=1 (1→1), N=1, C=0, Z=0

        HALT

.expect_reg   R0, 0x8000
.expect_flag  V, 1           ; V: 1→1 (etumerkillinen ylivuoto uudelleen)
.expect_flag  N, 1           ; N: bitti 15 asetettu
.expect_flag  C, 0
.expect_flag  Z, 0
