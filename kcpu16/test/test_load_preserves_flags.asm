; =============================================================
; TESTI: LOAD ei muuta lippuja
; =============================================================
; Asetetaan C=1 ja V=1 ADD:lla, sitten LOAD -> liput säilyvät
; =============================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0 ADD:lla (0x8000 + 0x8000)
LOAD  R0, 0x8000
LOAD  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; LOAD ei saa muuttaa lippuja
LOAD  R2, 42
LOAD  R3, 0x8000

HALT

.expect_reg   R2, 42
.expect_reg   R3, 0x8000
.expect_flag  C, 1           ; LOAD ei nollannut C:tä
.expect_flag  V, 1           ; LOAD ei nollannut V:tä
.expect_flag  Z, 1           ; LOAD ei nollannut Z:tä
.expect_flag  N, 0           ; N pysyi nollana
