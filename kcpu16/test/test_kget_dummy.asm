; =============================================================
; TESTI: KGET-käsky (näppäimistöpuskurin luku)
; =============================================================
; EI TESTATTAVISSA AUTOMAATTISESTI.
;
; Mitä pitäisi testata:
; - KGET lukee keyboard-puskurista seuraavan näppäimen
; - Jos puskuri on tyhjä, KGET palauttaa 0
; - KGET ei muuta lippuja (Z, N, C, V)
; - KGET toimii user modessa (ei privileged)
; - Useamman näppäimen jonottaminen ja lukeminen FIFO-järjestyksessä
;
; Miksi ei testattavissa:
; Testrunner ei tue näppäimistösyötteen simulointia.
; Tarvittaisiin .inject_key-direktiivi tai vastaava mekanismi,
; jolla voidaan asettaa näppäimiä puskuriin ennen suoritusta.
;
; Manuaalinen testi:
; 1. Käynnistä TUI-debuggeri
; 2. Lataa ohjelma joka kutsuu KGET silmukassa
; 3. Paina näppäimiä ja tarkista R-rekisterin arvo
; =============================================================

.origin 0x0200

; Dummy: KGET ilman näppäimistöä palauttaa 0
KGET  R0              ; R0 = 0 (ei näppäimistöä kytketty)
HALT

.expect_reg   R0, 0          ; ei näppäimistöä -> 0
