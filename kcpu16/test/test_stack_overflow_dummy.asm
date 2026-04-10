; =============================================================
; TESTI: Stack overflow (INT 2) user modessa
; =============================================================
; EI TESTATTAVISSA LUOTETTAVASTI AUTOMAATTISESTI.
;
; Mitä pitäisi testata:
; - User modessa PUSH joka vie SP:n alle MPR:n -> INT 2
; - INT 2 handler suoritetaan kernel-tilassa
; - Handler voi palauttaa suorituksen tai lopettaa prosessin
; - SP:n arvo INT 2:n hetkellä
; - Usean PUSH:n jono joka aiheuttaa overflow:n
;
; Miksi vaikea testata:
; Stack overflow vaatii user modessa tarpeeksi PUSH-käskyjä
; jotta SP laskee alle MPR:n. Tämä vaatii:
; 1. MPR:n asettamisen suureksi (lähelle SP:n alkuarvoa)
; 2. User modeen siirtymisen IRET:llä
; 3. User SP:n asettamisen sopivaksi
; 4. PUSH-käskyjen suorituksen kunnes SP < MPR
;
; Ongelmia:
; - INT 2 handler tarvitsee oman pinon (kernel stack)
; - Handler:in pitäisi pystyä palautumaan tai lopettamaan
; - SP on jo alle MPR:n kun handler alkaa, joten
;   IRET:llä paluu user-modeen aiheuttaa uuden overflow:n
;   ellei SP:tä korjata
;
; Tämä testi todentaa vain perusmekanismin:
; kernel-tilassa PUSH ei laukaise INT 2:ta.
; =============================================================

.origin 0x0200

; Dummy: kernel-tilassa PUSH ei aiheuta stack overflow:ta
READ  R0, 0x0300
SMPR  R0              ; MPR = 0x0300

; Kernel-tilassa PUSH toimii normaalisti vaikka SP menisi alle MPR:n
READ  R0, 111
READ  R1, 222
PUSH  R0
PUSH  R1
POP   R2              ; R2 = 222 (LIFO)
POP   R3              ; R3 = 111

HALT

.expect_reg   R2, 222        ; PUSH/POP toimii kernel-tilassa
.expect_reg   R3, 111        ; LIFO-järjestys oikein
