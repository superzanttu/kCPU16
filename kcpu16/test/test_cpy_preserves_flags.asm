; =============================================================================
; test_cpy_preserves_flags.asm — CPY ei muuta lippuja (1→1)
; JARI-testi (test_load_preserves_flags.asm) näyttää että JARI säilyttää liput.
; Tässä varmistetaan sama CPY:lle: kun liput ovat 1, CPY ei nollaa niitä.
; =============================================================================

.origin 0x0200

; Aseta C=1, V=1, Z=1, N=0
; 0x8000 + 0x8000 = 0x10000 → C=1, V=1, tulos katkottu 0 → Z=1, N=0
JARI  R0, 0x8000
JARI  R1, 0x8000
ADD   R0, R1          ; C=1, V=1, Z=1, N=0

; CPY ei saa muuttaa lippuja
CPY   R1, R0          ; R1 = 0 (ADD:n tulos)
CPY   R2, R1          ; R2 = 0
JARI  R0, 42
CPY   R3, R0          ; R3 = 42

HALT

.expect_reg   R0, 42
.expect_reg   R1, 0
.expect_reg   R2, 0
.expect_reg   R3, 42
.expect_flag  C, 1           ; CPY ei nollannut C:tä (1→1)
.expect_flag  V, 1           ; CPY ei nollannut V:tä (1→1)
.expect_flag  Z, 1           ; CPY ei nollannut Z:tä (1→1)
.expect_flag  N, 0           ; N pysyi nollana (0→0)
