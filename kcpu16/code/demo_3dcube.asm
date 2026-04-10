; =============================================================================
; demo_3dcube.asm — Pyörivä 3D-kuutio grafiikkatilassa B ja C
; =============================================================================
;
; KUVAUS:
;   Piirtää pyörivän wireframe-3D-kuution grafiikkanäytölle.
;   Pyörittää kuutiota Y-akselin ympäri (64 askelta per täysi kierros).
;   Kuutio on esikallistettu ~25° X-akselin ympäri, jotta myös ala- ja
;   yläpinnat näkyvät – ei pelkkää vaakatasoa.
;
;   Vaihe 1 (20 s): Tila B — 80 × 48 pikseliä (kuution säde 15 pikseliä)
;   Vaihe 2 (20 s): Tila C — 160 × 96 pikseliä (säde skaalattu ×2 = 30 px)
;   Tämän jälkeen: käynnistyy alusta vaiheesta 1.
;
; PYÖRITYSALGORITMI (Y-akseli):
;   nx = (vx · cos θ − vz · sin θ) / 100
;   ny =  vy  (muuttumaton)
;   Ortografinen projektio:
;     screen_x = center_x + nx          (tila B: center=40,24)
;     screen_y = center_y + ny          (tila C: center=80,48, skaala ×2)
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
; Alkuperäinen kuutio: ±15 pikseliä, kärkipisteet:
;   0:(−15,−15,−15)  1:(15,−15,−15)  2:(15,15,−15)  3:(−15,15,−15)
;   4:(−15,−15, 15)  5:(15,−15, 15)  6:(15,15, 15)  7:(−15,15, 15)
;
; Esikallistus ~25° X-akselin ympäri (cos≈91/100, sin≈42/100):
;   y' = y·cos − z·sin ≈ y·91/100 − z·42/100
;   z' = y·sin + z·cos ≈ y·42/100 + z·91/100
;
; Tulokset (pyöristettynä kokonaisluvuiksi):
;   0:(−15, −7,−20)  1:(15, −7,−20)  2:(15, 20, −7)  3:(−15, 20, −7)
;   4:(−15,−20,  7)  5:(15,−20,  7)  6:(15,  7, 20)  7:(−15,  7, 20)
;
; Tallennettu .dw-direktiivillä.
; =============================================================================

cube_vx:
        .dw  -15,  15,  15, -15, -15,  15,  15, -15

cube_vy:
        .dw   -7,  -7,  20,  20, -20, -20,   7,   7

cube_vz:
        .dw  -20, -20,  -7,  -7,   7,   7,  20,  20

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
        .db  0         ; rotaatiokulma (0–63, yksi täysi kierros = 64 askelta)

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
        LOAD  R0, [phase]
        LOAD  R1, 1
        ADD   R0, R1
        STORE [phase], R0

        ; Jos phase >= 2, pysäytä ajastin
        LOAD  R1, 2
        CMP   R0, R1
        JGE   _ch_stop

        ; phase < 2: käynnistä 20 sekunnin ajastin uudelleen
        LOAD  R0, 20000
        SCTMR R0
        JUMP  _ch_done

_ch_stop:
        LOAD  R0, 0
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
        LOAD  R2, 0x8000      ; etumerkkilipun maski (bitti 15)
        LOAD  R3, 0           ; tulosmerkki: 0 = positiivinen, 1 = negatiivinen
        LOAD  R5, 0           ; nollakonstantti vertailuja varten

        ; --- Tarkista R0:n etumerkki ---
        CPY   R4, R0
        AND   R4, R2          ; R4 = R0:n etumerkkilippu
        CMP   R4, R5
        JZ    _smul_r0_ok

        ; R0 on negatiivinen: negate (2-komplementti: ~R0 + 1)
        NOT   R0
        LOAD  R4, 1
        ADD   R0, R4
        LOAD  R4, 1
        XOR   R3, R4          ; käännä tulosmerkki

_smul_r0_ok:
        ; --- Tarkista R1:n etumerkki ---
        CPY   R4, R1
        AND   R4, R2          ; R4 = R1:n etumerkkilippu
        CMP   R4, R5          ; R5 on edelleen 0
        JZ    _smul_r1_ok

        ; R1 on negatiivinen: negate
        NOT   R1
        LOAD  R4, 1
        ADD   R1, R4
        LOAD  R4, 1
        XOR   R3, R4          ; käännä tulosmerkki

_smul_r1_ok:
        ; --- Etumerkitön kertolasku ja jako ---
        MUL   R0, R1          ; R0 = |A| × |B|
        LOAD  R4, 100
        DIV   R0, R4          ; R0 = (|A| × |B|) / 100

        ; --- Palauta etumerkki ---
        CMP   R3, R5          ; R5 on edelleen 0
        JZ    _smul_done

        ; Tulos on negatiivinen: negate
        NOT   R0
        LOAD  R4, 1
        ADD   R0, R4

_smul_done:
        RET

; =============================================================================
; draw_cube_frame — Piirrä yksi kuutioanimaatiokehys
;
; Sisään:  R14 = grafiikkatila (1 = tila B, 2 = tila C)
;          angle-muuttuja muistissa = nykyinen rotaatiokulma (0–63)
; Ulos:    —
; Clobbers: R0–R13, R15   (R14 = tila säilyy)
;
; gfx_line clobbers R0–R12 → R13, R14, R15 ovat turvassa sen kutsujen yli.
; smul_div100 clobbers R0–R5 → R6–R15 ovat turvassa sen kutsujen yli.
;
; VAIHE 1: Projisoidaan kaikki 8 kärkipistettä
;   Y-akselin rotaatio:  nx = (vx·cos − vz·sin) / 100,  ny = vy
;   Tila B:  screen = (40 + nx,  24 + ny)
;   Tila C:  screen = (80 + nx·2, 48 + ny·2)
;
; VAIHE 2: Piirretään 12 kaarta edge_table:sta proj_x/proj_y-arvojen avulla
; =============================================================================

draw_cube_frame:
        ; Lataa rotaatiokulma R13:een (käytetään eri VAIHE 1:ssä)
        LOAD  R13, [angle]

        ; --- VAIHE 1: Kärkipisteiden Y-akselin pyöritys ja projektio ---
        LOAD  R15, 0          ; R15 = kärkipiste-indeksi (0–7)

_dcf_vertex_loop:
        ; Lataa vx[R15], vy[R15], vz[R15]
        LOAD  R0, cube_vx
        ADD   R0, R15
        LOAD  R8, [R0]        ; R8 = vx (etumerkillinen)

        LOAD  R0, cube_vy
        ADD   R0, R15
        LOAD  R9, [R0]        ; R9 = vy (etumerkillinen)

        LOAD  R0, cube_vz
        ADD   R0, R15
        LOAD  R10, [R0]       ; R10 = vz (etumerkillinen)

        ; Hae sin(angle): sin_table[angle]
        LOAD  R0, sin_table
        ADD   R0, R13
        LOAD  R6, [R0]        ; R6 = sin(angle) × 100

        ; Hae cos(angle): sin_table[(angle + 16) & 63]
        LOAD  R0, 16
        ADD   R0, R13         ; R0 = angle + 16
        LOAD  R4, 63
        AND   R0, R4          ; R0 = (angle + 16) & 63
        LOAD  R4, sin_table
        ADD   R0, R4          ; R0 = &sin_table[(angle+16)&63]
        LOAD  R7, [R0]        ; R7 = cos(angle) × 100

        ; Laske vx·cos/100
        ; smul_div100 clobbers R0–R5 mutta R6,R7,R8,R9,R10,R13,R14,R15 pysyvät
        CPY   R0, R8          ; R0 = vx
        CPY   R1, R7          ; R1 = cos
        CALL  smul_div100     ; R0 = vx·cos/100
        CPY   R11, R0         ; R11 = vx·cos/100 (säilytetään)

        ; Laske vz·sin/100
        CPY   R0, R10         ; R0 = vz
        CPY   R1, R6          ; R1 = sin
        CALL  smul_div100     ; R0 = vz·sin/100

        ; nx = vx·cos/100 − vz·sin/100
        ; SUB toimii oikein 2-komplementissa myös negatiivisilla arvoilla
        SUB   R11, R0         ; R11 = nx

        ; ny = vy (R9 säilyy muuttumattomana)

        ; --- Sovella skaalaus ja siirros tilan mukaan ---
        LOAD  R4, 2
        CMP   R14, R4
        JNZ   _dcf_mode_b

        ; Tila C: skaalaa ×2, keskipiste (80, 48)
        CPY   R0, R11
        ADD   R11, R0         ; R11 = nx × 2  (etumerkitön ADD = 2-komplementin×2 ✓)
        CPY   R0, R9
        ADD   R9, R0          ; R9  = ny × 2
        LOAD  R0, 80
        ADD   R11, R0         ; R11 = screen_x
        LOAD  R0, 48
        ADD   R9, R0          ; R9  = screen_y
        JUMP  _dcf_store

_dcf_mode_b:
        ; Tila B: suoraan, keskipiste (40, 24)
        LOAD  R0, 40
        ADD   R11, R0         ; R11 = screen_x
        LOAD  R0, 24
        ADD   R9, R0          ; R9  = screen_y

_dcf_store:
        ; Tallenna proj_x[R15] ja proj_y[R15]
        LOAD  R0, proj_x
        ADD   R0, R15
        STORE [R0], R11       ; proj_x[R15] = screen_x

        LOAD  R0, proj_y
        ADD   R0, R15
        STORE [R0], R9        ; proj_y[R15] = screen_y

        ; Seuraava kärkipiste
        LOAD  R0, 1
        ADD   R15, R0
        LOAD  R0, 8
        CMP   R15, R0
        JNZ   _dcf_vertex_loop

        ; --- VAIHE 2: Piirrä 12 kaarta ---
        ; gfx_line clobbers R0–R12, mutta R13 ja R15 pysyvät!
        LOAD  R13, 0          ; R13 = edge_table sanatason offset (0, 2, 4 … 22)
        LOAD  R15, 0          ; R15 = kaarilaskuri (0–11)

_dcf_edge_loop:
        ; Lue v0 ja v1 edge_table:sta
        LOAD  R0, edge_table
        ADD   R0, R13
        LOAD  R4, [R0]        ; R4 = v0
        LOAD  R5, 1
        ADD   R0, R5          ; R0 → edge_table[R13 + 1]
        LOAD  R5, [R0]        ; R5 = v1

        ; Lataa proj_x[v0] → R0
        LOAD  R0, proj_x
        ADD   R0, R4
        LOAD  R0, [R0]        ; R0 = proj_x[v0]

        ; Lataa proj_y[v0] → R1
        LOAD  R1, proj_y
        ADD   R1, R4
        LOAD  R1, [R1]        ; R1 = proj_y[v0]

        ; Lataa proj_x[v1] → R2
        LOAD  R2, proj_x
        ADD   R2, R5
        LOAD  R2, [R2]        ; R2 = proj_x[v1]

        ; Lataa proj_y[v1] → R3
        LOAD  R3, proj_y
        ADD   R3, R5
        LOAD  R3, [R3]        ; R3 = proj_y[v1]

        ; Piirrä viiva (R0,R1) → (R2,R3)
        ; gfx_line clobbers R0–R12 mutta EI R13, R14, R15
        CALL  gfx_line

        ; Edistä kaarilaskuria
        LOAD  R0, 2
        ADD   R13, R0         ; R13 += 2  (kaksi sanaa per kaari)
        LOAD  R0, 1
        ADD   R15, R0         ; R15 += 1
        LOAD  R0, 12
        CMP   R15, R0
        JNZ   _dcf_edge_loop

        RET

; =============================================================================
; main — Pääohjelma
; =============================================================================

main:
        ; Rekisteröi kellokeskeytyksen käsittelijä (INT 9 -vektori = osoite 9)
        LOAD  R0, clock_handler
        STORE [INT_CLOCK], R0

        ; Salli (laitteisto)keskeytykset
        STI

restart_loop:
        ; Nollaa tilamuuttujat
        LOAD  R0, 0
        STORE [phase], R0
        STORE [angle], R0

        ; Käynnistä 20 sekunnin kellokeskeytys tila B:lle
        LOAD  R0, 20000
        SCTMR R0

        ; Aseta grafiikkatila B
        LOAD  R0, GFX_MODE_B
        LOAD  R1, GFX_MODE_REG
        STORE [R1], R0

        LOAD  R14, 1          ; R14 = 1 (tila B)

; --- Tila B -piirtosilmukka ---
b_loop:
        CALL  gfx_clear
        CALL  draw_cube_frame

        ; Kasvata rotaatiokulmaa (0–63), nollaa kierroksen jälkeen
        LOAD  R0, [angle]
        LOAD  R1, 1
        ADD   R0, R1
        LOAD  R1, 64
        CMP   R0, R1
        JNZ   _b_no_wrap
        LOAD  R0, 0
_b_no_wrap:
        STORE [angle], R0

        ; Tarkista vaihe — jos edelleen 0, jatka tila B:tä
        LOAD  R0, [phase]
        LOAD  R1, 0
        CMP   R0, R1
        JZ    b_loop

        ; Vaihe muuttui: siirry tila C:hen
        ; (clock_handler on jo käynnistänyt 20 s ajastimen uudelleen)
        LOAD  R0, GFX_MODE_C
        LOAD  R1, GFX_MODE_REG
        STORE [R1], R0

        LOAD  R14, 2          ; R14 = 2 (tila C)

; --- Tila C -piirtosilmukka ---
c_loop:
        CALL  gfx_clear
        CALL  draw_cube_frame

        ; Kasvata rotaatiokulmaa
        LOAD  R0, [angle]
        LOAD  R1, 1
        ADD   R0, R1
        LOAD  R1, 64
        CMP   R0, R1
        JNZ   _c_no_wrap
        LOAD  R0, 0
_c_no_wrap:
        STORE [angle], R0

        ; Tarkista vaihe — jos edelleen 1, jatka tila C:tä
        LOAD  R0, [phase]
        LOAD  R1, 1
        CMP   R0, R1
        JZ    c_loop

        ; Vaihe on 2: aloita koko animaatio alusta
        JUMP  restart_loop
