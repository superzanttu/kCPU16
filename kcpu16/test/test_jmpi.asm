; =============================================================================
; test_jmpi.asm — JMPI reg, addr... (indeksoitu epäsuora hyppy)
; JMPI hyppää osoitteeseen targets[reg], missä targets on käskyn
; välitön osoitetaulukko. Testataan indeksit 0, 1 ja 2.
; =============================================================================

        .origin 0x0200

; --- Tapaus 0: indeksi 0 → branch0 ---
        LOAD  R0, 0
        JMPI  R0, branch0, branch1, branch2

branch0:
        LOAD  R0, 10          ; valittiin oikein
        JUMP  next1
branch1:
        LOAD  R0, 99          ; ei pitäisi suorittua
        JUMP  next1
branch2:
        LOAD  R0, 99          ; ei pitäisi suorittua

next1:
; --- Tapaus 1: indeksi 1 → branch_b ---
        LOAD  R1, 1
        JMPI  R1, branch_a, branch_b, branch_c

branch_a:
        LOAD  R1, 99
        JUMP  next2
branch_b:
        LOAD  R1, 20          ; valittiin oikein
        JUMP  next2
branch_c:
        LOAD  R1, 99

next2:
; --- Tapaus 2: indeksi 2 → branch_z ---
        LOAD  R2, 2
        JMPI  R2, branch_x, branch_y, branch_z

branch_x:
        LOAD  R2, 99
        JUMP  done
branch_y:
        LOAD  R2, 99
        JUMP  done
branch_z:
        LOAD  R2, 30          ; valittiin oikein

done:
        HALT

.expect_reg  R0, 10
.expect_reg  R1, 20
.expect_reg  R2, 30
