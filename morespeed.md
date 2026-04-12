# Simulointinopeuden pullonkaulat ja nopeutusehdotukset

## Yhteenveto

Suurimmat pullonkaulat löytyvät CPU:n hot-loopista (`kcpu16/hardware/cpu.py`) ja TUI-ajotavasta (`kcpu16/tui.py`), jossa "fast/max"-tila ajaa edelleen `step()`-kutsulla käsky kerrallaan. Tämä estää jo tehdyn `CPU.run()`-optimoinnin täyden hyödyn.

## Havaitut pullonkaulat

1. **TUI fast/max käyttää `machine.step()`-silmukkaa**
   - Tiedosto: `kcpu16/tui.py` (noin rivit 2092–2115)
   - Vaikutus: jokainen käsky kulkee raskaamman `step()`-polun kautta eikä käytä `CPU.run()` fast-pathia.

2. **CPU hot-loop allokoi paljon pieniä olioita/listoja per käsky**
   - Tiedosto: `kcpu16/hardware/cpu.py` (`run`, noin rivit 462–486)
   - Vaikutus: `_Ins` + operandilistat rakennetaan joka kierroksella.

3. **Useita sanakirja-hakuja per käsky (`exec_table`, `cycles_table`, `mem_check_table`)**
   - Tiedosto: `kcpu16/hardware/cpu.py` (`run`)
   - Vaikutus: toistuva dict-haku näkyy pitkissä ajoissa.

4. **Lippujen päivitys tekee paljon pieniä metodikutsuja**
   - Tiedosto: `kcpu16/hardware/registers.py` (`set_zn_flags`, `set_carry_overflow`, `set_flag`)
   - Vaikutus: aritmeettisissä käskyissä ylimääräistä Python-kutsukustannusta.

5. **Keskeytystarkistuksia tehdään joka käskyllä**
   - Tiedosto: `kcpu16/hardware/cpu.py` (`run`/`step`, timer/clock/keyboard check)
   - Vaikutus: overhead kasvaa vaikka keskeytykset ovat usein pois.

6. **VRAM-renderöinti on kallis kun se tehdään usein**
   - Tiedosto: `kcpu16/hardware/devices/screen.py` (`render_with_rich_colors`)
   - Vaikutus: per-merkki merkkijonorakennus/tagitus on raskasta.

7. **`_mcheck_fill` käyttää viipaleita + `any()` laajoille alueille**
   - Tiedosto: `kcpu16/hardware/cpu.py` (`_mcheck_fill`)
   - Vaikutus: suuriin FILL-alueisiin ylimääräistä läpikäynti- ja allokointikustannusta.

## Ehdotetut tehtävät (priorisoitu)

### P1 — Suurin vaikutus nopeasti

- [ ] Muuta TUI:n fast/max-ajotapa käyttämään `CPU.run(max_cycles=batch)` eikä sisäistä `step()`-for-silmukkaa.
- [ ] Lisää breakpoint-rajattu ajotapa CPU-tasolle (esim. "run until breakpoint or cycles"), jotta TUI voi käyttää fast-pathia myös breakpointeilla.
- [ ] Vähennä hot-loopin allokaatioita (operandit kiinteänä tuple-rakenteena tai erilliset 0/1/2/3 operandin kevyet polut ilman listaluontia).

### P2 — Keskisuuri vaikutus

- [ ] Korvaa opcode-dict-haut nopeammalla rakenteella (esim. taulukko/lista opcode-indeksillä, `None` tuntemattomille).
- [ ] Inline-optimoi yleisimpien käskyjen lippupäivitykset (välttää useita `set_flag`-kutsuja per käsky).
- [ ] Lisää "interrupt fast gate": jos I=0 ja ajastimet pois eikä keyboard pending, ohita keskeytyscheckit yhdellä ehdolla.

### P3 — Täydentävät optimoinnit

- [ ] Optimoi FILL-muistitarkistus ilman suuria viipalekopioita.
- [ ] Tee renderöintiin kevyt "text-only fast mode" ja aggressiivisempi dirty-region-päivitys.
- [ ] Vähennä `datetime.now()`-kutsuja kellon MMIO-luvuissa (snapshot per käsky tai per lukujakso).

## Ehdotettu toteutusjärjestys

1. TUI fast/max → `CPU.run` (iso käytännön nopeushyöty heti)
2. CPU hot-loop allokaatioiden vähennys
3. Opcode-dispatchin taulukkorakenne
4. Lippu- ja keskeytyscheckien mikro-optimoinnit
5. Renderöinnin ja FILL-tarkistuksen jatko-optimoinnit

## Validointi

- Aja regressiot: `python main.py --test-all`
- Vertaa ennen/jälkeen benchmarkia ainakin:
  - puhdas CPU-looppi (ei VRAM-kirjoituksia)
  - VRAM-painotteinen kuormitus
  - interrupt-painotteinen kuormitus
