; =============================================================================
; demo_benchmark2.asm — kCPU16 Nopeusmittaus (adaptiivinen pysäytys)
; =============================================================================
;
; KUVAUS:
;   Sama kuin demo_benchmark.asm, mutta kukin mittaus toistetaan niin kauan
;   kunnes tulos VAKAUTUU tai LASKEE ennen siirtymistä seuraavaan testiin.
;
;   Pysäytysehto (kumpi tahansa riittää):
;     a) Tulos ei juuri muutu: kasvu < 5 % edellisestä mittauksesta
;     b) Tulos laskee tai pysyy samana
;
;   Käytännön toteutus:
;     R15 = edellinen tulos / 2  (puolitettu → pysyy 16-bit signed-alueella)
;     R6  = nykyinen  tulos / 2  (lasketaan ennen write5:ttä; säilyy sen yli)
;     Kynnys = R15 / 20  (≈ 5 % edellisestä)
;
;   1. CPU suoritusnopeus  — käskyä/sekuntti (k/s)
;   2. RAM latausnopeus    — tavua/sekuntti  (B/s)
;   3. RAM tallennusnopeus — tavua/sekuntti  (B/s)
;   4. Levy lukusnopeus    — tavua/sekuntti (B/s) ja blokkia/sekuntti (blk/s)
;   5. Levy kirjoitusnopeus— tavua/sekuntti (B/s) ja blokkia/sekuntti (blk/s)
;
; Koskemattomia osia: kaikki vakiot, data, aliohjelmat (write_str, write5,
; wait_sec, bench_*, update_avg) — identtiset demo_benchmark.asm:n kanssa.
; =============================================================================

        .origin 0x0200

        JUMP   main

; =============================================================================
; KÄYTTÄJÄVAKIOT
; =============================================================================

.const RAM_BM_START, 0x4000
.const RAM_BM_END,   0x4100
.const DSK_BM_START, 0x1000
.const DSK_BM_END,   0x1100
.const BLOCK_WORDS,  256

.const VRAM_R0,  0xF800
.const VRAM_R1,  0xF850
.const VRAM_R3,  0xF8F0
.const VRAM_R5,  0xF990
.const VRAM_R6,  0xF9E0
.const VRAM_R8,  0xFA80
.const VRAM_R9,  0xFAD0
.const VRAM_R11, 0xFB70

.const COL_TITLE, 0x4300
.const COL_LABEL, 0x0600
.const COL_SEP,   0x0700
.const COL_STAT,  0x0300

; Liukuvan keskiarvon historiataulukot
.const BUF_CPU,    0x0800
.const BUF_RAM_R,  0x0804
.const BUF_RAM_W,  0x0808
.const BUF_DSK_RB, 0x080C
.const BUF_DSK_RK, 0x0810
.const BUF_DSK_WB, 0x0814
.const BUF_DSK_WK, 0x0818

; =============================================================================
; MERKKIJONODATA
; =============================================================================

STR_TITLE:
        .dstr "kCPU16 NOPEUSMITTAUS"

STR_SEP:
        .dstr "===================="

STR_CPU_LBL:
        .dstr "CPU kIPS:       "

STR_RAM_R_LBL:
        .dstr "RAM  luku  B/s: "

STR_RAM_W_LBL:
        .dstr "RAM  kirj. B/s: "

STR_DSK_R_LBL:
        .dstr "Levy luku  B/s: "

STR_DSK_W_LBL:
        .dstr "Levy kirj. B/s: "

STR_BLKS_LBL:
        .dstr "  blk/s: "

STR_S_CPU:
        .dstr "Mittaa: CPU nopeus...         "

STR_S_RAM_R:
        .dstr "Mittaa: RAM luku...           "

STR_S_RAM_W:
        .dstr "Mittaa: RAM kirjoitus...      "

STR_S_DSK_R:
        .dstr "Mittaa: Levy luku...          "

STR_S_DSK_W:
        .dstr "Mittaa: Levy kirjoitus...     "

; =============================================================================
; ALIOHJELMA: write_str
; =============================================================================
write_str:
        READ  R12, 0
ws_loop:
        READ  R11, [R9]
        CMP   R11, R12
        JZ    ws_done
        OR    R11, R10
        STORE [R8], R11
        READ  R11, 1
        ADD   R8,  R11
        ADD   R9,  R11
        JUMP  ws_loop
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: write5
; =============================================================================
write5:
        READ  R0, 10000
        CPY   R7, R1
        DIV   R7, R0
        CPY   R9, R7
        MUL   R9, R0
        SUB   R1, R9
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        READ  R0, 1000
        CPY   R7, R1
        DIV   R7, R0
        CPY   R9, R7
        MUL   R9, R0
        SUB   R1, R9
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        READ  R0, 100
        CPY   R7, R1
        DIV   R7, R0
        CPY   R9, R7
        MUL   R9, R0
        SUB   R1, R9
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        CPY   R7, R1
        DIV   R7, R4
        CPY   R9, R7
        MUL   R9, R4
        SUB   R1, R9
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        CPY   R9, R5
        ADD   R9, R1
        STORE [R8], R9
        ADD   R8, R3

        RET

; =============================================================================
; ALIOHJELMA: wait_sec
; =============================================================================
wait_sec:
        READ  R0,  [CLOCK_SECOND]
wait_sec_loop:
        READ  R12, [CLOCK_SECOND]
        CMP   R12, R0
        JZ    wait_sec_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_cpu
; =============================================================================
bench_cpu:
        CALL  wait_sec
        READ  R13, 0
cpu_bm_loop:
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        ADD   R13, R3
        READ  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    cpu_bm_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_ram_read
; =============================================================================
bench_ram_read:
        CALL  wait_sec
        READ  R13, 0
        READ  R0,  RAM_BM_START
        READ  R2,  RAM_BM_END
ram_r_loop:
        READ  R1,  [R0]
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   ram_r_chk
        READ  R0,  RAM_BM_START
ram_r_chk:
        READ  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    ram_r_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_ram_write
; =============================================================================
bench_ram_write:
        CALL  wait_sec
        READ  R13, 0
        READ  R0,  RAM_BM_START
        READ  R2,  RAM_BM_END
        READ  R1,  0xABCD
ram_w_loop:
        STORE [R0], R1
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   ram_w_chk
        READ  R0,  RAM_BM_START
ram_w_chk:
        READ  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    ram_w_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_dsk_read
; =============================================================================
bench_dsk_read:
        CALL  wait_sec
        READ  R13, 0
        READ  R0,  DSK_BM_START
        READ  R2,  DSK_BM_END
dsk_r_loop:
        DREAD R1,  R0
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   dsk_r_chk
        READ  R0,  DSK_BM_START
dsk_r_chk:
        READ  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    dsk_r_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_dsk_write
; =============================================================================
bench_dsk_write:
        CALL  wait_sec
        READ  R13, 0
        READ  R0,  DSK_BM_START
        READ  R2,  DSK_BM_END
        READ  R1,  0x1234
dsk_w_loop:
        DWRITE R1, R0
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   dsk_w_chk
        READ  R0,  DSK_BM_START
dsk_w_chk:
        READ  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    dsk_w_loop
        RET

; =============================================================================
; ALIOHJELMA: update_avg
; =============================================================================
update_avg:
        CPY   R6, R0
        ADD   R6, R3
        CPY   R7, R6
        ADD   R7, R3
        CPY   R8, R7
        ADD   R8, R3

        READ  R9,  [R7]
        STORE [R8], R9
        READ  R9,  [R6]
        STORE [R7], R9
        READ  R9,  [R0]
        STORE [R6], R9

        STORE [R0], R1

        READ  R10, 4
        CPY   R9,  R1
        DIV   R9,  R10

        READ  R6,  [R6]
        DIV   R6,  R10
        ADD   R9,  R6

        READ  R7,  [R7]
        DIV   R7,  R10
        ADD   R9,  R7

        READ  R8,  [R8]
        DIV   R8,  R10
        ADD   R9,  R8

        CPY   R1,  R9
        RET

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        READ  R3,  1
        READ  R4,  10
        READ  R5,  0x4230

        READ  R8,  VRAM_R0
        READ  R9,  STR_TITLE
        READ  R10, COL_TITLE
        CALL  write_str

        READ  R8,  VRAM_R1
        READ  R9,  STR_SEP
        READ  R10, COL_SEP
        CALL  write_str

; =============================================================================
; PÄÄSILMUKKA — Kierrättää kaikkia viittä mittausta ikuisesti.
; Kukin mittaus toistetaan kunnes tulos vakautuu (< 5 % kasvu) tai laskee.
;
; Konvergenssistrategia (per testi):
;   R15 = edellinen tulos / 2   (nollataan testin alussa)
;   R6  = nykyinen  tulos / 2   (lasketaan update_avg:n jälkeen, säilyy write5:n yli)
;   Kynnys = R15 / 20           (≈ 5 %)
;   Siirrytään kun: R6 ≤ R15  TAI  (R6 - R15) ≤ R15/20
;   Puolitus pitää arvot ≤ 32767 jolloin signed-vertailu on oikein kaikille arvoille.
; =============================================================================
main_loop:

; ============================================================
; MITTAUS 1: CPU-nopeus
; ============================================================
        READ  R15, 0            ; edellinen tulos = 0 (ensimmäinen kierros)

cpu_loop:
        READ  R8,  VRAM_R11
        READ  R9,  STR_S_CPU
        READ  R10, COL_STAT
        CALL  write_str

        CALL  bench_cpu         ; R13 = kierroksia/s

        CPY   R1,  R13
        READ  R7,  100
        DIV   R1,  R7           ; R1 = kIPS

        READ  R0,  BUF_CPU
        CALL  update_avg        ; R1 = avg kIPS

        ; Vertailuarvo R6 = R1/2 (≤ 327 → signed-turvallinen)
        CPY   R6,  R1
        READ  R0,  2
        DIV   R6,  R0

        READ  R8,  VRAM_R3
        READ  R9,  STR_CPU_LBL
        READ  R10, COL_LABEL
        CALL  write_str
        CALL  write5            ; kuluttaa R1; R6 säilyy (write5 ei koske R6)

        ; --- Konvergenssitarkistus ---
        CMP   R6,  R15
        JLE   cpu_done          ; R6 ≤ R15 → laski tai sama → seuraava testi

        ; R6 > R15: tarkista onko kasvu ≤ 5 %
        CPY   R7,  R15
        READ  R0,  20
        DIV   R7,  R0           ; R7 = R15/20 (kynnys, ~5 % viime tuloksesta)
        CPY   R0,  R6
        SUB   R0,  R15          ; R0 = muutos = R6 - R15
        CMP   R0,  R7
        JLE   cpu_done          ; muutos ≤ kynnys → vakautui → seuraava testi

        CPY   R15, R6           ; päivitä edellinen
        JUMP  cpu_loop

cpu_done:

; ============================================================
; MITTAUS 2: RAM latausnopeus
; ============================================================
        READ  R15, 0

ram_r_loop2:
        READ  R8,  VRAM_R11
        READ  R9,  STR_S_RAM_R
        READ  R10, COL_STAT
        CALL  write_str

        CALL  bench_ram_read    ; R13 = sanoja/s

        READ  R7,  0
        CMP   R13, R7
        JLT   rr2_sat           ; R13 ≥ 32768 → ylivuoto × 2 → saturoi
        CPY   R1,  R13
        ADD   R1,  R13          ; R1 = 2 × W/s
        JUMP  rr2_bps
rr2_sat:
        READ  R1,  65535
rr2_bps:
        READ  R0,  BUF_RAM_R
        CALL  update_avg        ; R1 = avg B/s

        CPY   R6,  R1
        READ  R0,  2
        DIV   R6,  R0           ; R6 = avg B/s / 2 (≤ 32767)

        READ  R8,  VRAM_R5
        READ  R9,  STR_RAM_R_LBL
        READ  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        CMP   R6,  R15
        JLE   ram_r_done2
        CPY   R7,  R15
        READ  R0,  20
        DIV   R7,  R0
        CPY   R0,  R6
        SUB   R0,  R15
        CMP   R0,  R7
        JLE   ram_r_done2
        CPY   R15, R6
        JUMP  ram_r_loop2

ram_r_done2:

; ============================================================
; MITTAUS 3: RAM tallennusnopeus
; ============================================================
        READ  R15, 0

ram_w_loop2:
        READ  R8,  VRAM_R11
        READ  R9,  STR_S_RAM_W
        READ  R10, COL_STAT
        CALL  write_str

        CALL  bench_ram_write   ; R13 = sanoja/s

        READ  R7,  0
        CMP   R13, R7
        JLT   rw2_sat
        CPY   R1,  R13
        ADD   R1,  R13
        JUMP  rw2_bps
rw2_sat:
        READ  R1,  65535
rw2_bps:
        READ  R0,  BUF_RAM_W
        CALL  update_avg        ; R1 = avg B/s

        CPY   R6,  R1
        READ  R0,  2
        DIV   R6,  R0

        READ  R8,  VRAM_R6
        READ  R9,  STR_RAM_W_LBL
        READ  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        CMP   R6,  R15
        JLE   ram_w_done2
        CPY   R7,  R15
        READ  R0,  20
        DIV   R7,  R0
        CPY   R0,  R6
        SUB   R0,  R15
        CMP   R0,  R7
        JLE   ram_w_done2
        CPY   R15, R6
        JUMP  ram_w_loop2

ram_w_done2:

; ============================================================
; MITTAUS 4: Tallennuslaitteen lukusnopeus (B/s ja blk/s)
; ============================================================
        READ  R15, 0

dsk_r_loop2:
        READ  R8,  VRAM_R11
        READ  R9,  STR_S_DSK_R
        READ  R10, COL_STAT
        CALL  write_str

        CALL  bench_dsk_read    ; R13 = sanoja/s

        READ  R7,  0
        CMP   R13, R7
        JLT   dr2_sat
        CPY   R1,  R13
        ADD   R1,  R13          ; R1 = B/s
        JUMP  dr2_bps
dr2_sat:
        READ  R1,  65535
dr2_bps:
        READ  R7,  BLOCK_WORDS  ; R7 = 256
        CPY   R2,  R13
        DIV   R2,  R7           ; R2 = blk/s

        READ  R0,  BUF_DSK_RB
        CALL  update_avg        ; R1 = avg B/s (R2 säilyy)
        PUSH  R1                ; tallenna avg B/s
        READ  R0,  BUF_DSK_RK
        CPY   R1,  R2
        CALL  update_avg        ; R1 = avg blk/s
        CPY   R2,  R1           ; R2 = avg blk/s
        POP   R1                ; R1 = avg B/s

        ; Vertailuarvo R6 = avg B/s / 2
        CPY   R6,  R1
        READ  R0,  2
        DIV   R6,  R0

        READ  R8,  VRAM_R8
        READ  R9,  STR_DSK_R_LBL
        READ  R10, COL_LABEL
        CALL  write_str
        CALL  write5            ; kirjoita avg B/s; R6 ja R2 säilyvät

        READ  R9,  STR_BLKS_LBL
        CALL  write_str
        CPY   R1,  R2           ; R1 = avg blk/s
        CALL  write5

        CMP   R6,  R15
        JLE   dsk_r_done2
        CPY   R7,  R15
        READ  R0,  20
        DIV   R7,  R0
        CPY   R0,  R6
        SUB   R0,  R15
        CMP   R0,  R7
        JLE   dsk_r_done2
        CPY   R15, R6
        JUMP  dsk_r_loop2

dsk_r_done2:

; ============================================================
; MITTAUS 5: Tallennuslaitteen kirjoitusnopeus (B/s ja blk/s)
; ============================================================
        READ  R15, 0

dsk_w_loop2:
        READ  R8,  VRAM_R11
        READ  R9,  STR_S_DSK_W
        READ  R10, COL_STAT
        CALL  write_str

        CALL  bench_dsk_write   ; R13 = sanoja/s

        READ  R7,  0
        CMP   R13, R7
        JLT   dw2_sat
        CPY   R1,  R13
        ADD   R1,  R13
        JUMP  dw2_bps
dw2_sat:
        READ  R1,  65535
dw2_bps:
        READ  R7,  BLOCK_WORDS
        CPY   R2,  R13
        DIV   R2,  R7           ; R2 = blk/s

        READ  R0,  BUF_DSK_WB
        CALL  update_avg        ; R1 = avg B/s (R2 säilyy)
        PUSH  R1
        READ  R0,  BUF_DSK_WK
        CPY   R1,  R2
        CALL  update_avg
        CPY   R2,  R1           ; R2 = avg blk/s
        POP   R1                ; R1 = avg B/s

        CPY   R6,  R1
        READ  R0,  2
        DIV   R6,  R0

        READ  R8,  VRAM_R9
        READ  R9,  STR_DSK_W_LBL
        READ  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        READ  R9,  STR_BLKS_LBL
        CALL  write_str
        CPY   R1,  R2
        CALL  write5

        CMP   R6,  R15
        JLE   dsk_w_done2
        CPY   R7,  R15
        READ  R0,  20
        DIV   R7,  R0
        CPY   R0,  R6
        SUB   R0,  R15
        CMP   R0,  R7
        JLE   dsk_w_done2
        CPY   R15, R6
        JUMP  dsk_w_loop2

dsk_w_done2:

        JUMP  main_loop
