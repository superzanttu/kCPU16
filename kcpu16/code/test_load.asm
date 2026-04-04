; =============================================================================
; test_load.asm — LOAD reg, imm
; Lataa vakioarvo rekisteriin desimaalina, heksana ja binäärinä.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 42          ; desimaali
        LOAD  R1, 0xFF        ; heksadesimaali (255)
        LOAD  R2, 0b1010      ; binääri (10)
        LOAD  R3, 0           ; nolla

        HALT

.expect_reg   R0, 42
.expect_reg   R1, 255
.expect_reg   R2, 10
.expect_reg   R3, 0
