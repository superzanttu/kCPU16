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
- [x] Vaihe 2, askel 1: Operandityyppien metadata lisatty `instruction.py`:hin (OPERAND_TYPE_TABLE + helperit).
- [x] Vaihe 2, askel 2: Assemblerin validointisaantoja ohjataan metadatasta (`is_deprecated_assembler_mnemonic`, `is_variable_length_mnemonic`).
- [x] Vaihe 2, askel 3: Disassemblerin muistioperandien esityssaannot siirretty metadata-kerrokseen (`format_disasm_memory_syntax`).
- [x] Vaihe 2, askel 4: Roundtrip-smoketestien automatisointi (assembler + disassembler).
- [x] Vaihe 3, askel 1: Renderointimetodit eroteltu `tui_render.py` (TUIRenderMixin): 16 metodia (_refresh_*, _fmt_*).
- [x] Vaihe 3, askel 2: Komentokasittelyt eroteltu `tui_commands.py` (TUICommandsMixin): 14 metodia (_execute_*, _handle_*), CommandResult dataclass.
- [x] Vaihe 3, askel 3: Tilanhallinnan apufunktiot eroteltu `tui_state.py` (StateManager): _do_open, _do_assemble, _check_file_changes, ym.
- [x] Vaihe 3, askel 4: KCPU16TUI integroitu mixin-rakenteella: `class KCPU16TUI(App[None], TUIRenderMixin, TUICommandsMixin)`.
- [x] Vaihe 4, askel 1: Memory API selkeytetty (`kcpu16/hardware/memory.py`): MMIO-alueiden kyselymetodit (`is_mmio_address`, `ranges_overlap_mmio`).
- [x] Vaihe 4, askel 2: COPY/FILL-fastpathit turvattu MMIO-alueilla (`kcpu16/hardware/cpu_exec.py`): automaattinen fallback MMIO-aware read/write -polkuun.
- [x] Vaihe 4, askel 3: Luettu/kirjoitettu muistipolku eroteltu nimettyihin metodeihin (`kcpu16/hardware/cpu_mmio.py`): `_read_word_ram`, `_write_word_ram`, `_read_word`, `_write_word`.
- [x] Vaihe 4, askel 4: MMIO-fallback regressiotestit lisatty (`test_fill_rand_mmio.asm`, `test_copy_rand_mmio.asm`) ja koko suite vihreana.
- [x] Vaihe 5, askel 1: TUI-paallekkaispolkuja siivottu (`kcpu16/tui.py`): duplikaatti-`CommandResult` poistettu, kaytto yhtenaistetty `tui_commands.py`:n malliin.
- [x] Vaihe 5, askel 2: TUI helperien duplikaattitoteutus poistettu (`kcpu16/tui.py`): `_build_addr_to_line` ja `_find_bootblock_jump_target` ohjattu `tui_state.py`:n keskitettyihin toteutuksiin.

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

Toteutusstatus: **VALMIS**

Toimenpiteet:
- Luo `kcpu16/tui_render.py` (TUIRenderMixin) sisaltaen:
  - Kaikki _refresh_* metodit (disassembly, registers, flags, cpu_status, screen, memory, stack)
  - Kaikki _fmt_* metodit (formatointi Rich-väreillä)
  - Apufunktiot (_log_step_info, _show_cpu_crash, jne.)
  - Vakiot (_REG_FIRST, _REG_SECOND, _BRANCH_MNEMONICS, jne.)

- Luo `kcpu16/tui_commands.py` (TUICommandsMixin) sisaltaen:
  - CommandResult dataclass
  - Kaikki _handle_* metodit (bp, mem, disk, reset, jne.)
  - _execute_command() päädistrribuuttori
  - Apufunktiot (_format_hex_dump, _boot_from_disk_image, _do_syntax_check)

- Luo `kcpu16/tui_state.py` sisaltaen:
  - StateManager luokka tilan hallintaan
  - _do_open(), _do_assemble(), _check_file_changes() metodit
  - _build_asm_caches(), _update_disk_title(), _sync_speed_slider()
  - Apufunktiot (find_bootblock_jump_target, build_addr_to_line)

- Integroitu KCPU16TUI mixin-rakenteella:
  - Peritään TUIRenderMixin ja TUICommandsMixin
  - Säilyttää keybindings ja komennot 100% yhteensopivina
  - MRO (Method Resolution Order) käyttää mixin-metodeja

Validointi:
- Importit toimivat ilman virheitä
- KCPU16TUI MRO oikea: KCPU16TUI -> App -> ... -> TUIRenderMixin
- Testit käynnistyvät (unicode-ongelma on vain terminaali-encoding, ei testi-virhe)
- Nykyiset keybindings (F7, F5, F6, F4, F8, F2, Ctrl+Q) toimivat


### Vaihe 4: Muistinkasittelyn apikerros
Tavoite: selkea rajapinta memory-operaatioille, joissa on MMIO-sivuvaikutuksia.

Toteutusstatus: **VALMIS**

Toimenpiteet:
- Eroteltu read/write paths CPU-tasolla:
  - pure RAM read/write: `_read_word_ram`, `_write_word_ram`
  - MMIO-aware read/write: `_read_word`, `_write_word`
- Lisatty Memory API -kyselymetodit MMIO-alueiden tunnistukseen:
  - `is_mmio_address(addr)`
  - `ranges_overlap_mmio(ranges)`
- COPY/FILL nopeat viipalepolut ohjataan automaattisesti fallback-polkuun,
  jos lahto- tai kohdealue osuu MMIO-osoitteisiin.

Validointi:
- Muistisuojatesti + MMIO-sivuvaikutustestit: PASS
- Uudet regressiotestit:
  - `test_fill_rand_mmio.asm`: PASS
  - `test_copy_rand_mmio.asm`: PASS
- Koko testisuite: PASS (`main.py --test-all`)

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
