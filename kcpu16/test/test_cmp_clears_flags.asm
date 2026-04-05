; =============================================================================
; test_cmp_clears_flags.asm — CMP nollaa liput (1→0)
; Varmistaa, että CMP kirjoittaa liput uudelleen: kun lippu on 1 ja
; tulos ei aseta sitä, lippu menee 0:aan.
; Testataan Z, N, C, V suunnassa 1→0.
; =============================================================================

        .origin 0x0200

        ; --- Vaihe 1: aseta kaikki liput 1 ---
        ; SUB 0x7FFF - 0xFFFF = 0x8000: C=1, N=1, V=1, Z=0
        LOAD  R0, 0x7FFF
        LOAD  R1, 0xFFFF
        SUB   R0, R1          ; C=1, N=1, V=1, Z=0

        ; --- Vaihe 2: aseta myös Z=1 ---
        LOAD  R0, 42
        LOAD  R1, 42
        CMP   R0, R1          ; 42-42=0: Z=1 (0→1 koska Z oli 0 vaiheesta 1)
                              ; N=0 (1→0), C=0 (1→0), V=0 (1→0)

        ; --- Vaihe 3: aseta kaikki liput 1 uudelleen (SUB) ---
        LOAD  R0, 0x7FFF
        LOAD  R1, 0xFFFF
        SUB   R0, R1          ; C=1, N=1, V=1, Z=0

        ; --- Vaihe 4: CMP joka tuottaa vain positiivisen ei-nolla tuloksen ---
        ; 100 - 50 = 50: Z=0 (1→0), N=0 (1→0), C=0 (1→0), V=0 (1→0)
        LOAD  R0, 100
        LOAD  R1, 50
        CMP   R0, R1

        HALT

.expect_reg   R0, 100         ; CMP ei muuta rekistereitä
.expect_reg   R1, 50
.expect_flag  Z, 0           ; Z: 1→0
.expect_flag  N, 0           ; N: 1→0
.expect_flag  C, 0           ; C: 1→0
.expect_flag  V, 0           ; V: 1→0
