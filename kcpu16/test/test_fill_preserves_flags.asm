; =============================================================================
; test_fill_preserves_flags.asm — FILL ei muuta tilalippuja
; Varmistaa että FILL ei koskaan muuta Z, N, C tai V -lippuja.
; =============================================================================

        .origin 0x0200

        ; Aseta liput tunnettuun tilaan: ADD joka asettaa C=1
        LOAD  R3, 0xFFFF
        LOAD  R4, 1
        ADD   R3, R4            ; R3 = 0, Z=1, N=0, C=1, V=0

        ; Suorita FILL — sen ei pidä muuttaa lippuja
        LOAD  R0, 0x0900
        LOAD  R1, 0x0905
        LOAD  R2, 0x1111
        FILL  R0, R1, R2

        HALT

; Liput säilyvät ADD:n asettamina
.expect_flag  Z, 1
.expect_flag  N, 0
.expect_flag  C, 1
.expect_flag  V, 0

; Muisti on täytetty oikein
.expect_mem  0x0900, 0x1111
.expect_mem  0x0905, 0x1111
