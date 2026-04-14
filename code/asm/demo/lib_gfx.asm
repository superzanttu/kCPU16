; =============================================================================
; demo_lib_gfx.asm — lib-gfx.asm kirjaston demonstraatio
; =============================================================================
;
; KUVAUS:
;   Demonstroi lib-gfx.asm kirjaston kolmea toimintoa (gfx_clear, gfx_pixel,
;   gfx_line) molemmissa grafiikkatilassa B ja C.
;
;   Vaihe 1 (~3 s): Tila B — 80 × 48 pikseliä (puoliblokkipikseli)
;     • Tyhjennys (gfx_clear)
;     • Reunus — 4 viivaa (gfx_line)
;     • X-kuvio — 2 diagonaalia (gfx_line)
;     • Ristikko — vaaka- ja pystyviiva (gfx_line)
;     • Yksittäinen pikseli näytön keskelle (gfx_pixel)
;
;   Vaihe 2 (~3 s): Tila C — 160 × 96 pikseliä (braille)
;     • Tyhjennys (gfx_clear)
;     • Reunus — 4 viivaa (gfx_line)
;     • X-kuvio — 2 diagonaalia (gfx_line)
;     • Ristikko — vaaka- ja pystyviiva (gfx_line)
;     • Yksittäinen pikseli näytön keskelle (gfx_pixel)
;
;   Toistetaan ikuisesti (ei lopu itsestään).
;
; KÄYTTÖ:
;   python main.py --run kcpu16/code/demo_lib_gfx.asm
;   (tai TUI:ssa interaktiivisesti)
;
; KESKEYTYKSET:
;   INT 9 (kellokeskeytys, 3 s välein) — vaihtaa demo-vaihetta.
;   Käsittelijä tallentaa ja palauttaa R0 ja R1.
;
; REKISTERIEN KÄYTTÖ:
;   gfx_* -funktiot käyttävät R0–R12.
;   main: R0, R1 (lue phase ja vertailu)
;   draw_mode_b / draw_mode_c: R0–R3 per gfx_line-kutsu.
;
; =============================================================================

        .origin 0x0200

        JUMP  main

; =============================================================================
; Kirjasto
; =============================================================================

        .include "../lib/lib-gfx.asm"

; =============================================================================
; Data
; =============================================================================

; Demo-vaihe (pyörii ikuisesti):
;   0 = tila B näkyvissä (odota ajastin)
;   1 = tila C näkyvissä (odota ajastin)
phase:
        .db 0

; =============================================================================
; clock_handler — Kellokeskeytyksen käsittelijä (INT 9)
;
; Pyörittää demo-vaihetta modulo 2 (0→1→0→...) ja käynnistää
; 3 s ajastimen aina uudelleen (ikuinen looppi).
;
; Vaatii: Kernel-tila (INT:n kautta automaattisesti).
; Clobbers: R0, R1 (tallennetaan pinoon ja palautetaan ennen IRET:ä).
; =============================================================================

clock_handler:
        PUSH  R0
        PUSH  R1

        ; phase = (phase + 1) % 2
        READ  R0, [phase]
        READ  R1, 1
        ADD   R0, R1
        READ  R1, 2
        CMP   R0, R1
        JLT   _ch_store
        READ  R0, 0
_ch_store:
        STORE [phase], R0

        ; Käynnistä 3 s ajastin uudelleen (ikuinen looppi)
        READ  R0, 3000
        SCTMR R0

        POP   R1
        POP   R0
        IRET

; =============================================================================
; draw_mode_b — Piirrä tila B -demo (80 × 48 pikseliä)
;
; Kytke tila B, tyhjennä näyttö, piirrä reunus, X-kuvio, ristikko
; ja yksittäinen pikseli näytön keskelle.
;
; Clobbers: R0–R12 (gfx_* -funktioiden kautta)
; =============================================================================

draw_mode_b:
        ; Kytke tila B
        READ  R0, GFX_MODE_B
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        ; Tyhjennä näyttö
        CALL  gfx_clear

        ; ------------------------------------------------------------------
        ; Reunus (4 viivaa)
        ; ------------------------------------------------------------------

        ; Yläreuna: (0, 0) → (79, 0)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 79
        READ  R3, 0
        CALL  gfx_line

        ; Alareuna: (0, 47) → (79, 47)
        READ  R0, 0
        READ  R1, 47
        READ  R2, 79
        READ  R3, 47
        CALL  gfx_line

        ; Vasen reuna: (0, 0) → (0, 47)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 0
        READ  R3, 47
        CALL  gfx_line

        ; Oikea reuna: (79, 0) → (79, 47)
        READ  R0, 79
        READ  R1, 0
        READ  R2, 79
        READ  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; X-kuvio (2 diagonaalia)
        ; ------------------------------------------------------------------

        ; Vasen yläkulma → oikea alakulma: (0, 0) → (79, 47)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 79
        READ  R3, 47
        CALL  gfx_line

        ; Oikea yläkulma → vasen alakulma: (79, 0) → (0, 47)
        READ  R0, 79
        READ  R1, 0
        READ  R2, 0
        READ  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Ristikko (vaaka + pysty)
        ; ------------------------------------------------------------------

        ; Vaakaviiva keskellä: (0, 24) → (79, 24)
        READ  R0, 0
        READ  R1, 24
        READ  R2, 79
        READ  R3, 24
        CALL  gfx_line

        ; Pystyviiva keskellä: (40, 0) → (40, 47)
        READ  R0, 40
        READ  R1, 0
        READ  R2, 40
        READ  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Yksittäinen pikseli näytön keskelle: (40, 24)
        ; ------------------------------------------------------------------
        READ  R0, 40
        READ  R1, 24
        CALL  gfx_pixel
        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip
        RET

; =============================================================================
; draw_mode_c — Piirrä tila C -demo (160 × 96 pikseliä)
;
; Kytke tila C, tyhjennä näyttö, piirrä reunus, X-kuvio, ristikko
; ja yksittäinen pikseli näytön keskelle.
;
; Clobbers: R0–R12 (gfx_* -funktioiden kautta)
; =============================================================================

draw_mode_c:
        ; Kytke tila C
        READ  R0, GFX_MODE_C
        READ  R1, GFX_MODE_REG
        STORE [R1], R0

        ; Tyhjennä näyttö
        CALL  gfx_clear

        ; ------------------------------------------------------------------
        ; Reunus (4 viivaa)
        ; ------------------------------------------------------------------

        ; Yläreuna: (0, 0) → (159, 0)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 159
        READ  R3, 0
        CALL  gfx_line

        ; Alareuna: (0, 95) → (159, 95)
        READ  R0, 0
        READ  R1, 95
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line

        ; Vasen reuna: (0, 0) → (0, 95)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 0
        READ  R3, 95
        CALL  gfx_line

        ; Oikea reuna: (159, 0) → (159, 95)
        READ  R0, 159
        READ  R1, 0
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; X-kuvio (2 diagonaalia)
        ; ------------------------------------------------------------------

        ; Vasen yläkulma → oikea alakulma: (0, 0) → (159, 95)
        READ  R0, 0
        READ  R1, 0
        READ  R2, 159
        READ  R3, 95
        CALL  gfx_line

        ; Oikea yläkulma → vasen alakulma: (159, 0) → (0, 95)
        READ  R0, 159
        READ  R1, 0
        READ  R2, 0
        READ  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Ristikko (vaaka + pysty)
        ; ------------------------------------------------------------------

        ; Vaakaviiva keskellä: (0, 48) → (159, 48)
        READ  R0, 0
        READ  R1, 48
        READ  R2, 159
        READ  R3, 48
        CALL  gfx_line

        ; Pystyviiva keskellä: (80, 0) → (80, 95)
        READ  R0, 80
        READ  R1, 0
        READ  R2, 80
        READ  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Yksittäinen pikseli näytön keskelle: (80, 48)
        ; Tilan C resoluutio on 160×96 (x: 0–159, y: 0–95).
        ; Koordinaatti (80, 48) on lähinnä geometrista keskipistettä.
        ; ------------------------------------------------------------------
        READ  R0, 80
        READ  R1, 48
        CALL  gfx_pixel

        ; Kehys valmis — flipaa kaksoisbufferointi
        CALL  gfx_flip

        RET

; =============================================================================
; main — Pääohjelma
; =============================================================================

main:
        ; Rekisteröi kellokeskeytyksen käsittelijä (INT 9 -vektori osoitteessa $0009)
        ; INT_CLOCK = 9 on assembler-arkkitehtuurivakio (ARCH_SYMBOLS); kirjoitetaan
        ; suoraan vektoritaulukkoon muistiosoitteeseen [INT_CLOCK] = [9] = $0009.
        READ  R0, clock_handler
        STORE [INT_CLOCK], R0

loop_forever:
        ; Piirrä tila B -kuvio
        CALL  draw_mode_b

        ; Käynnistä 3 sekunnin kellokeskeytys (vain ensimmäisellä kierroksella;
        ; clock_handler käynnistää ajastimen aina uudelleen)
        READ  R0, 3000
        SCTMR R0

        ; Salli keskeytykset
        STI

; Odota kunnes phase 0 → 1 (kellokeskeytys laukeaa)
wait_phase_1:
        READ  R0, [phase]
        READ  R1, 0
        CMP   R0, R1
        JZ    wait_phase_1

        ; Piirrä tila C -kuvio
        CALL  draw_mode_c

; Odota kunnes phase 1 → 0 (toinen kellokeskeytys laukeaa) ja hyppää takaisin
wait_phase_0:
        READ  R0, [phase]
        READ  R1, 0
        CMP   R0, R1
        JNZ   wait_phase_0

        JUMP  loop_forever
