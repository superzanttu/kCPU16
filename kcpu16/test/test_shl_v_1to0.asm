; =============================================================================
; test_shl_v_1to0.asm — SHL: V-lippu 1→0 (SHL nollaa V aina)
; Asetetaan V=1 ADD:lla, sitten SHL → V:1→0.
; SHL kutsuu set_carry_overflow(carry, False) → V nollataan aina.
; =============================================================================

        .origin 0x0200

        ; Aseta V=1 ADD:lla
        READ  R0, 0x7FFF
        READ  R1, 1
        ADD   R0, R1          ; 0x8000: V=1, N=1, C=0, Z=0

        ; SHL nollaa V
        READ  R0, 0x0001
        READ  R1, 1
        SHL   R0, R1          ; 0x0002: V=0 (V:1→0), C=0, Z=0, N=0

        HALT

.expect_reg   R0, 0x0002
.expect_flag  V, 0           ; V: 1→0 (SHL nollaa aina)
.expect_flag  C, 0
.expect_flag  Z, 0
.expect_flag  N, 0
