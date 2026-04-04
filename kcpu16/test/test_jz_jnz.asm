; =============================================================================
; test_jz_jnz.asm — JZ addr / JNZ addr
; JZ:  hyppy jos Z=1 (CMP erotus oli nolla → yhtäsuuret)
; JNZ: hyppy jos Z=0 (CMP erotus ei nolla → eri suuret)
; =============================================================================

        .origin 0x0200

        ; --- JZ: yhtäsuuret → Z=1 → hyppy otetaan ---
        LOAD  R0, 5
        LOAD  R1, 5
        CMP   R0, R1          ; Z=1
        JZ    jnz_test
        LOAD  R2, 99          ; ei suoriteta

jnz_test:
        ; --- JNZ: eri suuret → Z=0 → hyppy otetaan ---
        LOAD  R0, 3
        LOAD  R1, 7
        CMP   R0, R1          ; Z=0
        JNZ   done
        LOAD  R3, 99          ; ei suoriteta

done:
        HALT

.expect_reg   R2, 0            ; JZ otti hypyn oikein
.expect_reg   R3, 0            ; JNZ otti hypyn oikein
; Liput viimeisimmän CMP:n (3−7=0xFFFC) jäljiltä
.expect_flag  Z, 0
.expect_flag  N, 1
.expect_flag  C, 1
.expect_flag  V, 0
