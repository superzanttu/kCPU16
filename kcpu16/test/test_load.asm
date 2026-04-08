; =============================================================================
; test_load.asm — JARI reg, imm
; Lataa vakioarvo rekisteriin desimaalina, heksana ja binäärinä.
; JARI ei aseta lippuja — testataan että liput säilyvät muuttumattomina.
; =============================================================================

        .origin 0x0200

        JARI  R0, 42          ; desimaali
        JARI  R1, 0xFF        ; heksadesimaali (255)
        JARI  R2, 0b1010      ; binääri (10)
        JARI  R3, 0           ; nolla — Z-lippu ei saa asettua

        HALT

.expect_reg   R0, 42
.expect_reg   R1, 255
.expect_reg   R2, 10
.expect_reg   R3, 0
; JARI ei koskaan muuta lippuja — kaikkien pitää olla nollassa
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
