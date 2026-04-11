; =============================================================================
; demo_3dcube.asm — Pyörivä 3D-objekti grafiikkatilassa B ja C
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
;   Etumerkillinen 16-bittinen kahdenkomplementti läpi koko laskennan.
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
obj_num_vertices:
        .dw  0
obj_num_edges:
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

; =============================================================================
; clock_handler — Kellokeskeytyksen käsittelijä (INT 9)
;
; Kasvattaa demo-vaihetta yhdellä.
; Jos uusi phase < 3, käynnistää 10 sekunnin ajastimen uudelleen.
; Jos uusi phase >= 3, pysäyttää ajastimen (pääsilmukka käynnistää sen).
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
; draw_object_frame — Piirrä yksi animaatiokehys aktiivisesta objektista
;
; Sisään:  R14 = grafiikkatila (1 = tila B, 2 = tila C)
;          angle_x, angle_z muistissa = rotaatiokulmat (0–63)
;          obj_vx_ptr, obj_vy_ptr, obj_vz_ptr = koordinaattitaulut
;          obj_edges_ptr = kaaritaulukko
;          obj_num_vertices, obj_num_edges = koot
; Ulos:    —
; Clobbers: R0–R13, R15   (R14 = tila säilyy)
;
; smul_div100 clobbers R0–R5 → R6–R15 säilyvät sen kutsujen yli.
; gfx_line   clobbers R0–R12 → R13, R14, R15 säilyvät.
;
; VAIHE 0: Esitallennetaan sin/cos X- ja Z-kulmille.
; VAIHE 1: Projisoidaan kärkipisteet — rotaatio järjestyksessä X→Z.
;   Rekisterikartta (säilyvät smul_div100:n yli):
;     R8  = ax=vx, R11 = ay, R9/R10 = scratch
;     R14 = tila (koskematon), R15 = kärkipiste-indeksi (koskematon)
; VAIHE 2: Piirretään kaikki kaaret.
; =============================================================================

draw_object_frame:
        ; === VAIHE 0: Esilaskenta — sin/cos X- ja Z-kulmille ===

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
        READ  R15, 0          ; R15 = kärkipiste-indeksi

_dof_vertex_loop:
        ; Tarkista silmukan loppu
        READ  R0, [obj_num_vertices]
        CMP   R15, R0
        JGE   _dof_vertex_done

        ; Lataa vx[R15]
        READ  R0, [obj_vx_ptr]
        ADD   R0, R15
        READ  R8, [R0]        ; R8 = vx = ax

        ; Lataa vy[R15]
        READ  R0, [obj_vy_ptr]
        ADD   R0, R15
        READ  R9, [R0]        ; R9 = vy

        ; Lataa vz[R15]
        READ  R0, [obj_vz_ptr]
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

        ; Nyt: R8=ax, R11=ay

        ; --- Z-akselin rotaatio ---
        ; cx = (ax·cos_z − ay·sin_z) / 100
        CPY   R0, R8
        READ  R1, [cos_cache_z]
        CALL  smul_div100     ; R0 = ax·cos_z/100
        CPY   R9, R0

        CPY   R0, R11
        READ  R1, [sin_cache_z]
        CALL  smul_div100     ; R0 = ay·sin_z/100
        SUB   R9, R0          ; R9 = cx

        ; cy = (ax·sin_z + ay·cos_z) / 100
        CPY   R0, R8
        READ  R1, [sin_cache_z]
        CALL  smul_div100     ; R0 = ax·sin_z/100
        CPY   R10, R0

        CPY   R0, R11
        READ  R1, [cos_cache_z]
        CALL  smul_div100     ; R0 = ay·cos_z/100
        ADD   R10, R0         ; R10 = cy

        ; Nyt: R9=cx (projisoitu X), R10=cy (projisoitu Y)

        ; --- Sovella skaalaus ja siirros tilan mukaan ---
        READ  R4, 2
        CMP   R14, R4
        JNZ   _dof_mode_b

        ; Tila C: skaalaa ×2, keskipiste (80, 48)
        ADD   R9, R9          ; cx × 2
        ADD   R10, R10        ; cy × 2
        READ  R0, 80
        ADD   R9, R0
        READ  R0, 48
        ADD   R10, R0
        JUMP  _dof_store

_dof_mode_b:
        ; Tila B: suoraan, keskipiste (40, 24)
        READ  R0, 40
        ADD   R9, R0
        READ  R0, 24
        ADD   R10, R0

_dof_store:
        ; Tallenna proj_x[R15] ja proj_y[R15]
        READ  R0, proj_x
        ADD   R0, R15
        STORE [R0], R9

        READ  R0, proj_y
        ADD   R0, R15
        STORE [R0], R10

        ; Seuraava kärkipiste
        READ  R0, 1
        ADD   R15, R0
        JUMP  _dof_vertex_loop

_dof_vertex_done:

        ; === VAIHE 2: Piirrä kaaret ===
        ; gfx_line clobbers R0–R12, mutta R13 ja R15 pysyvät!
        READ  R13, 0          ; R13 = kaaritaulukko-offset (sanatasolla)
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

        ; proj_x[v0]
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

        READ  R0, 2
        ADD   R13, R0         ; R13 += 2  (kaksi sanaa per kaari)
        READ  R0, 1
        ADD   R15, R0
        JUMP  _dof_edge_loop

_dof_edge_done:
        RET

; =============================================================================
; set_object — Aseta aktiivinen objekti osoitinmuuttujiin
;
; Sisään:  R0 = objektin valinta (0=kuutio, 1=L-kirjain, 2=J-kirjain)
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
        READ  R1, [cube_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [cube_num_edges]
        STORE [obj_num_edges], R1
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
        READ  R1, [letter_L_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [letter_L_num_edges]
        STORE [obj_num_edges], R1
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
        READ  R1, [letter_J_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [letter_J_num_edges]
        STORE [obj_num_edges], R1
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
        READ  R1, [pyramid_num_vertices]
        STORE [obj_num_vertices], R1
        READ  R1, [pyramid_num_edges]
        STORE [obj_num_edges], R1
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
        ; Nollaa tilamuuttujat phase..cnt_z yhtenä alueena (FILL: inklusiiviinen)
        READ  R0, phase
        READ  R1, cnt_z
        READ  R2, 0
        FILL  R0, R1, R2

        ; Aseta piirtotila: etuväri (pikselit piirretään päälle, ei XOR)
        READ  R0, GFX_DRAW_FG
        CALL  gfx_set_draw_mode

        ; Käynnistä 10 sekunnin kellokeskeytys
        READ  R0, 10000
        SCTMR R0

        ; Vaihe 0: kuutio, tila B
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 1          ; R14 = 1 (tila B)

        READ  R0, 0
        CALL  set_object

; --- Tila B / kuutio -piirtosilmukka ---
b_loop:
        CALL  gfx_clear
        CALL  draw_object_frame

        ; Kehys valmis — flipaa kaksoisbufferointi
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

        ; Tarkista vaihe — jos edelleen 0, jatka tila B:tä
        READ  R0, [phase]
        READ  R1, 0
        CMP   R0, R1
        JZ    b_loop

        ; Vaihe muuttui: siirry vaiheeseen 1 (L-kirjain, tila C)
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 2          ; R14 = 2 (tila C)

        READ  R0, 1
        CALL  set_object

; --- Tila C / L-kirjain -piirtosilmukka ---
c_loop:
        CALL  gfx_clear
        CALL  draw_object_frame

        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip

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

        ; Vaihe muuttui: siirry vaiheeseen 2 (J-kirjain, tila B)
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        READ  R14, 1          ; R14 = 1 (tila B)

        READ  R0, 2
        CALL  set_object

; --- Tila B / J-kirjain -piirtosilmukka ---
d_loop:
        CALL  gfx_clear
        CALL  draw_object_frame

        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip

        ; Kasvata angle_x (joka 3. kehys)
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

        ; Kasvata angle_z (joka 5. kehys)
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

        ; Tarkista vaihe — jos edelleen 2, jatka tila B:tä
        READ  R0, [phase]
        READ  R1, 2
        CMP   R0, R1
        JZ    d_loop

        ; Vaihe on 3: aloita koko animaatio alusta
        JUMP  restart_loop
