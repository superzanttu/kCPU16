; =============================================================================
; lib_3dobjects.asm — 3D-objektikirjasto demo_3dcube.asm ja demo_3dcube2.asm:lle
; =============================================================================
;
; SISÄLTÖ:
;   1. sin_table          — yhteinen sinustaulu (64 alkiota)
;   2. cube               — kuutio (8 kärkipistettä, 12 kaarta, 6 tahkoa)
;   3. letter_L           — L-kirjain, 3D-extruded (12 kärkipistettä, 18 kaarta, 8 tahkoa)
;   4. letter_J           — J-kirjain, 3D-extruded (12 kärkipistettä, 18 kaarta, 8 tahkoa)
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
;     0:(-10,-12)  1:(10,-12)   <- yläreunat
;     2:(10,  4)   3:( 2,  4)   <- pystyosan oikeapuoli
;     4:( 2, 12)   5:(-10,12)   <- koukku vasemmalle
;     (J kääntyy alhaalla vasemmalle)
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
        .dw  0, 7    ; kaari 0→1: etu + sivu50 (0,1,7,6) wait: 5→0 on tahko7, 0→1 on tahko2
        .dw  0, 2    ; kaari 0→1: etu(0) + sivu 0→1(2)
        .dw  0, 3    ; kaari 1→2: etu(0) + sivu 1→2(3)
        .dw  0, 4    ; kaari 2→3: etu(0) + sivu 2→3(4)
        .dw  0, 5    ; kaari 3→4: etu(0) + sivu 3→4(5)
        .dw  0, 6    ; kaari 4→5: etu(0) + sivu 4→5(6)
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
; Etupinta: profiili myötäpäivään katsottuna edestä → normaali osoittaa -Z
; Takapinta: profiili vastapäivään katsottuna edestä → normaali osoittaa +Z
letter_L_faces:
        .dw  0,  1,  2    ; 0: etupinta (normaali -Z, kärkipist. myötäpäivään)
        .dw  6,  8,  7    ; 1: takapinta (normaali +Z, kärkipist. vastapäivään)
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
;   0:(−10,−12)  <- vasenyläkulma (ristikko ylhäältä)
;   1:( 10,−12)  <- oikeayläkulma
;   2:( 10,  4)  <- pystyosan oikeaalakulma
;   3:(  2,  4)  <- koukun sisäoikeakulma
;   4:(  2, 12)  <- koukun alaoikeakulma
;   5:(−10, 12)  <- vasenaalakulma (koukku kääntyy vasemmalle)
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
        .dw  -10,  10,  10,   2,   2, -10
        ; Takapinta (z=+5): i=6..11
        .dw  -10,  10,  10,   2,   2, -10

letter_J_vy:
        ; Etupinta
        .dw  -12, -12,   4,   4,  12,  12
        ; Takapinta
        .dw  -12, -12,   4,   4,  12,  12

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
        .dw  0,  1,  2    ; 0: etupinta
        .dw  6,  8,  7    ; 1: takapinta
        .dw  0,  1,  7    ; 2: sivu 0→1 (yläreuna)
        .dw  1,  2,  8    ; 3: sivu 1→2 (oikea reuna alas)
        .dw  2,  3,  9    ; 4: sivu 2→3 (koukun yläreuna)
        .dw  3,  4, 10    ; 5: sivu 3→4 (koukun oikeareuna)
        .dw  4,  5, 11    ; 6: sivu 4→5 (pohja)
        .dw  5,  0,  6    ; 7: sivu 5→0 (vasen reuna)
