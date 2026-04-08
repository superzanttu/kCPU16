; =============================================================================
; test_adc_nv_1to1.asm — ADC: V-lippu 1→1
; Asetetaan V=1 (ADD 0x8000+0x8000 → C=1, V=1),
; sitten ADC 0x7FFE+1+C(1)=0x8000 → V=1 uudelleen (V:1→1).
; Samalla N:0→1 ja N:1→1 (kahdessa vaiheessa).
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: aseta C=1, V=1 ADD:lla
        JARI  R0, 0x8000
        JARI  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; Vaihe 2: ADC 0x7FFE+1+C(1)=0x8000 → V=1 (V:1→1), N=1 (N:0→1), C=0
        JARI  R0, 0x7FFE
        JARI  R1, 1
        ADC   R0, R1          ; 0x8000: V=1 (1→1), N=1, C=0, Z=0

        ; Vaihe 3: ADC 0x8001+0+0=0x8001 → N=1 (N:1→1), V=0
        JARI  R0, 0x8001
        JARI  R1, 0
        ADC   R0, R1          ; 0x8001: N=1 (1→1), V=0, C=0, Z=0

        HALT

.expect_reg   R0, 0x8001
.expect_flag  N, 1           ; N: 1→1
.expect_flag  V, 0           ; V nollautuu (0x8001+0 ei etumerkki-ylivuoto)
.expect_flag  Z, 0
.expect_flag  C, 0
