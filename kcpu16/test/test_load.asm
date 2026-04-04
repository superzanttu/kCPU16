; =============================================================================
; test_load.asm — LOAD reg, imm
; Lataa vakioarvo rekisteriin desimaalina, heksana ja binäärinä.
; LOAD ei aseta lippuja — testataan että liput säilyvät muuttumattomina.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 42          ; desimaali
        LOAD  R1, 0xFF        ; heksadesimaali (255)
        LOAD  R2, 0b1010      ; binääri (10)
        LOAD  R3, 0           ; nolla — Z-lippu ei saa asettua

        HALT

.expect_reg   R0, 42
.expect_reg   R1, 255
.expect_reg   R2, 10
.expect_reg   R3, 0
; LOAD ei koskaan muuta lippuja — kaikkien pitää olla nollassa
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
