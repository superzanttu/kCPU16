; =============================================================================
; speed_test.asm — kCPU16 Nopeusmittaus
; =============================================================================
;
; KUVAUS:
;   Mittaa ja näyttää viisi suorituskykyä kuvaavaa nopeutta reaaliajassa.
;   Ohjelma mittaa yhden asian kerrallaan, päivittää tuloksen näytölle
;   ja kierrättää kaikkia mittauksia ikuisessa silmukassa.
;
;   1. CPU suoritusnopeus  — käskyä/sekuntti (k/s)
;   2. RAM latausnopeus    — tavua/sekuntti  (B/s)
;   3. RAM tallennusnopeus — tavua/sekuntti  (B/s)
;   4. Levy lukusnopeus    — tavua/sekuntti (B/s) ja blokkia/sekuntti (blk/s)
;   5. Levy kirjoitusnopeus— tavua/sekuntti (B/s) ja blokkia/sekuntti (blk/s)
;
; NÄYTTÖASETTELU (80 × 24):
;   Rivi  0  "kCPU16 NOPEUSMITTAUS"              (keltainen lihavoitu)
;   Rivi  1  "===================="               (valkoinen)
;   Rivi  3  "CPU  k/s:       NNNNN"              (syaani + vihreä lihavoitu)
;   Rivi  5  "RAM  luku  B/s: NNNNN"
;   Rivi  6  "RAM  kirj. B/s: NNNNN"
;   Rivi  8  "Levy luku  B/s: NNNNN  blk/s: NNNNN"
;   Rivi  9  "Levy kirj. B/s: NNNNN  blk/s: NNNNN"
;   Rivi 11  "Mittaa: ..."                         (keltainen, vaihtuva status)
;
; VRAM-VÄRIKOODIT:
;   Otsikko:  keltainen lihavoitu  FG=3 bold = 0x4300
;   Etiketit: syaani               FG=6      = 0x0600
;   Numerot:  vihreä lihavoitu     FG=2 bold = 0x4200  →  '0' = 0x4230
;   Status:   keltainen            FG=3      = 0x0300
;   Erotin:   valkoinen            FG=7      = 0x0700
;
; MITTAUSTAPA:
;   Kutsutaan wait_sec (odottaa sekuntirajaa), käynnistetään laskuri,
;   pyöritetään mittaussilmukkaa kunnes CLOCK_SECOND muuttuu → count = ops/s.
;   1 CPU-silmukka ≈ 10 käskyä (6 NOP + ADD + LOAD + CMP + JZ).
;   1 RAM-sana = 2 tavua → B/s = W/s × 2 (saturoitu 65535:ään).
;   1 levy-blokki = 256 sanaa → blk/s = W/s / 256.
;
; REKISTERIT (globaalit koko ohjelman ajan):
;   R3 = 1    (askel-inkrementti)
;   R4 = 10   (desimaalijakaja write5:ssä)
;   R5 = 0x4230  (vihreä bold '0', perusmerkki numeroille)
;
; ALIOHJELMAT:
;   write_str  R8=vram-dst, R9=str-ptr, R10=väri → kirjoittaa null-terminoidun
;              merkkijonon VRAM:iin, asettaa R12=0, päivittää R8 ja R9
;   write5     R8=vram-dst, R1=n, R5=base-'0', R3=1, R4=10
;              → kirjoittaa 5-numeroisen desimaaliluvun, päivittää R8 +5
;   wait_sec   → R12 = uusi sekunti (odottaa sekuntirajaa)
;
; BENCHMARK-MUISTIALUEET:
;   RAM-puskuri:            0x4000–0x40FF  (256 sanaa, vapaa RAM)
;   Levy-benchmark-alue:    storage[0x1000–0x10FF]  (256 sanaa = 1 blokki)
;
; VAATII: Kernel-tilan (P=1) → DREAD/DWRITE toimivat käynnistyksen jälkeen.
; =============================================================================

        .origin 0x0200

        JUMP   main             ; Hyppää datan ja aliohjelmaesimerkkien yli

; =============================================================================
; KÄYTTÄJÄVAKIOT
; =============================================================================

.const RAM_BM_START, 0x4000    ; RAM-testipuskurin alkuosoite
.const RAM_BM_END,   0x4100    ; RAM-testipuskurin loppuosoite (ei mukaan)
.const DSK_BM_START, 0x1000    ; Levy-testin alkuosoite (storage-muisti)
.const DSK_BM_END,   0x1100    ; Levy-testin loppuosoite
.const BLOCK_WORDS,  256       ; Sanojen määrä yhdessä blokissa

; VRAM-riviosoitteet:  VRAM_Rn = 0xF800 + n * 80
.const VRAM_R0,  0xF800        ; Rivi  0: otsikko
.const VRAM_R1,  0xF850        ; Rivi  1: erotin      (0xF800 + 80)
.const VRAM_R3,  0xF8F0        ; Rivi  3: CPU         (0xF800 + 240)
.const VRAM_R5,  0xF990        ; Rivi  5: RAM luku    (0xF800 + 400)
.const VRAM_R6,  0xF9E0        ; Rivi  6: RAM kirj.   (0xF800 + 480)
.const VRAM_R8,  0xFA80        ; Rivi  8: Levy luku   (0xF800 + 640)
.const VRAM_R9,  0xFAD0        ; Rivi  9: Levy kirj.  (0xF800 + 720)
.const VRAM_R11, 0xFB70        ; Rivi 11: status      (0xF800 + 880)

; VRAM-värimääritelmiä
.const COL_TITLE, 0x4300       ; FG=3 (keltainen) + lihavoitu
.const COL_LABEL, 0x0600       ; FG=6 (syaani)
.const COL_SEP,   0x0700       ; FG=7 (valkoinen)
.const COL_STAT,  0x0300       ; FG=3 (keltainen)

; =============================================================================
; MERKKIJONODATA (null-terminoitu, .dstr = yksi sana/merkki + nollatavuu)
; =============================================================================

STR_TITLE:
        .dstr "kCPU16 NOPEUSMITTAUS"

STR_SEP:
        .dstr "===================="

; Tulosten etiketit — kaikki tasan 16 merkkiä, jolloin numero alkaa heti perään
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

; Liiteotsikot jotka kirjoitetaan numeron jälkeen
STR_BLKS_LBL:
        .dstr "  blk/s: "

; Tilaviestit — kaikki tasan 30 merkkiä, jotta edellinen tila ylikirjoittuu täydellisesti
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
; Kirjoita null-terminoitu merkkijono VRAM:iin väriattribuutin kanssa.
;
; Sisään:  R8  = VRAM-kohdeosoitin  (päivittyy: siirtyy kirjoituksen loppuun)
;          R9  = merkkijono-osoitin  (päivittyy: osoittaa null-terminaattoriin)
;          R10 = väriattribuutti     (ei muutu)
; Asettaa: R12 = 0  (null-vertailuarvo, alustetaan sisällä)
; Muuttaa: R11 (väliaikainen)
; =============================================================================
write_str:
        LOAD  R12, 0            ; R12 = 0 (null-terminaattorin vertailu)
ws_loop:
        LOAD  R11, [R9]         ; R11 = seuraava merkki lähteestä
        CMP   R11, R12          ; merkki == null?
        JZ    ws_done           ; kyllä → lopeta
        OR    R11, R10          ; R11 = merkki | väriattribuutti
        STORE [R8], R11         ; kirjoita VRAM-sana
        LOAD  R11, 1
        ADD   R8,  R11          ; VRAM-osoitin++
        ADD   R9,  R11          ; lähde-osoitin++
        JUMP  ws_loop
ws_done:
        RET

; =============================================================================
; ALIOHJELMA: write5
; =============================================================================
; Kirjoita 5-numeroinen desimaaliluku (0–65535) VRAM:iin.
;
; Sisään:  R8 = VRAM-kohdeosoitin  (päivittyy: +5 merkin verran)
;          R1 = luku 0–65535       (tuhoutuu — sisältää 0 paluun jälkeen)
;          R5 = perusmerkki = väriattribuutti + ASCII '0'  (esim. 0x4230)
;          R3 = 1  (globaali askelkertoimenn)
;          R4 = 10 (globaali desimaalijakaja)
; Muuttaa: R0 (jakaja temp), R7 (nykyinen numero), R8 (+5), R9 (temp)
; =============================================================================
write5:
        ; --- Kymmenen tuhannen paikkaa ---
        LOAD  R0, 10000
        CPY   R7, R1
        DIV   R7, R0            ; R7 = 10000-luku (0–6)
        CPY   R9, R7
        MUL   R9, R0            ; R9 = numero × 10000
        SUB   R1, R9            ; R1 = jäännös (0–9999)
        CPY   R9, R5
        ADD   R9, R7            ; R9 = perusmerkki + numero
        STORE [R8], R9
        ADD   R8, R3

        ; --- Tuhannen paikkaa ---
        LOAD  R0, 1000
        CPY   R7, R1
        DIV   R7, R0            ; R7 = 1000-luku (0–9)
        CPY   R9, R7
        MUL   R9, R0            ; R9 = numero × 1000
        SUB   R1, R9            ; R1 = jäännös (0–999)
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        ; --- Sadan paikkaa ---
        LOAD  R0, 100
        CPY   R7, R1
        DIV   R7, R0            ; R7 = 100-luku (0–9)
        CPY   R9, R7
        MUL   R9, R0            ; R9 = numero × 100
        SUB   R1, R9            ; R1 = jäännös (0–99)
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        ; --- Kymmenen paikkaa  (R4 = 10 on globaali vakio) ---
        CPY   R7, R1
        DIV   R7, R4            ; R7 = 10-luku (0–9)
        CPY   R9, R7
        MUL   R9, R4            ; R9 = numero × 10
        SUB   R1, R9            ; R1 = ykköspaikan luku (0–9)
        CPY   R9, R5
        ADD   R9, R7
        STORE [R8], R9
        ADD   R8, R3

        ; --- Yhden paikkaa ---
        CPY   R9, R5
        ADD   R9, R1            ; R1 = ykköspaikan luku
        STORE [R8], R9
        ADD   R8, R3

        RET

; =============================================================================
; ALIOHJELMA: wait_sec
; =============================================================================
; Odota sekuntirajaa: pysyy silmukassa kunnes CLOCK_SECOND muuttuu.
;
; Palauttaa: R12 = uusi CLOCK_SECOND-arvo
; Muuttaa:   R0  (edellinen sekunti väliaikaisesti)
; =============================================================================
wait_sec:
        LOAD  R0,  [CLOCK_SECOND]   ; R0 = nykyinen sekunti
wait_sec_loop:
        LOAD  R12, [CLOCK_SECOND]   ; R12 = tuorein sekunti
        CMP   R12, R0
        JZ    wait_sec_loop         ; ei muuttunut → odota
        RET                         ; R12 = uusi sekunti

; =============================================================================
; ALIOHJELMA: bench_cpu
; =============================================================================
; Mittaa CPU-silmukan nopeuden sekunnissa.
; Silmukkarakenne:  NOP×6 + ADD + LOAD + CMP + JZ  ≈ 10 käskyä/kierros
;
; Palauttaa: R13 = kierrosten lukumäärä 1 sekunnissa
; Muuttaa:   R0, R12, R13, R14
; =============================================================================
bench_cpu:
        CALL  wait_sec              ; R12 = uusi sekunti
        LOAD  R13, 0                ; R13 = kierroslaskuri
cpu_bm_loop:
        NOP                         ; benchmark-työ 1
        NOP                         ; benchmark-työ 2
        NOP                         ; benchmark-työ 3
        NOP                         ; benchmark-työ 4
        NOP                         ; benchmark-työ 5
        NOP                         ; benchmark-työ 6
        ADD   R13, R3               ; kierrosten laskuri++  (R3 = 1)
        LOAD  R14, [CLOCK_SECOND]   ; luetaan aika
        CMP   R14, R12              ; verrattaan aloitussekuntiin
        JZ    cpu_bm_loop           ; sama sekunti → jatka
        RET                         ; R13 = kierrosta/sekuntti

; =============================================================================
; ALIOHJELMA: bench_ram_read
; =============================================================================
; Mittaa RAM-lukemisnopeuden lukemalla 256 sanan puskuria toistuvasti.
; R13 = READ_IND-operaatioita/sekuntti  (= sanoja/sekuntti)
;
; Muuttaa: R0, R1, R2, R12, R13, R14
; =============================================================================
bench_ram_read:
        CALL  wait_sec
        LOAD  R13, 0
        LOAD  R0,  RAM_BM_START     ; R0 = puskurin osoitin
        LOAD  R2,  RAM_BM_END       ; R2 = puskurin loppuraja
ram_r_loop:
        LOAD  R1,  [R0]             ; lue RAM-puskurista (benchmark)
        ADD   R13, R3               ; laskuri++
        ADD   R0,  R3               ; osoitin++
        CMP   R0,  R2
        JLT   ram_r_chk             ; ei loppuun → tarkista aika
        LOAD  R0,  RAM_BM_START     ; puskurin kierrätys
ram_r_chk:
        LOAD  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    ram_r_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_ram_write
; =============================================================================
; Mittaa RAM-kirjoitusnopeuden kirjoittamalla 256 sanan puskuriin toistuvasti.
; R13 = STORE_IND-operaatioita/sekuntti  (= sanoja/sekuntti)
;
; Muuttaa: R0, R1, R2, R12, R13, R14
; =============================================================================
bench_ram_write:
        CALL  wait_sec
        LOAD  R13, 0
        LOAD  R0,  RAM_BM_START
        LOAD  R2,  RAM_BM_END
        LOAD  R1,  0xABCD           ; testiarvo (pysyy muuttumattomana)
ram_w_loop:
        STORE [R0], R1              ; kirjoita RAM-puskuriin (benchmark)
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   ram_w_chk
        LOAD  R0,  RAM_BM_START
ram_w_chk:
        LOAD  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    ram_w_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_dsk_read
; =============================================================================
; Mittaa tallennuslaitteen lukemisnopeuden (DREAD, Kernel-tila).
; Lukee 256 sanan testiä storage-muistista toistuvasti.
; R13 = DREAD-operaatioita/sekuntti  (= sanoja/sekuntti)
;
; Vaatii Kernel-tilan (P=1) — toimii käynnistyksen jälkeen.
; Muuttaa: R0, R1, R2, R12, R13, R14
; =============================================================================
bench_dsk_read:
        CALL  wait_sec
        LOAD  R13, 0
        LOAD  R0,  DSK_BM_START     ; R0 = testin storage-osoitin
        LOAD  R2,  DSK_BM_END
dsk_r_loop:
        DREAD R1,  R0               ; lue tallennuslaitteelta (benchmark)
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   dsk_r_chk
        LOAD  R0,  DSK_BM_START
dsk_r_chk:
        LOAD  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    dsk_r_loop
        RET

; =============================================================================
; ALIOHJELMA: bench_dsk_write
; =============================================================================
; Mittaa tallennuslaitteen kirjoitusnopeuden (DWRITE, Kernel-tila).
; R13 = DWRITE-operaatioita/sekuntti  (= sanoja/sekuntti)
;
; Vaatii Kernel-tilan (P=1).
; Muuttaa: R0, R1, R2, R12, R13, R14
; =============================================================================
bench_dsk_write:
        CALL  wait_sec
        LOAD  R13, 0
        LOAD  R0,  DSK_BM_START
        LOAD  R2,  DSK_BM_END
        LOAD  R1,  0x1234           ; testiarvo
dsk_w_loop:
        DWRITE R1, R0               ; kirjoita tallennuslaitteelle (benchmark)
        ADD   R13, R3
        ADD   R0,  R3
        CMP   R0,  R2
        JLT   dsk_w_chk
        LOAD  R0,  DSK_BM_START
dsk_w_chk:
        LOAD  R14, [CLOCK_SECOND]
        CMP   R14, R12
        JZ    dsk_w_loop
        RET

; =============================================================================
; PÄÄOHJELMA
; =============================================================================
main:
        ; -------------------------------------------------------
        ; Globaalien vakiorekistereiden alustus
        ; -------------------------------------------------------
        LOAD  R3,  1            ; R3  = 1  (askel-inkrementti)
        LOAD  R4,  10           ; R4  = 10 (kymmenenjakaja write5:ssä)
        LOAD  R5,  0x4230       ; R5  = vihreä bold '0' (numeroperusmerkki)

        ; -------------------------------------------------------
        ; Otsikkorivi 0
        ; -------------------------------------------------------
        LOAD  R8,  VRAM_R0
        LOAD  R9,  STR_TITLE
        LOAD  R10, COL_TITLE    ; keltainen lihavoitu
        CALL  write_str

        ; -------------------------------------------------------
        ; Erotinrivi 1
        ; -------------------------------------------------------
        LOAD  R8,  VRAM_R1
        LOAD  R9,  STR_SEP
        LOAD  R10, COL_SEP      ; valkoinen
        CALL  write_str

; =============================================================================
; PÄÄSILMUKKA — Kierrättää kaikkia viittä mittausta ikuisesti
; =============================================================================
main_loop:

        ; ============================================================
        ; MITTAUS 1: CPU-nopeus (käskyä/sekuntti, noin 10 käskyä/kierros)
        ; ============================================================

        ; Näytä mittausstatus rivi 11
        LOAD  R8,  VRAM_R11
        LOAD  R9,  STR_S_CPU
        LOAD  R10, COL_STAT
        CALL  write_str

        ; Suorita benchmark → R13 = silmukkakierroksia/sekuntti (1 kierros ≈ 10 käskyä)
        CALL  bench_cpu

        ; Laske kIPS (= kiloinstruction/sec) = R13 × 10 / 1000 = R13 / 100
        ; Emulaattori ajaa ~70 000 käskyä/s → R13 ≈ 7000 → kIPS ≈ 70
        ; Tulos mahtuu aina 16-bittiin (max kIPS ≈ R13_max/100 = 655)
        CPY   R1,  R13
        LOAD  R7,  100
        DIV   R1,  R7           ; R1 = kIPS (R13 / 100)
cpu_kps_show:
        ; Kirjoita rivi 3: "CPU  k/s:       NNNNN"
        LOAD  R8,  VRAM_R3
        LOAD  R9,  STR_CPU_LBL
        LOAD  R10, COL_LABEL    ; syaani etiketti
        CALL  write_str         ; R8 osoittaa nyt numeron kohdalle
        ; R1 = k/s, R5 = 0x4230, R3 = 1, R4 = 10
        CALL  write5

        ; ============================================================
        ; MITTAUS 2: RAM latausnopeus (tavua/sekuntti)
        ; ============================================================

        LOAD  R8,  VRAM_R11
        LOAD  R9,  STR_S_RAM_R
        LOAD  R10, COL_STAT
        CALL  write_str

        CALL  bench_ram_read    ; R13 = sanoja/sekuntti

        ; Laske B/s = R13 × 2 (1 sana = 2 tavua), saturoi 65535:ään
        ; CMP R13, 0: N=1 jos R13 >= 32768 (bitti 15 ylhäällä → × 2 ylivuotaisi)
        LOAD  R7,  0
        CMP   R13, R7
        JLT   rr_bps_sat        ; N=1, V=0 → R13 >= 32768 → saturoi
        CPY   R1,  R13
        ADD   R1,  R13          ; R1 = 2 × W/s
        JUMP  rr_bps_show
rr_bps_sat:
        LOAD  R1,  65535
rr_bps_show:
        ; Kirjoita rivi 5: "RAM  luku  B/s: NNNNN"
        LOAD  R8,  VRAM_R5
        LOAD  R9,  STR_RAM_R_LBL
        LOAD  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        ; ============================================================
        ; MITTAUS 3: RAM tallennusnopeus (tavua/sekuntti)
        ; ============================================================

        LOAD  R8,  VRAM_R11
        LOAD  R9,  STR_S_RAM_W
        LOAD  R10, COL_STAT
        CALL  write_str

        CALL  bench_ram_write   ; R13 = sanoja/sekuntti

        ; Laske B/s = R13 × 2
        LOAD  R7,  0
        CMP   R13, R7
        JLT   rw_bps_sat
        CPY   R1,  R13
        ADD   R1,  R13
        JUMP  rw_bps_show
rw_bps_sat:
        LOAD  R1,  65535
rw_bps_show:
        ; Kirjoita rivi 6: "RAM  kirj. B/s: NNNNN"
        LOAD  R8,  VRAM_R6
        LOAD  R9,  STR_RAM_W_LBL
        LOAD  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        ; ============================================================
        ; MITTAUS 4: Tallennuslaitteen lukusnopeus (B/s ja blk/s)
        ; ============================================================

        LOAD  R8,  VRAM_R11
        LOAD  R9,  STR_S_DSK_R
        LOAD  R10, COL_STAT
        CALL  write_str

        CALL  bench_dsk_read    ; R13 = sanoja/sekuntti

        ; Laske B/s (→ R1) ja blk/s (→ R2)
        ; B/s ensin
        LOAD  R7,  0
        CMP   R13, R7
        JLT   dr_bps_sat
        CPY   R1,  R13
        ADD   R1,  R13          ; R1 = B/s
        JUMP  dr_bps_done
dr_bps_sat:
        LOAD  R1,  65535
dr_bps_done:
        ; blk/s = W/s / 256
        LOAD  R7,  BLOCK_WORDS  ; R7 = 256
        CPY   R2,  R13
        DIV   R2,  R7           ; R2 = blk/s

        ; Kirjoita rivi 8: "Levy luku  B/s: NNNNN  blk/s: NNNNN"
        LOAD  R8,  VRAM_R8
        LOAD  R9,  STR_DSK_R_LBL
        LOAD  R10, COL_LABEL
        CALL  write_str         ; "Levy luku  B/s: "  → R8 on B/s-numerokohta
        CALL  write5            ; kirjoita B/s (R1), R8 siirtyy eteenpäin

        LOAD  R9,  STR_BLKS_LBL
        CALL  write_str         ; "  blk/s: "  → R8 on blk-numerokohta
        CPY   R1,  R2           ; R1 = blk/s
        CALL  write5            ; kirjoita blk/s

        ; ============================================================
        ; MITTAUS 5: Tallennuslaitteen kirjoitusnopeus (B/s ja blk/s)
        ; ============================================================

        LOAD  R8,  VRAM_R11
        LOAD  R9,  STR_S_DSK_W
        LOAD  R10, COL_STAT
        CALL  write_str

        CALL  bench_dsk_write   ; R13 = sanoja/sekuntti

        ; Laske B/s (→ R1) ja blk/s (→ R2)
        LOAD  R7,  0
        CMP   R13, R7
        JLT   dw_bps_sat
        CPY   R1,  R13
        ADD   R1,  R13
        JUMP  dw_bps_done
dw_bps_sat:
        LOAD  R1,  65535
dw_bps_done:
        LOAD  R7,  BLOCK_WORDS
        CPY   R2,  R13
        DIV   R2,  R7           ; R2 = blk/s

        ; Kirjoita rivi 9: "Levy kirj. B/s: NNNNN  blk/s: NNNNN"
        LOAD  R8,  VRAM_R9
        LOAD  R9,  STR_DSK_W_LBL
        LOAD  R10, COL_LABEL
        CALL  write_str
        CALL  write5

        LOAD  R9,  STR_BLKS_LBL
        CALL  write_str
        CPY   R1,  R2
        CALL  write5

        ; ============================================================
        ; Kierrä: mittaa kaikki uudestaan
        ; ============================================================
        JUMP  main_loop
