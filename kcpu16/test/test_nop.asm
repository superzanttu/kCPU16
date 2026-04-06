; =============================================================
; TESTI: NOP
; NOP ei tee mitään: rekisterit ja liput pysyvät muuttumattomina
; =============================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0 ADD:lla (0x8000 + 0x8000)
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; Aseta rekisteriarvot
LOAD  R0, 42
LOAD  R1, 99
LOAD  R2, 0x1234
LOAD  R3, 0xABCD

NOP                   ; ei tee mitään
NOP                   ; kaksi peräkkäistä NOPia

HALT

.expect_reg   R0, 42
.expect_reg   R1, 99
.expect_reg   R2, 0x1234
.expect_reg   R3, 0xABCD
.expect_flag  C, 1           ; NOP ei nollannut C:tä
.expect_flag  V, 1           ; NOP ei nollannut V:tä
.expect_flag  Z, 1           ; NOP ei nollannut Z:tä
.expect_flag  N, 0           ; N pysyi nollana
