; =============================================================================
; test_cmp.asm — CMP regA, regB
; Vertailu asettaa liput kuten SUB mutta ei tallenna tulosta.
; Testaa: yhtäsuuruus (Z=1), pienempi (N/C), ei muuta operandeja.
; =============================================================================

        .origin 0x0200

        ; Testi 1: yhtäsuuret — JZ:n pitää ottaa hyppy
        READ  R0, 5
        READ  R1, 5
        CMP   R0, R1          ; 5 − 5 = 0 → Z=1
        JZ    test2
        READ  R2, 99          ; ei suoriteta

test2:
        ; Testi 2: pienempi — JLT:n pitää ottaa hyppy
        READ  R0, 3
        READ  R1, 7
        CMP   R0, R1          ; 3 − 7 → N=1
        JLT   test3
        READ  R3, 99          ; ei suoriteta

test3:
        ; CMP ei saa muuttaa operandirekistereitä
        READ  R0, 42
        READ  R1, 42
        CMP   R0, R1

        HALT

.expect_reg   R2, 0           ; haaraherätteen sivupolkua ei ajettu
.expect_reg   R3, 0
.expect_reg   R0, 42          ; CMP ei muuttanut R0:aa
.expect_reg   R1, 42          ; CMP ei muuttanut R1:tä
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
