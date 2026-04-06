; =============================================================================
; test_swsp_preserves_flags.asm — SWSP säilyttää liput (1→1)
; Kun liput ovat 1 ennen SWSP:tä, ne pysyvät 1:nä sen jälkeen.
; =============================================================================

        .origin 0x0200

        ; Aseta C=1, V=1, Z=1, N=0 ADD:lla
        LOAD  R0, 0x8000
        LOAD  R1, 0x8000
        ADD   R0, R1          ; C=1, V=1, Z=1, N=0

        ; SWSP ei saa muuttaa lippuja
        LOAD  R0, 0x0400
        SWSP  R1, R0          ; R1 = vanha SP, SP = 0x0400; liput ennallaan
        SWSP  R2, R1          ; R2 = 0x0400, SP = vanha SP; liput ennallaan

        HALT

.expect_reg   R1, 0xFFFF      ; R1 sai alkuperäisen SP:n
.expect_reg   R2, 0x0400      ; R2 sai vaihdetun SP:n
.expect_flag  C, 1           ; SWSP ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; SWSP ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; SWSP ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
