; =============================================================================
; test_copy_rand_mmio.asm — COPY MMIO-lähteestä käyttää MMIO-aware fallbackia
;
; Siemennetään RAND_MMIO arvolla 0xDEAD ja kopioidaan yksi sana COPY:lla
; RAND_MMIO-osoitteesta RAM:iin. Oikea arvo kohteessa on 0xDB56.
;
; Jos COPY käyttäisi väärin suoraa RAM-fastpathia MMIO-alueella,
; kohteeseen kopioituisi väärä arvo.
; =============================================================================

        .origin 0x0200

        READ  R7, 0xDEAD
        STORE [RAND_MMIO], R7    ; aseta siemen

        READ  R0, RAND_MMIO      ; src start
        READ  R1, RAND_MMIO      ; src end (1 sana)
        READ  R2, 0x0300         ; dst

        COPY  R0, R1, R2
        READ  R3, [0x0300]

        HALT

.expect_reg R3, 0xDB56
