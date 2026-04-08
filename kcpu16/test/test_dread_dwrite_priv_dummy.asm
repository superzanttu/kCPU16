; =============================================================
; TESTI: DREAD/DWRITE privilege violation user modessa
; =============================================================
; EI TESTATTAVISSA TÄYSIN AUTOMAATTISESTI.
;
; Mitä pitäisi testata:
; - User-mode DREAD laukaisee INT 4 (privilege violation)
; - User-mode DWRITE laukaisee INT 4 (privilege violation)
; - DREAD on 3 sanan käsky (opcode + regD + regS)
; - DWRITE on 3 sanan käsky (opcode + regS + regD)
; - Handler voi ohittaa käskyn ja jatkaa suoritusta
;
; Miksi ei testattavissa täysin:
; DREAD/DWRITE ilman storage-laitetta laukaisee INT 1
; (InvalidOpcodeError) kernel-tilassakin. Testrunner ei
; kytke storage-laitetta oletuksena.
;
; Privilege violation -mekanismi on kuitenkin identtinen
; kaikkien privileged-käskyjen osalta (sama _check_privilege),
; ja se on testattu test_privilege_all.asm:ssä käskyillä
; HALT, STI, CLI, IRET, SMPR, STMR.
;
; Täydellinen testi vaatisi:
; 1. Storage-laitteen kytkemisen testrunnerissa
; 2. User modeen siirtymisen
; 3. DREAD/DWRITE:n suoritusyrityksen
; 4. INT 4 handler:in tarkistuksen
; =============================================================

.origin 0x0200

; Dummy: tarkista että DREAD/DWRITE toimii kernel-tilassa
; kun storage-laite on kytketty (testrunner kytkee sen)
JARI  R0, 0xCAFE
JARI  R1, 10
DWRITE R0, R1         ; storage[10] = 0xCAFE
JARI  R2, 10
DREAD R3, R2          ; R3 = storage[10] = 0xCAFE

HALT

.expect_reg   R3, 0xCAFE     ; kernel-mode DREAD/DWRITE toimii
.expect_storage 10, 0xCAFE   ; data tallentui storage-laitteelle
