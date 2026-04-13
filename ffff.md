# kCPU16 Refaktorointisuunnitelma

## Tavoite
Tama suunnitelma kuvaa hallitun refaktoroinnin, jolla parannetaan koodirakennetta, modulaarisuutta ja yllapidettavyytta ilman regressioita suorituskykyyn tai toiminnallisuuteen.

## Nykyiset kipupisteet
- `kcpu16/hardware/cpu.py` on suuri ja sisaltaa useita vastuualueita (decode, execute, MMIO, keskeytykset, suorituskykyoptimoinnit).
- TUI-logiikka (`kcpu16/tui.py`) sisaltaa runsaasti tilaa, renderointia ja komentokasittelya samassa luokassa.
- Instruction metadata, assembler-saannot ja execute-handlerit ovat osittain tiukasti sidottuja toisiinsa.
- Testit ovat kattavat, mutta rakenne on paosin yksi tiedosto per ilmiö ilman erillista "test matrix" -dokumentaatiota.

## Refaktoroinnin periaatteet
- Ei toiminnallisia muutoksia ilman erillista tehtavaa.
- Suorituskykypolut pidetaan nopeina (hot path: no extra allocations/calls).
- Jokainen vaihe on pieni, testattava ja palautettavissa.
- Ensin rajapinnat ja tiedostorakenne, sitten sisaiset optimoinnit.

## Vaiheistus

## Toteutusstatus
- [x] Vaihe 1, askel 1: MMIO-metodit eroteltu tiedostoon `kcpu16/hardware/cpu_mmio.py` mixin-rakenteella.
- [x] Vaihe 1, askel 2: Muistitarkistusmetodit eroteltu tiedostoon `kcpu16/hardware/cpu_memcheck.py` mixin-rakenteella.
- [x] Vaihe 1, askel 3: Exec-handlerien erotus tiedostoon `kcpu16/hardware/cpu_exec.py`.
- [x] Vaihe 1, askel 4: Run-loop/decode/facade-siivous (`cpu_core.py` + `cpu.py`).

### Vaihe 1: Rajaa CPU-vastuut pienempiin moduuleihin
Tavoite: pilko `cpu.py` sisallot loogisiin osiin ilman API-muutosta.

Toimenpiteet:
- Luo `kcpu16/hardware/cpu_core.py` (run-loop + dispatch + decode).
- Luo `kcpu16/hardware/cpu_exec.py` (exec-handlerit).
- Luo `kcpu16/hardware/cpu_memcheck.py` (mcheck-handlerit).
- Luo `kcpu16/hardware/cpu_mmio.py` (clock/kbd/rand mmio read/write).
- Jata `cpu.py` facade-luokaksi, joka kokoaa osat.

Validointi:
- `main.py --test-all` pysyy vihreana.
- Suorituskykyvertailu: run-fastpath ei hidastu > 5 %.

### Vaihe 2: Yhtenainen Instruction Definition Layer
Tavoite: yksi totuuden lahde opcodeille, operandityypeille ja syklimalleille.

Toimenpiteet:
- Laajenna `instruction.py` sisaltamaan operandityyppien metadata (esim. reg, addr, imm, reg_range).
- Generoi assemblerin validointisaannot osittain metadatasta.
- Generoi disassemblerin esityssaantoja metadatasta.

Validointi:
- Opcode-taulukon kattavuustesti 100 %.
- Assembler + disassembler roundtrip-smoketest.

### Vaihe 3: TUI:n rakenteellinen pilkkominen
Tavoite: erottaa UI-komponentit, rendererit ja command-handlers.

Toimenpiteet:
- Erottele `tui.py` osiin:
  - `tui_app.py` (App + layout)
  - `tui_commands.py` (command parser + handlers)
  - `tui_render.py` (paneelien paivitys)
  - `tui_state.py` (ajotila + watched files + cachet)
- Pida nykyiset keybindings ja komennot yhteensopivina.

Validointi:
- Manual smoke: load/assemble/run/step/breakpoint/reset.
- Nykyiset testit + 1-2 uutta TUI-integraatioskriptia (jos mahdollinen).

### Vaihe 4: Muistinkasittelyn apikerros
Tavoite: selkea rajapinta memory-operaatioille, joissa on MMIO-sivuvaikutuksia.

Toimenpiteet:
- Dokumentoi ja mahdollisesti erottele read/write paths:
  - pure RAM read/write
  - MMIO-aware read/write
- Varmista etta COPY/FILL/nopeat viipalepolut kayttavat turvallista fallbackia MMIO-alueilla.

Validointi:
- Muistisuojatesti + MMIO-sivuvaikutustestit.

### Vaihe 5: Teknisen velan siivous
Tavoite: poistaa koodista vanhat/paallekkaiset polut.

Toimenpiteet:
- Poista tarpeettomat kommentoidut tai vanhentuneet haarat.
- Yhtenaisyys: nimikaytannot, type hint -tasot, docstring-muoto.
- Korjaa kirjoitusvirheet dokumentaatiosta (`todo.md` ja docs) erillisessa dokumentointitehtavassa.

Validointi:
- Lint/tyyppitarkistus (jos otetaan kayttoon), testit vihreana.

## Ehdotettu hakemistorakenne (tavoitetila)

```
kcpu16/
  hardware/
    cpu.py              # facade
    cpu_core.py
    cpu_exec.py
    cpu_memcheck.py
    cpu_mmio.py
    memory.py
    registers.py
    devices/
  tui/
    tui_app.py
    tui_commands.py
    tui_render.py
    tui_state.py
  assembler/
    parser.py
    macros.py
    emitter.py
  instruction.py
  tests/                # mahdollinen pidemman aikavalin tavoite
```

Huom: Rakenteen muutos voidaan toteuttaa vaiheittain ilman ulkoisen CLI/TUI-API:n muutoksia.

## Riskit ja hallinta
- Riski: suorituskykypolku hidastuu abstrahoinnista.
  - Hallinta: benchmark jokaisen vaiheen jalkeen, rollback-raja 5 %.
- Riski: MMIO-sivuvaikutukset rikkoutuvat moduloinnissa.
  - Hallinta: dedicated MMIO-regressiot ennen/jalkeen.
- Riski: TUI-kayttaytymisen regressiot.
  - Hallinta: smoke-checklist + nopeat integraatiotestit.

## Suoritusjarjestys (prioriteetti)
1. CPU pilkkominen (Vaihe 1)
2. Instruction metadata yhtenaistys (Vaihe 2)
3. TUI pilkkominen (Vaihe 3)
4. Memory API selkeytys (Vaihe 4)
5. Teknisen velan siivous (Vaihe 5)

## Hyvaksyntakriteerit
- Kaikki olemassa olevat testit lapaisevat.
- Opcode-kattavuus pysyy 100 % testiaineistossa.
- Fast-path suorituskyky ei heikkene merkittavasti.
- Koodi on helpommin navigoitava: CPU/TUI per tiedosto pienempi ja selkeampi.
