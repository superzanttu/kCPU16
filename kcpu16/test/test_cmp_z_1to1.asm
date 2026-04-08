; =============================================================================
; test_cmp_z_1to1.asm — CMP: Z-lippu 1→1
; Kun Z=1 ja seuraava CMP tuottaa myös nollatuloksen → Z:1→1.
; CMP ei muuta operandeja.
; =============================================================================

        .origin 0x0200

        ; Vaihe 1: CMP tuottaa Z=1 (0→1)
        JARI  R0, 55
        JARI  R1, 55
        CMP   R0, R1          ; 55-55=0: Z=1, N=0, C=0, V=0

        ; Vaihe 2: CMP tuottaa Z=1 uudelleen → Z:1→1
        JARI  R0, 99
        JARI  R1, 99
        CMP   R0, R1          ; 99-99=0: Z=1 (1→1)

        HALT

.expect_reg   R0, 99          ; CMP ei muuta R0
.expect_reg   R1, 99          ; CMP ei muuta R1
.expect_flag  Z, 1           ; Z: 1→1
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
