; =============================================================================
; test_swsp.asm — SWSP regD, regS
; Atominen pinon osoittimen vaihto: regD = vanha SP, SP = regS.
; Käytetään pinon vaihtoon kontekstikytkennässä.
; =============================================================================

        .origin 0x0200

        ; Vaihda SP uuteen arvoon ja tallenna vanha arvo R1:een
        LOAD  R0, 0x0400
        SWSP  R1, R0          ; R1 = vanha SP (0xFFFF), SP = 0x0400

        ; Palauta vanha SP ja vahvista että R2 saa nykyisen SP:n arvon
        SWSP  R2, R1          ; R2 = 0x0400 (nykyinen SP), SP = 0xFFFF

        HALT

.expect_reg   R0, 0x0400      ; R0 muuttumaton
.expect_reg   R1, 0xFFFF      ; R1 sai alkuperäisen SP:n
.expect_reg   R2, 0x0400      ; R2 sai vaihdetun SP:n arvon
; SWSP ei aseta lippuja
.expect_flag  Z, 0
.expect_flag  N, 0
.expect_flag  C, 0
.expect_flag  V, 0
