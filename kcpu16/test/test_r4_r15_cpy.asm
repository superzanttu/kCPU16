; =============================================================================
; test_r4_r15_cpy.asm — CPY R4-R15 <-> R0-R3
; Testaa kopiointi vanhojen ja uusien rekisterien välillä.
; =============================================================================

        .origin 0x0200

        READ  R0, 111
        READ  R1, 222
        CPY   R8,  R0          ; R8  = R0 = 111
        CPY   R9,  R1          ; R9  = R1 = 222
        READ  R12, 0xFF
        CPY   R2,  R12         ; R2  = R12 = 255
        CPY   R15, R9          ; R15 = R9  = 222

        HALT

.expect_reg   R8,  111
.expect_reg   R9,  222
.expect_reg   R2,  255
.expect_reg   R15, 222
; CPY ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
