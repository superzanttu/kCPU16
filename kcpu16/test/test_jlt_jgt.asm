; =============================================================================
; test_jlt_jgt.asm — JLT addr / JGT addr
; JLT: hyppy jos N≠V (etumerkillinen A < B)
; JGT: hyppy jos Z=0 ja N=V (etumerkillinen A > B)
; =============================================================================

        .origin 0x0200

        ; --- JLT: 3 < 7 → hyppy otetaan ---
        JARI  R0, 3
        JARI  R1, 7
        CMP   R0, R1          ; N=1, V=0 → N≠V
        JLT   jgt_test
        JARI  R2, 99          ; ei suoriteta

jgt_test:
        ; --- JGT: 9 > 4 → hyppy otetaan ---
        JARI  R0, 9
        JARI  R1, 4
        CMP   R0, R1          ; Z=0, N=0, V=0 → Z=0 ja N=V
        JGT   done
        JARI  R3, 99          ; ei suoriteta

done:
        HALT

.expect_reg   R2, 0            ; JLT otti hypyn oikein
.expect_reg   R3, 0            ; JGT otti hypyn oikein
; Liput viimeisimmän CMP:n (9−4=5) jäljiltä
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
