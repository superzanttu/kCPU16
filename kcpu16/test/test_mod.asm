; =============================================================================
; test_mod.asm — MOD regD, regS
; Jakojäännös: regD = regD % regS.
; Testaa perustuloksen ja lippujen arvot.
; =============================================================================

        .origin 0x0200

        LOAD  R0, 17
        LOAD  R1, 5
        MOD   R0, R1          ; R0 = 17 % 5 = 2

        LOAD  R2, 100
        LOAD  R3, 7
        MOD   R2, R3          ; R2 = 100 % 7 = 2

        HALT

.expect_reg   R0, 2
.expect_reg   R2, 2
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0            ; MOD ei aseta C-lippua
.expect_flag  V, 0            ; MOD ei aseta V-lippua
