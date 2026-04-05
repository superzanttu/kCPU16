; =============================================================================
; test_div_n_flags.asm — DIV: N-lippu (0→1 ja 1→1)
; DIV ei aseta C- eikä V-lippua; se asettaa vain Z ja N.
; 0xFFFF / 1 = 0xFFFF → N=1 (bitti 15 asetettu)
; Toistetaan → N:1→1
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: DIV tuottaa N=1 (0→1)
        LOAD  R0, 0xFFFF
        LOAD  R1, 1
        DIV   R0, R1          ; 65535 / 1 = 65535 = 0xFFFF: N=1, Z=0

        ; Vaihe 2: DIV tuottaa N=1 uudelleen → N:1→1
        LOAD  R0, 0xFFFF
        LOAD  R1, 1
        DIV   R0, R1          ; N=1 (1→1)

        HALT

.expect_reg   R0, 0xFFFF
.expect_flag  N, 1           ; N: 1→1 (bitti 15 asetettu)
.expect_flag  Z, 0
.expect_flag  C, 0           ; DIV ei kosketa C:tä
.expect_flag  V, 0           ; DIV ei kosketa V:tä
