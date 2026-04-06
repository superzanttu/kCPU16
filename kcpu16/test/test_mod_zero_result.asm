; =============================================================================
; test_mod_zero_result.asm — MOD regD, regS kun tulos on 0
; Tarkistaa että Z-lippu asetetaan kun jakojäännös on 0.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 100
        LOAD  R1, 10
        MOD   R0, R1          ; R0 = 100 % 10 = 0  -> Z=1

        HALT

.expect_reg   R0, 0
.expect_flag  Z, 1
.expect_flag  N, 0
