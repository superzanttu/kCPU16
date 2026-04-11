; =============================================================================
; demo_3dcube2.asm — Pyörivä 3D-objekti, jossa näkymättömät reunat piilotetaan
; =============================================================================
;
; KUVAUS:
;   Piirtää pyörivän wireframe-3D-objektin grafiikkanäytölle.
;   Pyörittää objektia samanaikaisesti kahden akselin ympäri:
;     X: nopeampi (64 askelta/kierros, joka 3. kehys)
;     Z: hitaampi (64 askelta/kierros, joka 5. kehys)
;
;   Vaihe 0 (10 s): Tila B — kuutio (säde 12 pikseliä)
;   Vaihe 1 (10 s): Tila C — L-kirjain (skaalattu ×2)
;   Vaihe 2 (10 s): Tila B — J-kirjain
;   Tämän jälkeen: käynnistyy alusta vaiheesta 0.
;
; PYÖRITYSALGORITMI (järjestys X→Z, ortografinen projektio):
;   X: ay=(vy·cox−vz·six)/100, az=(vy·six+vz·cox)/100, ax=vx
;   Z: cx=(ax·coz−ay·siz)/100, cy=(ax·siz+ay·coz)/100
;   Projektio: screen_x = center_x + cx  (tila B: center=40,24)
;              screen_y = center_y + cy  (tila C: center=80,48, skaala ×2)
;
; KIINTEÄPISTE-ARITMETIIKKA:
;   sin/cos-taulu: arvot × 100 (alue −100 … 100)
;   Kertolaskun jälkeen jaetaan 100:lla (smul_div100-aliohjelma).
;   Etumerkillinen 16-bittinen kahdenkomplementti läpi koko laskennan;
;   2-komplementti ADD/SUB toimii suoraan positiivisille näyttökoordinaateille.
;
; OBJEKTIKIRJASTO:
;   Objektien data tulee lib_3dobjects.asm:sta (.include).
;   Aktiivinen objekti osoitetaan obj_* -osoitinmuuttujilla.
;
; DATAN TALLENNUSMUOTO:
;   Koordinaattitaulukot tallennetaan .dw-direktiivilla.
;   Negatiiviset arvot muunnetaan automaattisesti 2-komplementiksi.
;
; REKISTERIEN GLOBAALI KÄYTTÖ (main-silmukoissa):
;   R14 = grafiikkatila (1=B, 2=C) — säilyy gfx_line/smul_div100-kutsujen yli
;   R13, R15 = silmukkalaskurit draw_object_frame:ssä
;   R0–R12 = scratch / lib-gfx-kutsut
;   angle_x, angle_z, cnt_x, cnt_z, sin/cos_cache_x/z = muistissa
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/demo_3dcube2.asm
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; =============================================================================
; Kirjasto (gfx_clear, gfx_pixel, gfx_line)
; =============================================================================

        .include "lib-gfx.asm"

; =============================================================================
; Objektidata (sin_table, cube, letter_L, letter_J)
; =============================================================================

        .include "lib_3dobjects.asm"

; =============================================================================
; Projisoidut näyttökoordinaatit — tila 12 kärkipisteelle (L ja J = 12)
; =============================================================================

proj_x:
        .dw    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

proj_y:
        .dw    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

; Rotaation 3D-välikoordinaatit (X-vaiheen jälkeen) — piiloviivapoistoon
rot_x:
        .dw    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

rot_y:
        .dw    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

rot_z:
        .dw    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

; =============================================================================
; Osoitinmuuttujat aktiiviseen objektiin
; =============================================================================

obj_vx_ptr:
        .dw  0
obj_vy_ptr:
        .dw  0
obj_vz_ptr:
        .dw  0
obj_edges_ptr:
        .dw  0
obj_edge_faces_ptr:
        .dw  0
obj_faces_ptr:
        .dw  0
obj_num_vertices:
        .dw  0
obj_num_edges:
        .dw  0
obj_num_faces:
        .dw  0

; =============================================================================
; Tilamuuttujat
; =============================================================================

phase:
        .db  0         ; 0=kuutio B, 1=L-kirjain C, 2=J-kirjain B, 3=restart

angle_x:
        .db  0         ; X-akselin rotaatiokulma (0–63)

angle_z:
        .db  0         ; Z-akselin rotaatiokulma (0–63)

cnt_x:
        .db  0         ; kehyslaskuri angle_x:n päivitykseen

cnt_z:
        .db  0         ; kehyslaskuri angle_z:n päivitykseen

; Esilasketut sin/cos-arvot (täytetään draw_object_frame:n alussa joka kehyksellä)
sin_cache_x:
        .dw  0
cos_cache_x:
        .dw  0
sin_cache_z:
        .dw  0
cos_cache_z:
        .dw  0

; Tahkojen näkyvyystaulukko — max 8 tahkoa (L ja J = 8 tahkoa)
face_visible:
        .dw  0, 0, 0, 0, 0, 0, 0, 0

; =============================================================================
; clock_handler — Kellokeskeytyksen käsittelijä (INT 9)
;
; Kasvattaa demo-vaihetta yhdellä.
; Jos uusi phase < 4, käynnistää 20 sekunnin ajastimen uudelleen.
; Jos uusi phase >= 4, pysäyttää ajastimen (pääsilmukka käynnistää sen).
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

        ; Jos phase >= 3, pysäytä ajastin
        READ  R1, 3
        CMP   R0, R1
        JGE   _ch_stop

        ; phase < 3: käynnistä 10 sekunnin ajastin uudelleen
        READ  R0, 10000
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
; smul_div100 — siirretty lib_3dobjects.asm:iin (.include yllä tuo sen mukaan)
; =============================================================================

; =============================================================================
; draw_object_frame — Piirrä yksi animaatiokehys, piiloviivan poisto
;
; Sisään:  R14 = grafiikkatila (1 = tila B, 2 = tila C)
;          angle_x, angle_z muistissa = rotaatiokulmat (0–63)
;          obj_*_ptr ja obj_num_* = aktiivinen objekti
; Ulos:    —
; Clobbers: R0–R13, R15   (R14 = tila säilyy)
;
; VAIHE 0: sin/cos-esilaskenta.
; VAIHE 1: Rotaatio ja projektio — tallennetaan myös rot_x/y/z piiloviivapoistoon.
; VAIHE 2: Lasketaan näkyvät tahkot normaali-z:n merkistä.
; VAIHE 3: Piirretään kaaret joiden vähintään yksi viereinen tahko on näkyvä.
; =============================================================================

draw_object_frame:
        ; === VAIHE 0: Esilaskenta — sin/cos X- ja Z-kulmille ===

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
        READ  R15, 0          ; R15 = kärkipiste-indeksi

_dof_vertex_loop:
        READ  R0, [obj_num_vertices]
        CMP   R15, R0
        JGE   _dof_vertex_done

        ; Lataa koordinaatit
        READ  R0, [obj_vx_ptr]
        ADD   R0, R15
        READ  R8, [R0]        ; R8 = vx = ax

        READ  R0, [obj_vy_ptr]
        ADD   R0, R15
        READ  R9, [R0]        ; R9 = vy

        READ  R0, [obj_vz_ptr]
        ADD   R0, R15
        READ  R10, [R0]       ; R10 = vz

        ; --- X-akselin rotaatio ---
        ; ay = (vy·cos_x − vz·sin_x) / 100
        CPY   R0, R9
        READ  R1, [cos_cache_x]
        CALL  smul_div100
        CPY   R11, R0         ; R11 = vy·cos_x/100

        CPY   R0, R10
        READ  R1, [sin_cache_x]
        CALL  smul_div100
        SUB   R11, R0         ; R11 = ay

        ; az = (vy·sin_x + vz·cos_x) / 100
        CPY   R0, R9
        READ  R1, [sin_cache_x]
        CALL  smul_div100
        CPY   R12, R0

        CPY   R0, R10
        READ  R1, [cos_cache_x]
        CALL  smul_div100
        ADD   R12, R0         ; R12 = az

        ; Nyt: R8=ax, R11=ay, R12=az
        CPY   R7, R12         ; R7 = az

        ; Talleta rot_x/y/z piiloviivapoistoa varten
        READ  R0, rot_x
        ADD   R0, R15
        STORE [R0], R8
        READ  R0, rot_y
        ADD   R0, R15
        STORE [R0], R11
        READ  R0, rot_z
        ADD   R0, R15
        STORE [R0], R7

        ; --- Z-akselin rotaatio ---
        ; cx = (ax·cos_z − ay·sin_z) / 100
        CPY   R0, R8
        READ  R1, [cos_cache_z]
        CALL  smul_div100
        CPY   R9, R0

        CPY   R0, R11
        READ  R1, [sin_cache_z]
        CALL  smul_div100
        SUB   R9, R0          ; R9 = cx

        ; cy = (ax·sin_z + ay·cos_z) / 100
        CPY   R0, R8
        READ  R1, [sin_cache_z]
        CALL  smul_div100
        CPY   R10, R0

        CPY   R0, R11
        READ  R1, [cos_cache_z]
        CALL  smul_div100
        ADD   R10, R0         ; R10 = cy

        ; --- Sovella skaalaus ja siirros ---
        READ  R4, 2
        CMP   R14, R4
        JNZ   _dof_mode_b

        ADD   R9, R9
        ADD   R10, R10
        READ  R0, 80
        ADD   R9, R0
        READ  R0, 48
        ADD   R10, R0
        JUMP  _dof_store

_dof_mode_b:
        READ  R0, 40
        ADD   R9, R0
        READ  R0, 24
        ADD   R10, R0

_dof_store:
        READ  R0, proj_x
        ADD   R0, R15
        STORE [R0], R9

        READ  R0, proj_y
        ADD   R0, R15
        STORE [R0], R10

        READ  R0, 1
        ADD   R15, R0
        JUMP  _dof_vertex_loop

_dof_vertex_done:

        ; === VAIHE 2: Laske näkyvät tahkot ===
        READ  R6, 0          ; face_idx
        READ  R7, 0          ; face_table-offset (0,3,6,...)

_dof_face_loop:
        READ  R0, [obj_num_faces]
        CMP   R6, R0
        JGE   _dof_face_done

        ; Lue tahkon kolme kärkipistettä: ia, ib, ic
        READ  R0, [obj_faces_ptr]
        ADD   R0, R7
        READ  R1, [R0]       ; ia
        READ  R5, 1
        ADD   R0, R5
        READ  R2, [R0]       ; ib
        READ  R5, 1
        ADD   R0, R5
        READ  R3, [R0]       ; ic

        ; A = (xa, ya)
        READ  R0, rot_x
        ADD   R0, R1
        READ  R8, [R0]
        READ  R0, rot_y
        ADD   R0, R1
        READ  R9, [R0]

        ; B = (xb, yb)
        READ  R0, rot_x
        ADD   R0, R2
        READ  R10, [R0]
        READ  R0, rot_y
        ADD   R0, R2
        READ  R11, [R0]

        ; C = (xc, yc)
        READ  R0, rot_x
        ADD   R0, R3
        READ  R12, [R0]
        READ  R0, rot_y
        ADD   R0, R3
        READ  R13, [R0]

        ; normal_z = (xb-xa)*(yc-ya) - (yb-ya)*(xc-xa)
        CPY   R0, R10
        SUB   R0, R8         ; dx1
        CPY   R2, R11
        SUB   R2, R9         ; dy1
        CPY   R3, R12
        SUB   R3, R8         ; dx2
        CPY   R4, R13
        SUB   R4, R9         ; dy2

        CPY   R1, R4
        MUL   R0, R1         ; p1 = dx1*dy2
        CPY   R1, R2
        MUL   R1, R3         ; p2 = dy1*dx2
        SUB   R0, R1         ; normal_z

        ; Näkyvä, jos normal_z < 0
        READ  R1, 0
        CMP   R0, R1
        JLT   _dof_face_visible

        READ  R0, face_visible
        ADD   R0, R6
        READ  R1, 0
        STORE [R0], R1
        JUMP  _dof_face_next

_dof_face_visible:
        READ  R0, face_visible
        ADD   R0, R6
        READ  R1, 1
        STORE [R0], R1

_dof_face_next:
        READ  R0, 1
        ADD   R6, R0
        READ  R0, 3
        ADD   R7, R0
        JUMP  _dof_face_loop

_dof_face_done:

        ; === VAIHE 3: Piirrä kaaret joiden ≥1 viereinen tahko on näkyvä ===
        READ  R13, 0          ; R13 = kaaritaulukko-offset
        READ  R15, 0          ; R15 = kaarilaskuri

_dof_edge_loop:
        READ  R0, [obj_num_edges]
        CMP   R15, R0
        JGE   _dof_edge_done

        ; Lue v0 ja v1
        READ  R0, [obj_edges_ptr]
        ADD   R0, R13
        READ  R4, [R0]        ; R4 = v0
        READ  R5, 1
        ADD   R0, R5
        READ  R5, [R0]        ; R5 = v1

        ; Kaari näkyy, jos vähintään yksi viereinen tahko on näkyvä
        CPY   R6, R15
        ADD   R6, R15         ; R6 = edge_idx * 2
        READ  R0, [obj_edge_faces_ptr]
        ADD   R0, R6
        READ  R6, [R0]        ; face_a
        READ  R7, 1
        ADD   R0, R7
        READ  R7, [R0]        ; face_b

        READ  R0, face_visible
        ADD   R0, R6
        READ  R6, [R0]        ; vis_a
        READ  R0, face_visible
        ADD   R0, R7
        READ  R7, [R0]        ; vis_b
        OR    R6, R7
        READ  R0, 0
        CMP   R6, R0
        JZ    _dof_skip_edge

        ; Piirrä viiva
        READ  R0, proj_x
        ADD   R0, R4
        READ  R0, [R0]

        READ  R1, proj_y
        ADD   R1, R4
        READ  R1, [R1]

        READ  R2, proj_x
        ADD   R2, R5
        READ  R2, [R2]

        READ  R3, proj_y
        ADD   R3, R5
        READ  R3, [R3]

        CALL  gfx_line

_dof_skip_edge:
        READ  R0, 2
        ADD   R13, R0
        READ  R0, 1
        ADD   R15, R0
        JUMP  _dof_edge_loop

_dof_edge_done:
        RET

; =============================================================================
; set_object — Aseta aktiivinen objekti osoitinmuuttujiin
;
; Sisään:  R0 = objektin valinta (0=kuutio, 1=L-kirjain, 2=J-kirjain, 3=pyramidi)
; Ulos:    obj_*_ptr ja obj_num_* päivitetty
; Clobbers: R0, R1
; =============================================================================

set_object:
        READ  R1, 1
        CMP   R0, R1
        JZ    _so_letter_L
        READ  R1, 2
        CMP   R0, R1
        JZ    _so_letter_J
        READ  R1, 3
        CMP   R0, R1
        JZ    _so_pyramid

        ; Kuutio (oletus)
        READ  R1, cube_vx
        STORE [obj_vx_ptr], R1
        READ  R1, cube_vy
        STORE [obj_vy_ptr], R1
        READ  R1, cube_vz
        STORE [obj_vz_ptr], R1
        READ  R1, cube_edges
        STORE [obj_edges_ptr], R1
        READ  R1, cube_edge_faces
        STORE [obj_edge_faces_ptr], R1
        READ  R1, cube_faces
        STORE [obj_faces_ptr], R1
        READ  R1, [cube_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [cube_num_edges]
        STORE [obj_num_edges], R1
        READ  R1, [cube_num_faces]
        STORE [obj_num_faces], R1
        RET

_so_letter_L:
        READ  R1, letter_L_vx
        STORE [obj_vx_ptr], R1
        READ  R1, letter_L_vy
        STORE [obj_vy_ptr], R1
        READ  R1, letter_L_vz
        STORE [obj_vz_ptr], R1
        READ  R1, letter_L_edges
        STORE [obj_edges_ptr], R1
        READ  R1, letter_L_edge_faces
        STORE [obj_edge_faces_ptr], R1
        READ  R1, letter_L_faces
        STORE [obj_faces_ptr], R1
        READ  R1, [letter_L_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [letter_L_num_edges]
        STORE [obj_num_edges], R1
        READ  R1, [letter_L_num_faces]
        STORE [obj_num_faces], R1
        RET

_so_letter_J:
        READ  R1, letter_J_vx
        STORE [obj_vx_ptr], R1
        READ  R1, letter_J_vy
        STORE [obj_vy_ptr], R1
        READ  R1, letter_J_vz
        STORE [obj_vz_ptr], R1
        READ  R1, letter_J_edges
        STORE [obj_edges_ptr], R1
        READ  R1, letter_J_edge_faces
        STORE [obj_edge_faces_ptr], R1
        READ  R1, letter_J_faces
        STORE [obj_faces_ptr], R1
        READ  R1, [letter_J_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [letter_J_num_edges]
        STORE [obj_num_edges], R1
        READ  R1, [letter_J_num_faces]
        STORE [obj_num_faces], R1
        RET

_so_pyramid:
        READ  R1, pyramid_vx
        STORE [obj_vx_ptr], R1
        READ  R1, pyramid_vy
        STORE [obj_vy_ptr], R1
        READ  R1, pyramid_vz
        STORE [obj_vz_ptr], R1
        READ  R1, pyramid_edges
        STORE [obj_edges_ptr], R1
        READ  R1, pyramid_edge_faces
        STORE [obj_edge_faces_ptr], R1
        READ  R1, pyramid_faces
        STORE [obj_faces_ptr], R1
        READ  R1, [pyramid_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [pyramid_num_edges]
        STORE [obj_num_edges], R1
        READ  R1, [pyramid_num_faces]
        STORE [obj_num_faces], R1
        RET

; =============================================================================
; main — Pääohjelma
; Sykli: vaihe 0 = kuutio (tila B), vaihe 1 = L (tila C), vaihe 2 = J (tila B), sitten alusta
; =============================================================================

main:
        ; Rekisteröi kellokeskeytyksen käsittelijä (INT 9 -vektori = osoite 9)
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

        ; Salli (laitteisto)keskeytykset
        STI

restart_loop:
        ; Nollaa tilamuuttujat phase..cnt_z
        READ  R0, phase
        READ  R1, cnt_z
        READ  R2, 0
        FILL  R0, R1, R2

        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Käynnistä 10 s ajastin
        READ  R0, 10000
        SCTMR R0

        ; Vaihe 0: kuutio, tila B
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 1

        READ  R0, 0
        CALL  set_object

; --- Tila B / kuutio -piirtosilmukka ---
b_loop:
        CALL  gfx_clear
        CALL  draw_object_frame
        CALL  gfx_flip

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

        READ  R0, [phase]
        READ  R1, 0
        CMP   R0, R1
        JZ    b_loop

        ; Siirry vaiheeseen 1: L-kirjain, tila C
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 2

        READ  R0, 1
        CALL  set_object

; --- Tila C / L-kirjain -piirtosilmukka ---
c_loop:
        CALL  gfx_clear
        CALL  draw_object_frame
        CALL  gfx_flip

        ; Kasvata angle_x
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

        ; Kasvata angle_z
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

        READ  R0, [phase]
        READ  R1, 1
        CMP   R0, R1
        JZ    c_loop

        ; Siirry vaiheeseen 2: J-kirjain, tila B
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 1

        READ  R0, 2
        CALL  set_object

; --- Tila B / J-kirjain -piirtosilmukka ---
d_loop:
        CALL  gfx_clear
        CALL  draw_object_frame
        CALL  gfx_flip

        ; Kasvata angle_x
        READ  R0, [cnt_x]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 3
        CMP   R0, R1
        JNZ   _d_cnt_x_done
        READ  R0, 0
        READ  R1, [angle_x]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _d_ax_no_wrap
        READ  R1, 0
_d_ax_no_wrap:
        STORE [angle_x], R1
_d_cnt_x_done:
        STORE [cnt_x], R0

        ; Kasvata angle_z
        READ  R0, [cnt_z]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 5
        CMP   R0, R1
        JNZ   _d_cnt_z_done
        READ  R0, 0
        READ  R1, [angle_z]
        READ  R2, 1
        ADD   R1, R2
        READ  R2, 64
        CMP   R1, R2
        JNZ   _d_az_no_wrap
        READ  R1, 0
_d_az_no_wrap:
        STORE [angle_z], R1
_d_cnt_z_done:
        STORE [cnt_z], R0

        READ  R0, [phase]
        READ  R1, 2
        CMP   R0, R1
        JZ    d_loop

        ; Vaihe on 3: aloita koko animaatio alusta
        JUMP  restart_loop
