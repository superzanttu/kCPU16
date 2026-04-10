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
;   Lopuksi: tekstitila A palautetaan ja ohjelma päättyy.
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

        .include "lib-gfx.asm"

; =============================================================================
; Data
; =============================================================================

; Demo-vaihe:
;   0 = tila B näkyvissä (odota ajastin)
;   1 = tila C näkyvissä (odota ajastin)
;   2 = valmis
phase:
        .db 0

; =============================================================================
; clock_handler — Kellokeskeytyksen käsittelijä (INT 9)
;
; Kasvattaa demo-vaihetta yhdellä.
; Jos uusi phase < 2, käynnistää 3 s ajastimen uudelleen.
; Jos uusi phase == 2, pysäyttää ajastimen.
;
; Vaatii: Kernel-tila (INT:n kautta automaattisesti).
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

        ; phase < 2: käynnistä 3 s ajastin uudelleen
        LOAD  R0, 3000
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
; draw_mode_b — Piirrä tila B -demo (80 × 48 pikseliä)
;
; Kytke tila B, tyhjennä näyttö, piirrä reunus, X-kuvio, ristikko
; ja yksittäinen pikseli näytön keskelle.
;
; Clobbers: R0–R12 (gfx_* -funktioiden kautta)
; =============================================================================

draw_mode_b:
        ; Kytke tila B
        LOAD  R0, GFX_MODE_B
        LOAD  R1, GFX_MODE_REG
        STORE [R1], R0

        ; Tyhjennä näyttö
        CALL  gfx_clear

        ; ------------------------------------------------------------------
        ; Reunus (4 viivaa)
        ; ------------------------------------------------------------------

        ; Yläreuna: (0, 0) → (79, 0)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 79
        LOAD  R3, 0
        CALL  gfx_line

        ; Alareuna: (0, 47) → (79, 47)
        LOAD  R0, 0
        LOAD  R1, 47
        LOAD  R2, 79
        LOAD  R3, 47
        CALL  gfx_line

        ; Vasen reuna: (0, 0) → (0, 47)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 0
        LOAD  R3, 47
        CALL  gfx_line

        ; Oikea reuna: (79, 0) → (79, 47)
        LOAD  R0, 79
        LOAD  R1, 0
        LOAD  R2, 79
        LOAD  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; X-kuvio (2 diagonaalia)
        ; ------------------------------------------------------------------

        ; Vasen yläkulma → oikea alakulma: (0, 0) → (79, 47)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 79
        LOAD  R3, 47
        CALL  gfx_line

        ; Oikea yläkulma → vasen alakulma: (79, 0) → (0, 47)
        LOAD  R0, 79
        LOAD  R1, 0
        LOAD  R2, 0
        LOAD  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Ristikko (vaaka + pysty)
        ; ------------------------------------------------------------------

        ; Vaakaviiva keskellä: (0, 24) → (79, 24)
        LOAD  R0, 0
        LOAD  R1, 24
        LOAD  R2, 79
        LOAD  R3, 24
        CALL  gfx_line

        ; Pystyviiva keskellä: (40, 0) → (40, 47)
        LOAD  R0, 40
        LOAD  R1, 0
        LOAD  R2, 40
        LOAD  R3, 47
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Yksittäinen pikseli näytön keskelle: (40, 24)
        ; ------------------------------------------------------------------
        LOAD  R0, 40
        LOAD  R1, 24
        CALL  gfx_pixel

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
        LOAD  R0, GFX_MODE_C
        LOAD  R1, GFX_MODE_REG
        STORE [R1], R0

        ; Tyhjennä näyttö
        CALL  gfx_clear

        ; ------------------------------------------------------------------
        ; Reunus (4 viivaa)
        ; ------------------------------------------------------------------

        ; Yläreuna: (0, 0) → (159, 0)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 159
        LOAD  R3, 0
        CALL  gfx_line

        ; Alareuna: (0, 95) → (159, 95)
        LOAD  R0, 0
        LOAD  R1, 95
        LOAD  R2, 159
        LOAD  R3, 95
        CALL  gfx_line

        ; Vasen reuna: (0, 0) → (0, 95)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 0
        LOAD  R3, 95
        CALL  gfx_line

        ; Oikea reuna: (159, 0) → (159, 95)
        LOAD  R0, 159
        LOAD  R1, 0
        LOAD  R2, 159
        LOAD  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; X-kuvio (2 diagonaalia)
        ; ------------------------------------------------------------------

        ; Vasen yläkulma → oikea alakulma: (0, 0) → (159, 95)
        LOAD  R0, 0
        LOAD  R1, 0
        LOAD  R2, 159
        LOAD  R3, 95
        CALL  gfx_line

        ; Oikea yläkulma → vasen alakulma: (159, 0) → (0, 95)
        LOAD  R0, 159
        LOAD  R1, 0
        LOAD  R2, 0
        LOAD  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Ristikko (vaaka + pysty)
        ; ------------------------------------------------------------------

        ; Vaakaviiva keskellä: (0, 48) → (159, 48)
        LOAD  R0, 0
        LOAD  R1, 48
        LOAD  R2, 159
        LOAD  R3, 48
        CALL  gfx_line

        ; Pystyviiva keskellä: (80, 0) → (80, 95)
        LOAD  R0, 80
        LOAD  R1, 0
        LOAD  R2, 80
        LOAD  R3, 95
        CALL  gfx_line

        ; ------------------------------------------------------------------
        ; Yksittäinen pikseli näytön keskelle: (80, 48)
        ; Tilan C resoluutio on 160×96 (x: 0–159, y: 0–95).
        ; Koordinaatti (80, 48) on lähinnä geometrista keskipistettä.
        ; ------------------------------------------------------------------
        LOAD  R0, 80
        LOAD  R1, 48
        CALL  gfx_pixel

        RET

; =============================================================================
; main — Pääohjelma
; =============================================================================

main:
        ; Rekisteröi kellokeskeytyksen käsittelijä (INT 9 -vektori osoitteessa $0009)
        ; INT_CLOCK = 9 on assembler-arkkitehtuurivakio (ARCH_SYMBOLS); kirjoitetaan
        ; suoraan vektoritaulukkoon muistiosoitteeseen [INT_CLOCK] = [9] = $0009.
        LOAD  R0, clock_handler
        STORE [INT_CLOCK], R0

        ; Piirrä tila B -kuvio
        CALL  draw_mode_b

        ; Käynnistä 3 sekunnin kellokeskeytys
        LOAD  R0, 3000
        SCTMR R0

        ; Salli keskeytykset
        STI

; Odota kunnes phase 0 → 1 (kellokeskeytys laukeaa)
wait_phase_1:
        LOAD  R0, [phase]
        LOAD  R1, 0
        CMP   R0, R1
        JZ    wait_phase_1

        ; Piirrä tila C -kuvio
        CALL  draw_mode_c

; Odota kunnes phase 1 → 2 (toinen kellokeskeytys laukeaa)
wait_phase_2:
        LOAD  R0, [phase]
        LOAD  R1, 1
        CMP   R0, R1
        JZ    wait_phase_2

        ; Palauta tekstitila A
        LOAD  R0, 0
        LOAD  R1, GFX_MODE_REG
        STORE [R1], R0

        EXIT
