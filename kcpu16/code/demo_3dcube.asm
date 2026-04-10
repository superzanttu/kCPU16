; =============================================================================
; demo_3dcube.asm — Pyörivä 3D-kuutio grafiikkatilassa B ja C
; =============================================================================
;
; KUVAUS:
;   Piirtää pyörivän wireframe-3D-kuution grafiikkanäytölle.
;   Pyörittää kuutiota samanaikaisesti kaikkien kolmen akselin ympäri:
;     Y: nopea  (64 askelta/kierros, joka kehys)
;     X: hidas  (64 askelta/kierros, joka 3. kehys)
;     Z: hitain (64 askelta/kierros, joka 5. kehys)
;
;   Vaihe 1 (20 s): Tila B — 80 × 48 pikseliä (kuution säde 12 pikseliä)
;   Vaihe 2 (20 s): Tila C — 160 × 96 pikseliä (säde skaalattu ×2 = 24 px)
;   Tämän jälkeen: käynnistyy alusta vaiheesta 1.
;
; PYÖRITYSALGORITMI (järjestys X→Y→Z, ortografinen projektio):
;   X: ay=(vy·cox−vz·six)/100, az=(vy·six+vz·cox)/100, ax=vx
;   Y: bx=(ax·coy−az·siy)/100, by=ay
;   Z: cx=(bx·coz−by·siz)/100, cy=(bx·siz+by·coz)/100
;   Projektio: screen_x = center_x + cx  (tila B: center=40,24)
;              screen_y = center_y + cy  (tila C: center=80,48, skaala ×2)
;
; KIINTEÄPISTE-ARITMETIIKKA:
;   sin/cos-taulu: arvot × 100 (alue −100 … 100)
;   Kertolaskun jälkeen jaetaan 100:lla (smul_div100-aliohjelma).
;   Etumerkillinen 16-bittinen kahdenkomplementti läpi koko laskennan;
;   2-komplementti ADD/SUB toimii suoraan positiivisille näyttökoordinaateille.
;
; DATAN TALLENNUSMUOTO:
;   Koordinaattitaulukot (cube_vx, cube_vy, cube_vz, sin_table, edge_table)
;   tallennetaan .dw-direktiivilla kokonaisina 16-bittisinä sanoina.
;   Negatiiviset arvot muunnetaan automaattisesti 2-komplementiksi.
;
; REKISTERIEN GLOBAALI KÄYTTÖ (main-silmukoissa):
;   R14 = grafiikkatila (1=B, 2=C) — säilyy gfx_line/smul_div100-kutsujen yli
;   R13, R15 = silmukkalaskurit draw_cube_frame:ssä
;   R0–R12 = scratch / lib-gfx-kutsut
;   angle, angle_x, angle_z, cnt_x, cnt_z, sin/cos_cache_* = muistissa
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/demo_3dcube.asm
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; =============================================================================
; Kirjasto (gfx_clear, gfx_pixel, gfx_line)
; =============================================================================

        .include "lib-gfx.asm"

; =============================================================================
; Sinustaulukko — sin(i × 5.625°) × 100, pyöristettynä kokonaisluvuiksi
; i = 0 … 63  (64 alkiota = täysi kierros)
;
; Kaavoitus:
;   sin(i) = sin_table[i & 63]
;   cos(i) = sin_table[(i + 16) & 63]   (koska cos x = sin(x + 90°))
;
; Tallennettu .dw-direktiivillä — negatiiviset arvot 2-komplementtina.
; =============================================================================

sin_table:
        .dw    0,  10,  20,  29,  38,  47,  56,  63
        .dw   71,  77,  83,  88,  92,  96,  98, 100
        .dw  100, 100,  98,  96,  92,  88,  83,  77
        .dw   71,  63,  56,  47,  38,  29,  20,  10
        .dw    0, -10, -20, -29, -38, -47, -56, -63
        .dw  -71, -77, -83, -88, -92, -96, -98, -100
        .dw -100, -100, -98, -96, -92, -88, -83, -77
        .dw  -71, -63, -56, -47, -38, -29, -20, -10

; =============================================================================
; Kuution kärkipisteiden koordinaatit (8 kärkipistettä)
;
; Kuutio: ±12 pikseliä. Säde 12 takaa ettei mikään piste ylitä
; näyttöaluetta kolmiakselisen pyörityksen aikana (max etäisyys = 12√3 ≈ 21).
; Kärkipisteet:
;   0:(−12,−12,−12)  1:(12,−12,−12)  2:(12,12,−12)  3:(−12,12,−12)
;   4:(−12,−12, 12)  5:(12,−12, 12)  6:(12,12, 12)  7:(−12,12, 12)
;
; Kolmiakselinen X→Y→Z-rotaatio lasketaan dynaamisesti draw_cube_frame:ssä.
;
; Tallennettu .dw-direktiivillä.
; =============================================================================

cube_vx:
        .dw  -12,  12,  12, -12, -12,  12,  12, -12

cube_vy:
        .dw  -12, -12,  12,  12, -12, -12,  12,  12

cube_vz:
        .dw  -12, -12, -12, -12,  12,  12,  12,  12

; =============================================================================
; Projisoidut näyttökoordinaatit (täytetään draw_cube_frame-kutsussa)
; =============================================================================

proj_x:
        .dw    0,   0,   0,   0,   0,   0,   0,   0

proj_y:
        .dw    0,   0,   0,   0,   0,   0,   0,   0

; =============================================================================
; Kaaritaulukko — 12 kaarta, kukin (v0, v1) kärkipiste-indeksiparina
;
;   Etupinta (z<0): 0–1, 1–2, 2–3, 3–0
;   Takapinta (z>0): 4–5, 5–6, 6–7, 7–4
;   Yhdistävät:     0–4, 1–5, 2–6, 3–7
;
; Tallennettu .dw-direktiivillä (24 sanaa yhteensä).
; =============================================================================

edge_table:
        .dw  0, 1     ; etupinta
        .dw  1, 2
        .dw  2, 3
        .dw  3, 0
        .dw  4, 5     ; takapinta
        .dw  5, 6
        .dw  6, 7
        .dw  7, 4
        .dw  0, 4     ; yhdistävät reunat
        .dw  1, 5
        .dw  2, 6
        .dw  3, 7

; =============================================================================
; Tilamuuttujat
; =============================================================================

phase:
        .db  0         ; 0=tila B käynnissä, 1=tila C käynnissä, 2=käynnistä uudelleen

angle:
        .db  0         ; Y-akselin rotaatiokulma (0–63, joka kehys)

angle_x:
        .db  0         ; X-akselin rotaatiokulma (0–63, joka 3. kehys)

angle_z:
        .db  0         ; Z-akselin rotaatiokulma (0–63, joka 5. kehys)

cnt_x:
        .db  0         ; kehyslaskuri angle_x:n päivitykseen

cnt_z:
        .db  0         ; kehyslaskuri angle_z:n päivitykseen

; Esilasketut sin/cos-arvot (täytetään draw_cube_frame:n alussa joka kehyksellä)
sin_cache_x:
        .dw  0
cos_cache_x:
        .dw  0
sin_cache_y:
        .dw  0
cos_cache_y:
        .dw  0
sin_cache_z:
        .dw  0
cos_cache_z:
        .dw  0

; =============================================================================
; clock_handler — Kellokeskeytyksen käsittelijä (INT 9)
;
; Kasvattaa demo-vaihetta yhdellä.
; Jos uusi phase < 2, käynnistää 20 sekunnin ajastimen uudelleen.
; Jos uusi phase >= 2, pysäyttää ajastimen (pääsilmukka käynnistää sen).
;
; Clobbers: R0, R1 (tallennetaan pinoon ja palautetaan ennen IRET:ä).
; =============================================================================

clock_handler:
        PUSH  R0
        PUSH  R1

        ; phase++
        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        STORE [phase], R0

        ; Jos phase >= 2, pysäytä ajastin
        READ  R1, 2
        CMP   R0, R1
        JGE   _ch_stop

        ; phase < 2: käynnistä 20 sekunnin ajastin uudelleen
        READ  R0, 20000
        SCTMR R0
        JUMP  _ch_done

_ch_stop:
        READ  R0, 0
        SCTMR R0

_ch_done:
        POP   R1
        POP   R0
        IRET

; =============================================================================
; smul_div100 — Etumerkillinen kertolasku jaettuna 100:lla
;
; Sisään:  R0 = kerroin A (etumerkillinen 16-bittinen, 2-komplementti)
;          R1 = kerroin B (etumerkillinen 16-bittinen, 2-komplementti)
; Ulos:    R0 = (A × B) / 100  (etumerkillinen, kokonaislukujakolasku)
; Clobbers: R0–R5
;
; Toiminta:
;   1. Normalisoi: negoi negatiiviset tulot, seuraa etumerkkiä R3:ssa
;   2. Kertoo absoluuttiarvot (etumerkitön MUL)
;   3. Jakaa 100:lla (etumerkitön DIV)
;   4. Palauttaa tuloksen oikealla etumerkillä
;
; Rekisterit R6–R15 jätetään koskemattomiksi — kutsuva koodi voi
; nojata tähän pitäessään arvoja niissä.
; =============================================================================

smul_div100:
        READ  R2, 0x8000      ; etumerkkilipun maski (bitti 15)
        READ  R3, 0           ; tulosmerkki: 0 = positiivinen, 1 = negatiivinen
        READ  R5, 0           ; nollakonstantti vertailuja varten

        ; --- Tarkista R0:n etumerkki ---
        CPY   R4, R0
        AND   R4, R2          ; R4 = R0:n etumerkkilippu
        CMP   R4, R5
        JZ    _smul_r0_ok

        ; R0 on negatiivinen: negate (2-komplementti: ~R0 + 1)
        NOT   R0
        READ  R4, 1
        ADD   R0, R4
        READ  R4, 1
        XOR   R3, R4          ; käännä tulosmerkki

_smul_r0_ok:
        ; --- Tarkista R1:n etumerkki ---
        CPY   R4, R1
        AND   R4, R2          ; R4 = R1:n etumerkkilippu
        CMP   R4, R5          ; R5 on edelleen 0
        JZ    _smul_r1_ok

        ; R1 on negatiivinen: negate
        NOT   R1
        READ  R4, 1
        ADD   R1, R4
        READ  R4, 1
        XOR   R3, R4          ; käännä tulosmerkki

_smul_r1_ok:
        ; --- Etumerkitön kertolasku ja jako ---
        MUL   R0, R1          ; R0 = |A| × |B|
        READ  R4, 100
        DIV   R0, R4          ; R0 = (|A| × |B|) / 100

        ; --- Palauta etumerkki ---
        CMP   R3, R5          ; R5 on edelleen 0
        JZ    _smul_done

        ; Tulos on negatiivinen: negate
        NOT   R0
        READ  R4, 1
        ADD   R0, R4

_smul_done:
        RET

; =============================================================================
; draw_cube_frame — Piirrä yksi kuutioanimaatiokehys
;
; Sisään:  R14 = grafiikkatila (1 = tila B, 2 = tila C)
;          angle, angle_x, angle_z muistissa = rotaatiokulmat (0–63)
; Ulos:    —
; Clobbers: R0–R13, R15   (R14 = tila säilyy)
;
; smul_div100 clobbers R0–R5 → R6–R15 säilyvät sen kutsujen yli.
; gfx_line   clobbers R0–R12 → R13, R14, R15 säilyvät.
;
; VAIHE 0: Esitallennetaan sin/cos kaikille kolmelle kulmalle:
;   sin_cache_x/y/z, cos_cache_x/y/z
;
; VAIHE 1: Projisoidaan 8 kärkipistettä — rotaatio järjestyksessä X→Y→Z.
;   Rekisterikartta vertex-silmukassa (säilyvät smul_div100:n yli):
;     R8  = ax=vx (→ ax·cos_y/100 → bx)
;     R9  = vy (→ bx·cos_z/100 → cx)
;     R10 = vz (→ bx·sin_z/100 → cy)
;     R11 = ay (= by, ei muutu Y-rotaatiossa)
;     R12 = az (→ ei enää tarvita Y-rotaation jälkeen)
;     R14 = grafiikkatila (koskematon)
;     R15 = kärkipiste-indeksi (koskematon)
;
; VAIHE 2: Piirretään 12 kaarta edge_table:sta proj_x/proj_y-arvojen avulla.
; =============================================================================

draw_cube_frame:
        ; === VAIHE 0: Esilaskenta — sin/cos kaikille kolmelle kulmalle ===

        ; --- angle_x ---
        READ  R0, [angle_x]
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [sin_cache_x], R2
        READ  R1, 16
        ADD   R0, R1
        READ  R1, 63
        AND   R0, R1
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [cos_cache_x], R2

        ; --- angle (Y-akseli) ---
        READ  R0, [angle]
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [sin_cache_y], R2
        READ  R1, 16
        ADD   R0, R1
        READ  R1, 63
        AND   R0, R1
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [cos_cache_y], R2

        ; --- angle_z ---
        READ  R0, [angle_z]
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [sin_cache_z], R2
        READ  R1, 16
        ADD   R0, R1
        READ  R1, 63
        AND   R0, R1
        READ  R1, sin_table
        ADD   R1, R0
        READ  R2, [R1]
        STORE [cos_cache_z], R2

        ; === VAIHE 1: Kärkipisteiden 3D-rotaatio ja projektio ===
        READ  R15, 0          ; R15 = kärkipiste-indeksi (0–7)

_dcf_vertex_loop:
        ; Lataa vx[R15], vy[R15], vz[R15]
        READ  R0, cube_vx
        ADD   R0, R15
        READ  R8, [R0]        ; R8 = vx (= ax, ei muutu X-rotaatiossa)

        READ  R0, cube_vy
        ADD   R0, R15
        READ  R9, [R0]        ; R9 = vy

        READ  R0, cube_vz
        ADD   R0, R15
        READ  R10, [R0]       ; R10 = vz

        ; --- X-akselin rotaatio ---
        ; ay = (vy·cos_x − vz·sin_x) / 100
        CPY   R0, R9
        READ  R1, [cos_cache_x]
        CALL  smul_div100     ; R0 = vy·cos_x/100
        CPY   R11, R0         ; R11 = vy·cos_x/100

        CPY   R0, R10
        READ  R1, [sin_cache_x]
        CALL  smul_div100     ; R0 = vz·sin_x/100
        SUB   R11, R0         ; R11 = ay

        ; az = (vy·sin_x + vz·cos_x) / 100
        CPY   R0, R9
        READ  R1, [sin_cache_x]
        CALL  smul_div100     ; R0 = vy·sin_x/100
        CPY   R12, R0         ; R12 = vy·sin_x/100

        CPY   R0, R10
        READ  R1, [cos_cache_x]
        CALL  smul_div100     ; R0 = vz·cos_x/100
        ADD   R12, R0         ; R12 = az

        ; Nyt: R8=ax=vx, R11=ay, R12=az

        ; --- Y-akselin rotaatio ---
        ; bx = (ax·cos_y − az·sin_y) / 100,  by = ay (R11 muuttumaton)
        CPY   R0, R8
        READ  R1, [cos_cache_y]
        CALL  smul_div100     ; R0 = ax·cos_y/100
        CPY   R8, R0          ; R8 = ax·cos_y/100 (välivaihe)

        CPY   R0, R12
        READ  R1, [sin_cache_y]
        CALL  smul_div100     ; R0 = az·sin_y/100
        SUB   R8, R0          ; R8 = bx

        ; R11 = by = ay (ei koskaan muutettu)

        ; --- Z-akselin rotaatio ---
        ; cx = (bx·cos_z − by·sin_z) / 100
        CPY   R0, R8
        READ  R1, [cos_cache_z]
        CALL  smul_div100     ; R0 = bx·cos_z/100
        CPY   R9, R0          ; R9 = bx·cos_z/100  (R9:n vy ei enää tarvita)

        CPY   R0, R11
        READ  R1, [sin_cache_z]
        CALL  smul_div100     ; R0 = by·sin_z/100
        SUB   R9, R0          ; R9 = cx

        ; cy = (bx·sin_z + by·cos_z) / 100
        CPY   R0, R8
        READ  R1, [sin_cache_z]
        CALL  smul_div100     ; R0 = bx·sin_z/100
        CPY   R10, R0         ; R10 = bx·sin_z/100  (R10:n vz ei enää tarvita)

        CPY   R0, R11
        READ  R1, [cos_cache_z]
        CALL  smul_div100     ; R0 = by·cos_z/100
        ADD   R10, R0         ; R10 = cy

        ; Nyt: R9=cx (projisoitu X), R10=cy (projisoitu Y)

        ; --- Sovella skaalaus ja siirros tilan mukaan ---
        READ  R4, 2
        CMP   R14, R4
        JNZ   _dcf_mode_b

        ; Tila C: skaalaa ×2, keskipiste (80, 48)
        ADD   R9, R9          ; cx × 2
        ADD   R10, R10        ; cy × 2
        READ  R0, 80
        ADD   R9, R0
        READ  R0, 48
        ADD   R10, R0
        JUMP  _dcf_store

_dcf_mode_b:
        ; Tila B: suoraan, keskipiste (40, 24)
        READ  R0, 40
        ADD   R9, R0
        READ  R0, 24
        ADD   R10, R0

_dcf_store:
        ; Tallenna proj_x[R15] ja proj_y[R15]
        READ  R0, proj_x
        ADD   R0, R15
        STORE [R0], R9        ; proj_x[R15] = screen_x

        READ  R0, proj_y
        ADD   R0, R15
        STORE [R0], R10       ; proj_y[R15] = screen_y

        ; Seuraava kärkipiste
        READ  R0, 1
        ADD   R15, R0
        READ  R0, 8
        CMP   R15, R0
        JNZ   _dcf_vertex_loop

        ; === VAIHE 2: Piirrä 12 kaarta ===
        ; gfx_line clobbers R0–R12, mutta R13 ja R15 pysyvät!
        READ  R13, 0          ; R13 = edge_table sanatason offset (0, 2, 4 … 22)
        READ  R15, 0          ; R15 = kaarilaskuri (0–11)

_dcf_edge_loop:
        ; Lue v0 ja v1 edge_table:sta
        READ  R0, edge_table
        ADD   R0, R13
        READ  R4, [R0]        ; R4 = v0
        READ  R5, 1
        ADD   R0, R5          ; R0 → edge_table[R13 + 1]
        READ  R5, [R0]        ; R5 = v1

        ; Lataa proj_x[v0] → R0
        READ  R0, proj_x
        ADD   R0, R4
        READ  R0, [R0]        ; R0 = proj_x[v0]

        ; Lataa proj_y[v0] → R1
        READ  R1, proj_y
        ADD   R1, R4
        READ  R1, [R1]        ; R1 = proj_y[v0]

        ; Lataa proj_x[v1] → R2
        READ  R2, proj_x
        ADD   R2, R5
        READ  R2, [R2]        ; R2 = proj_x[v1]

        ; Lataa proj_y[v1] → R3
        READ  R3, proj_y
        ADD   R3, R5
        READ  R3, [R3]        ; R3 = proj_y[v1]

        ; Piirrä viiva (R0,R1) → (R2,R3)
        ; gfx_line clobbers R0–R12 mutta EI R13, R14, R15
        CALL  gfx_line

        ; Edistä kaarilaskuria
        READ  R0, 2
        ADD   R13, R0         ; R13 += 2  (kaksi sanaa per kaari)
        READ  R0, 1
        ADD   R15, R0         ; R15 += 1
        READ  R0, 12
        CMP   R15, R0
        JNZ   _dcf_edge_loop

        RET

; =============================================================================
; main — Pääohjelma
; =============================================================================

main:
        ; Rekisteröi kellokeskeytyksen käsittelijä (INT 9 -vektori = osoite 9)
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

        ; Salli (laitteisto)keskeytykset
        STI

restart_loop:
        ; Nollaa tilamuuttujat phase..cnt_z yhtenä alueena (FILL: inklusiiviinen)
        READ  R0, phase
        READ  R1, cnt_z
        READ  R2, 0
        FILL  R0, R1, R2

        ; Aseta piirtotila: etuväri (pikselit piirretään päälle, ei XOR)
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Käynnistä 20 sekunnin kellokeskeytys tila B:lle
        READ  R0, 20000
        SCTMR R0

        ; Aseta grafiikkatila B
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 1          ; R14 = 1 (tila B)

; --- Tila B -piirtosilmukka ---
b_loop:
        CALL  gfx_clear
        CALL  draw_cube_frame

        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip

        ; Kasvata Y-rotaatiokulmaa (0–63), nollaa kierroksen jälkeen
        READ  R0, [angle]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 64
        CMP   R0, R1
        JNZ   _b_no_wrap
        READ  R0, 0
_b_no_wrap:
        STORE [angle], R0

        ; Kasvata angle_x (joka 3. kehys)
        READ  R0, [cnt_x]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 3
        CMP   R0, R1
        JNZ   _b_cnt_x_done
        READ  R0, 0
        READ  R1, [angle_x]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _b_ax_no_wrap
        READ  R1, 0
_b_ax_no_wrap:
        STORE [angle_x], R1
_b_cnt_x_done:
        STORE [cnt_x], R0

        ; Kasvata angle_z (joka 5. kehys)
        READ  R0, [cnt_z]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 5
        CMP   R0, R1
        JNZ   _b_cnt_z_done
        READ  R0, 0
        READ  R1, [angle_z]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _b_az_no_wrap
        READ  R1, 0
_b_az_no_wrap:
        STORE [angle_z], R1
_b_cnt_z_done:
        STORE [cnt_z], R0

        ; Tarkista vaihe — jos edelleen 0, jatka tila B:tä
        READ  R0, [phase]
        READ  R1, 0
        CMP   R0, R1
        JZ    b_loop

        ; Vaihe muuttui: siirry tila C:hen
        ; (clock_handler on jo käynnistänyt 20 s ajastimen uudelleen)
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 2          ; R14 = 2 (tila C)

; --- Tila C -piirtosilmukka ---
c_loop:
        CALL  gfx_clear
        CALL  draw_cube_frame

        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip

        ; Kasvata Y-rotaatiokulmaa (0–63), nollaa kierroksen jälkeen
        READ  R0, [angle]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 64
        CMP   R0, R1
        JNZ   _c_no_wrap
        READ  R0, 0
_c_no_wrap:
        STORE [angle], R0

        ; Kasvata angle_x (joka 3. kehys)
        READ  R0, [cnt_x]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 3
        CMP   R0, R1
        JNZ   _c_cnt_x_done
        READ  R0, 0
        READ  R1, [angle_x]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _c_ax_no_wrap
        READ  R1, 0
_c_ax_no_wrap:
        STORE [angle_x], R1
_c_cnt_x_done:
        STORE [cnt_x], R0

        ; Kasvata angle_z (joka 5. kehys)
        READ  R0, [cnt_z]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 5
        CMP   R0, R1
        JNZ   _c_cnt_z_done
        READ  R0, 0
        READ  R1, [angle_z]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _c_az_no_wrap
        READ  R1, 0
_c_az_no_wrap:
        STORE [angle_z], R1
_c_cnt_z_done:
        STORE [cnt_z], R0

        ; Tarkista vaihe — jos edelleen 1, jatka tila C:tä
        READ  R0, [phase]
        READ  R1, 1
        CMP   R0, R1
        JZ    c_loop

        ; Vaihe on 2: aloita koko animaatio alusta
        JUMP  restart_loop
