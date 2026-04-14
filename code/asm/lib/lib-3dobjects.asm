; =============================================================================
; lib_3dobjects.asm — 3D-objektikirjasto demo_3dcube.asm ja demo_3dcube2.asm:lle
; =============================================================================
;
; SISÄLTÖ:
;   1. sin_table          — yhteinen sinustaulu (64 alkiota)
;   2. smul_div100        — etumerkillinen kertolasku jaettuna 100:lla
;   3. cube               — kuutio (8 kärkipistettä, 12 kaarta, 6 tahkoa)
;   4. letter_L           — L-kirjain, 3D-extruded (12 kärkipistettä, 18 kaarta, 8 tahkoa)
;   5. letter_J           — J-kirjain, 3D-extruded (12 kärkipistettä, 18 kaarta, 8 tahkoa)
;   6. pyramid            — nelipohjainen pyramidi (5 kärkipistettä, 8 kaarta, 5 tahkoa)
;
; KÄYTTÖ:
;   Osoita haluamaasi objektiin asettamalla obj_ptr_* -muuttujat ennen
;   draw_object_frame-kutsua:
;
;       READ  R0, cube_num_vertices   ; tai letter_L_num_vertices jne.
;       STORE [obj_num_vertices], R0
;       ; ... muut osoittimet ...
;
; EXTRUDED-KIRJAINGEOMETRIA:
;   Profiili XY-tasossa, extrusoitu Z:n suhteen ±5 yksikköä.
;   Indeksit 0..N-1 = etupinta (z=-5), N..2N-1 = takapinta (z=+5).
;   Skaalattu niin että max etäisyys origosta ≈ 15 (sopii ruudulle).
;
;   L-profiili (6 pistettä):
;     0:(-10,-12)  1:(-2,-12)   <- pystyosan yläreunat
;     2:(-2,  2)   3:(10,  2)   <- sisäkulma + vaakaosan oikea ylä
;     4:(10, 12)   5:(-10,12)   <- pohja
;
;   J-profiili (6 pistettä):
;     0:(-8,-12)  1:(8,-12)    <- ylevän palkin yläreunat
;     2:(8, 12)   3:(2, 12)    <- pystyosan oikea reuna alas + koukun sisäkulma
;     4:(2, -4)   5:(-8, -4)   <- palkin pohja (kapea pystyosa oikealla)
;     (J-muoto: leveä ylevä palkki, kapea pystyosa oikealla, koukku vasemmalle)
;
; TAHKOTAULUKOT (num_faces=8 per kirjain):
;   Tahkot 0–1: etu- ja takapinta (6-kulmainen)
;     — jaetaan kolmioiksi (kulmaispiste + 2 peräkkäistä), 4 kolmiota per pinta
;     — mutta demo_3dcube2 odottaa 3-alkion rivejä face_table:ssa
;   Tahkot 2–7: 6 sivutahkoa (suorakulmiot)
;     — kukin suorakulmiollinen sivutahko esitetään kahtena kolmiona:
;       face[i] = (i, i+1, N+i+1) ja toisena (i, N+i+1, N+i)
;     — tässä kirjastossa kukin suorakulmiollinen sivu on yksi face-tietue (3 pist.)
;       yksinkertaistettuna: face[2+i] = (i, (i+1)%N, N+(i+1)%N)
;
; REUNOJEN NÄKYVYYS (edge_face_table):
;   Kullekin kaarelle kaksi viereistä face-indeksiä.
;   Käyttämättömillä "kaarilla" (esim. fannen sisäviivat) voidaan asettaa
;   molemmiksi -1 → ei koskaan piirretä. Tässä käytetään 0xFF:ää.
;
; REKISTERIVAATIMUKSET:
;   Sama kuin demo_3dcube*.asm — katso draw_object_frame.
; =============================================================================

; =============================================================================
; sin_table — sin(i × 5.625°) × 100, pyöristettynä
; i = 0 … 63  (64 alkiota = täysi kierros)
; cos(i) = sin_table[(i + 16) & 63]
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
; OBJEKTI 1: KUUTIO
;
; 8 kärkipistettä: ±12 pikseliä.
;   0:(−12,−12,−12)  1:(12,−12,−12)  2:(12,12,−12)  3:(−12,12,−12)
;   4:(−12,−12, 12)  5:(12,−12, 12)  6:(12,12, 12)  7:(−12,12, 12)
; 12 kaarta, 6 tahkoa.
; =============================================================================

cube_num_vertices:
        .dw  8

cube_num_edges:
        .dw  12

cube_num_faces:
        .dw  6

cube_vx:
        .dw  -12,  12,  12, -12, -12,  12,  12, -12

cube_vy:
        .dw  -12, -12,  12,  12, -12, -12,  12,  12

cube_vz:
        .dw  -12, -12, -12, -12,  12,  12,  12,  12

cube_edges:
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

; face_id:t 0=front,1=back,2=left,3=right,4=bottom,5=top
cube_edge_faces:
        .dw  0, 4
        .dw  0, 3
        .dw  0, 5
        .dw  0, 2
        .dw  1, 4
        .dw  1, 3
        .dw  1, 5
        .dw  1, 2
        .dw  2, 4
        .dw  3, 4
        .dw  3, 5
        .dw  2, 5

; Tahkot: kolme kärkipistettä (normaalin laskentaan)
cube_faces:
        .dw  0, 3, 2   ; front  (z < 0)
        .dw  4, 5, 6   ; back   (z > 0)
        .dw  0, 4, 7   ; left   (x < 0)
        .dw  1, 2, 6   ; right  (x > 0)
        .dw  0, 1, 5   ; bottom (y < 0)
        .dw  3, 7, 6   ; top    (y > 0)

; =============================================================================
; OBJEKTI 2: L-KIRJAIN (3D-extruded)
;
; L-profiili 6 kärkipisteellä XY-tasossa, extrusoitu Z-akselilla ±5.
; Indeksit 0–5: etupinta (z=−5), indeksit 6–11: takapinta (z=+5).
;
; Profiili (myötäpäivään): katsojan näkökulmasta etupinnalle:
;   0:(−10,−12)  <- pystyosan vasenyläkulma
;   1:( −2,−12)  <- pystyosan oikeayläkulma
;   2:( −2,  2)  <- sisäkulma (pystyosa kohtaa vaakaosan)
;   3:( 10,  2)  <- vaakaosan oikeayläkulma
;   4:( 10, 12)  <- vaakaosan oikeaalakulma
;   5:(−10, 12)  <- pystyosan vasenalakulma
;
; 18 kaarta:
;   Etupinta  (0–5): 0→1, 1→2, 2→3, 3→4, 4→5, 5→0       6 kaarta
;   Takapinta (6–11): 6→7, 7→8, 8→9, 9→10, 10→11, 11→6   6 kaarta
;   Yhdistävät (12–17): 0→6, 1→7, 2→8, 3→9, 4→10, 5→11   6 kaarta
;
; 8 tahkoa:
;   0: etupinta  (kärkipisteet 0,5,4,3,2,1 — normaalin laskentaan 0,5,4)
;   1: takapinta (6,7,8,9,10,11 — normaalin laskentaan 6,7,8)
;   2–7: 6 sivutahkoa (suorakulmiot)
;     tahko 2: sivu 0→1 — kärkipisteet 0,1,7,6
;     tahko 3: sivu 1→2 — kärkipisteet 1,2,8,7
;     tahko 4: sivu 2→3 — kärkipisteet 2,3,9,8
;     tahko 5: sivu 3→4 — kärkipisteet 3,4,10,9
;     tahko 6: sivu 4→5 — kärkipisteet 4,5,11,10
;     tahko 7: sivu 5→0 — kärkipisteet 5,0,6,11
; =============================================================================

letter_L_num_vertices:
        .dw  12

letter_L_num_edges:
        .dw  18

letter_L_num_faces:
        .dw  8

letter_L_vx:
        ; Etupinta (z=-5): i=0..5
        .dw  -10,  -2,  -2,  10,  10, -10
        ; Takapinta (z=+5): i=6..11
        .dw  -10,  -2,  -2,  10,  10, -10

letter_L_vy:
        ; Etupinta
        .dw  -12, -12,   2,   2,  12,  12
        ; Takapinta
        .dw  -12, -12,   2,   2,  12,  12

letter_L_vz:
        ; Etupinta (z=-5)
        .dw   -5,  -5,  -5,  -5,  -5,  -5
        ; Takapinta (z=+5)
        .dw    5,   5,   5,   5,   5,   5

letter_L_edges:
        ; Etupinta (6 kaarta)
        .dw  0, 1
        .dw  1, 2
        .dw  2, 3
        .dw  3, 4
        .dw  4, 5
        .dw  5, 0
        ; Takapinta (6 kaarta)
        .dw  6,  7
        .dw  7,  8
        .dw  8,  9
        .dw  9, 10
        .dw 10, 11
        .dw 11,  6
        ; Yhdistävät (6 kaarta)
        .dw  0,  6
        .dw  1,  7
        .dw  2,  8
        .dw  3,  9
        .dw  4, 10
        .dw  5, 11

; Kullekin kaarelle kaksi viereistä tahkoa
; Tahkot: 0=etu, 1=taka, 2=sivu01, 3=sivu12, 4=sivu23, 5=sivu34, 6=sivu45, 7=sivu50
letter_L_edge_faces:
        ; Etupinta-kaaret (tahko 0 ja viereinen sivutahko)
        .dw  0, 2    ; kaari 0→1: etu(0) + sivu 0→1(2)
        .dw  0, 3    ; kaari 1→2: etu(0) + sivu 1→2(3)
        .dw  0, 4    ; kaari 2→3: etu(0) + sivu 2→3(4)
        .dw  0, 5    ; kaari 3→4: etu(0) + sivu 3→4(5)
        .dw  0, 6    ; kaari 4→5: etu(0) + sivu 4→5(6)
        .dw  0, 7    ; kaari 5→0: etu(0) + sivu 5→0(7)
        ; Takapinta-kaaret
        .dw  1, 2    ; kaari 6→7:  taka(1) + sivu 0→1(2)
        .dw  1, 3    ; kaari 7→8:  taka(1) + sivu 1→2(3)
        .dw  1, 4    ; kaari 8→9:  taka(1) + sivu 2→3(4)
        .dw  1, 5    ; kaari 9→10: taka(1) + sivu 3→4(5)
        .dw  1, 6    ; kaari 10→11:taka(1) + sivu 4→5(6)
        .dw  1, 7    ; kaari 11→6: taka(1) + sivu 5→0(7)
        ; Yhdistävät kaaret (kaksi sivutahkoa kohtaavat)
        .dw  7, 2    ; kaari 0→6:  sivu50(7) + sivu01(2)
        .dw  2, 3    ; kaari 1→7:  sivu01(2) + sivu12(3)
        .dw  3, 4    ; kaari 2→8:  sivu12(3) + sivu23(4)
        .dw  4, 5    ; kaari 3→9:  sivu23(4) + sivu34(5)
        .dw  5, 6    ; kaari 4→10: sivu34(5) + sivu45(6)
        .dw  6, 7    ; kaari 5→11: sivu45(6) + sivu50(7)

; Tahkot (3 kärkipistettä normaalin laskentaan):
; Etupinta: CCW ruutukoordinaateissa (Y alas) → normal_z < 0 → näkyvä kun kamera -Z:ssa
; Takapinta: CW ruutukoordinaateissa → normal_z > 0 → näkyvä kun kamera +Z:ssa
letter_L_faces:
        .dw  0,  2,  1    ; 0: etupinta (normal_z < 0: CCW ruutukoord.)
        .dw  6,  7,  8    ; 1: takapinta (normal_z > 0: CW ruutukoord.)
        .dw  0,  1,  7    ; 2: sivu 0→1 (yläreuna pystyosalla)
        .dw  1,  2,  8    ; 3: sivu 1→2 (pystyosan oikeareuna alas)
        .dw  2,  3,  9    ; 4: sivu 2→3 (sisäkulma → oikea, ylhäältä)
        .dw  3,  4, 10    ; 5: sivu 3→4 (oikea reuna alas)
        .dw  4,  5, 11    ; 6: sivu 4→5 (pohja)
        .dw  5,  0,  6    ; 7: sivu 5→0 (vasen reuna)

; =============================================================================
; OBJEKTI 3: J-KIRJAIN (3D-extruded)
;
; J-profiili 6 kärkipisteellä XY-tasossa, extrusoitu Z-akselilla ±5.
; Indeksit 0–5: etupinta (z=−5), indeksit 6–11: takapinta (z=+5).
;
; Profiili (myötäpäivään etupinnalta katsottuna):
;   0:(−8,−12)  <- ylevän palkin vasenyläkulma
;   1:( 8,−12)  <- ylevän palkin oikeayläkulma
;   2:( 8, 12)  <- pystyosan oikeaalakulma (koukku oikealla alhaalla)
;   3:( 2, 12)  <- koukun sisäoikeakulma (koukku kääntyy vasemmalle)
;   4:( 2, −4)  <- pystyosan sisäkulma (palkin pohja)
;   5:(−8, −4)  <- ylevän palkin vasenaalakulma
;
; J-muoto: leveä ylevä palkki + kapea pystyosa oikealla + koukku vasemmalle alhaalla.
;
; Sama rakenne kuin L:
;   18 kaarta, 8 tahkoa.
; =============================================================================

letter_J_num_vertices:
        .dw  12

letter_J_num_edges:
        .dw  18

letter_J_num_faces:
        .dw  8

letter_J_vx:
        ; Etupinta (z=-5): i=0..5
        .dw   -8,   8,   8,   2,   2,  -8
        ; Takapinta (z=+5): i=6..11
        .dw   -8,   8,   8,   2,   2,  -8

letter_J_vy:
        ; Etupinta
        .dw  -12, -12,  12,  12,  -4,  -4
        ; Takapinta
        .dw  -12, -12,  12,  12,  -4,  -4

letter_J_vz:
        ; Etupinta (z=-5)
        .dw   -5,  -5,  -5,  -5,  -5,  -5
        ; Takapinta (z=+5)
        .dw    5,   5,   5,   5,   5,   5

letter_J_edges:
        ; Etupinta (6 kaarta)
        .dw  0, 1
        .dw  1, 2
        .dw  2, 3
        .dw  3, 4
        .dw  4, 5
        .dw  5, 0
        ; Takapinta (6 kaarta)
        .dw  6,  7
        .dw  7,  8
        .dw  8,  9
        .dw  9, 10
        .dw 10, 11
        .dw 11,  6
        ; Yhdistävät (6 kaarta)
        .dw  0,  6
        .dw  1,  7
        .dw  2,  8
        .dw  3,  9
        .dw  4, 10
        .dw  5, 11

; Tahkot: 0=etu, 1=taka, 2=sivu01, 3=sivu12, 4=sivu23, 5=sivu34, 6=sivu45, 7=sivu50
letter_J_edge_faces:
        ; Etupinta-kaaret
        .dw  0, 2    ; kaari 0→1: etu(0) + sivu01(2)
        .dw  0, 3    ; kaari 1→2: etu(0) + sivu12(3)
        .dw  0, 4    ; kaari 2→3: etu(0) + sivu23(4)
        .dw  0, 5    ; kaari 3→4: etu(0) + sivu34(5)
        .dw  0, 6    ; kaari 4→5: etu(0) + sivu45(6)
        .dw  0, 7    ; kaari 5→0: etu(0) + sivu50(7)
        ; Takapinta-kaaret
        .dw  1, 2    ; kaari 6→7:  taka(1) + sivu01(2)
        .dw  1, 3    ; kaari 7→8:  taka(1) + sivu12(3)
        .dw  1, 4    ; kaari 8→9:  taka(1) + sivu23(4)
        .dw  1, 5    ; kaari 9→10: taka(1) + sivu34(5)
        .dw  1, 6    ; kaari 10→11:taka(1) + sivu45(6)
        .dw  1, 7    ; kaari 11→6: taka(1) + sivu50(7)
        ; Yhdistävät kaaret
        .dw  7, 2    ; kaari 0→6:  sivu50(7) + sivu01(2)
        .dw  2, 3    ; kaari 1→7:  sivu01(2) + sivu12(3)
        .dw  3, 4    ; kaari 2→8:  sivu12(3) + sivu23(4)
        .dw  4, 5    ; kaari 3→9:  sivu23(4) + sivu34(5)
        .dw  5, 6    ; kaari 4→10: sivu34(5) + sivu45(6)
        .dw  6, 7    ; kaari 5→11: sivu45(6) + sivu50(7)

letter_J_faces:
        .dw  0,  2,  1    ; 0: etupinta (normal_z < 0: CCW ruutukoord.)
        .dw  6,  7,  8    ; 1: takapinta (normal_z > 0: CW ruutukoord.)
        .dw  0,  1,  7    ; 2: sivu 0→1 (yläreuna)
        .dw  1,  2,  8    ; 3: sivu 1→2 (oikea reuna alas)
        .dw  2,  3,  9    ; 4: sivu 2→3 (koukun yläreuna)
        .dw  3,  4, 10    ; 5: sivu 3→4 (koukun oikea sisäreuna alas)
        .dw  4,  5, 11    ; 6: sivu 4→5 (palkin pohja = sisäreuna vaakaan)
        .dw  5,  0,  6    ; 7: sivu 5→0 (vasen reuna ylhäälle)

; =============================================================================
; OBJEKTI 4: PYRAMIDI (nelipohjainen)
;
; 5 kärkipistettä:
;   0:(−10, 10,−10)  1:(10, 10,−10)  2:(10, 10, 10)  3:(−10, 10, 10)
;   4:(  0,−12,  0)  ← huippu
;
; Kärkipisteindeksit: pohja = 0–3, huippu = 4.
; Tahkot: 0=pohja, 1=etu(−10<z<0 sivu), 2=oikea, 3=taka, 4=vasen
;
; Tahkon normaali osoittaa ulospain:
;   pohja: +Y, etu: −Z, oikea: +X, taka: +Z, vasen: −X
; =============================================================================

pyramid_num_vertices:
        .dw  5

pyramid_num_edges:
        .dw  8

pyramid_num_faces:
        .dw  5

pyramid_vx:
        .dw  -10,  10,  10, -10,   0

pyramid_vy:
        .dw   10,  10,  10,  10, -12

pyramid_vz:
        .dw  -10, -10,  10,  10,   0

pyramid_edges:
        ; Pohja (4 kaarta)
        .dw  0, 1
        .dw  1, 2
        .dw  2, 3
        .dw  3, 0
        ; Sivut → huippu (4 kaarta)
        .dw  0, 4
        .dw  1, 4
        .dw  2, 4
        .dw  3, 4

; face_id:t: 0=pohja, 1=etu, 2=oikea, 3=taka, 4=vasen
pyramid_edge_faces:
        ; Pohjakaaret (pohja + sivutahko)
        .dw  0, 1    ; kaari 0→1: pohja(0) + etu(1)
        .dw  0, 2    ; kaari 1→2: pohja(0) + oikea(2)
        .dw  0, 3    ; kaari 2→3: pohja(0) + taka(3)
        .dw  0, 4    ; kaari 3→0: pohja(0) + vasen(4)
        ; Sivukaaret → huippu (kaksi sivutahkoa kohtaavat)
        .dw  4, 1    ; kaari 0→4: vasen(4) + etu(1)
        .dw  1, 2    ; kaari 1→4: etu(1) + oikea(2)
        .dw  2, 3    ; kaari 2→4: oikea(2) + taka(3)
        .dw  3, 4    ; kaari 3→4: taka(3) + vasen(4)

; Tahkot (3 kärkipistettä normaalin laskentaan):
pyramid_faces:
        .dw  0, 3, 2    ; 0: pohja   (normaali +Y, CW pohjalta ylöspäin)
        .dw  0, 1, 4    ; 1: etu     (normaali −Z)
        .dw  1, 2, 4    ; 2: oikea   (normaali +X)
        .dw  2, 3, 4    ; 3: taka    (normaali +Z)
        .dw  3, 0, 4    ; 4: vasen   (normaali −X)
