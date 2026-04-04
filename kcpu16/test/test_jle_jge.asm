; =============================================================================
; test_jle_jge.asm — JLE addr / JGE addr
; JLE: hyppy jos Z=1 tai N≠V (etumerkillinen A ≤ B)
; JGE: hyppy jos N=V          (etumerkillinen A ≥ B)
; =============================================================================

        .origin 0x0200

        ; --- JLE: 5 = 5 → Z=1 → hyppy otetaan ---
        LOAD  R0, 5
        LOAD  R1, 5
        CMP   R0, R1          ; Z=1
        JLE   jge_test
        LOAD  R2, 99          ; ei suoriteta

jge_test:
        ; --- JGE: 10 > 3 → N=0, V=0 → N=V → hyppy otetaan ---
        LOAD  R0, 10
        LOAD  R1, 3
        CMP   R0, R1          ; N=0, V=0
        JGE   done
        LOAD  R3, 99          ; ei suoriteta

done:
        HALT

.expect_reg   R2, 0            ; JLE otti hypyn oikein
.expect_reg   R3, 0            ; JGE otti hypyn oikein
