# kCPU16 emulaation suorituskyky – analyysi ja parannusehdotukset

Tämä analyysi perustuu nykyiseen toteutukseen tiedostoissa:
- `/home/runner/work/kCPU16/kCPU16/kcpu16/hardware/cpu_core.py`
- `/home/runner/work/kCPU16/kCPU16/kcpu16/hardware/cpu_exec.py`
- `/home/runner/work/kCPU16/kCPU16/kcpu16/hardware/cpu_memcheck.py`
- `/home/runner/work/kCPU16/kCPU16/kcpu16/hardware/cpu_mmio.py`
- `/home/runner/work/kCPU16/kCPU16/kcpu16/hardware/devices/screen.py`

## 1) Poista per-käsky `_Ins`-olioallokaatio hot loopista

**Muutoksen tarve**  
`CPUCoreMixin._run_core()` rakentaa lähes jokaisella kierroksella uuden `_Ins`-olion ja operandi-tuplen. Tämä allokoi paljon pieniä Python-olioita, mikä nostaa GC- ja tulkkioverheadia.

**Ehdotus**  
Käytä hot-loopissa kevyttä, allokoimatonta esitystä (esim. paikalliset `opcode/op1/op2/op3/size`) ja erillistä hitaampaa polkua vain JMPI/CALLI-käskyille.

**Vaikutus**  
Suora IPS-parannus CPU-intensiivisissä ajoissa, koska jokaisen käskyn peruskustannus pienenee.

---

## 2) Ota käyttöön valinnainen trace-historia (debug-only)

**Muutoksen tarve**  
`_run_core()` tekee aina `self._recent_exec_trace.append(...)` jokaisella käskyllä, vaikka crash-tracea ei tarvittaisi.

**Ehdotus**  
Lisää lippu (esim. `trace_enabled`) ja ohita append normaalissa fast/max-ajossa.

**Vaikutus**  
Vähemmän dequen käsittelyä hot-pathissa; nopeushyöty korostuu pitkässä jatkuvassa ajossa.

---

## 3) Harvenna keskeytysten käsittelykutsuja

**Muutoksen tarve**  
`_run_core()` tarkistaa jokaisella käskyllä keskeytyslipun ja voi kutsua jopa kolmea erillistä tarkistusmetodia (`keyboard/timer/clock`).

**Ehdotus**  
Pidä paikallinen “next interrupt deadline” -arvo ja tarkista yksityiskohtaiset keskeytysfunktiot vasta kun deadline on saavutettu tai kun näppäimistöllä on pending-tila.

**Vaikutus**  
Pienempi per-käsky overhead tilanteissa, joissa keskeytykset ovat harvinaisia (yleisin tapaus).

---

## 4) Vähennä FILL/COPY:n väliaikaisia listoja isoissa siirroissa

**Muutoksen tarve**  
`_exec_fill()` ja `_exec_copy()` käyttävät fast-pathissa listarakennusta (`[val] * n`, `src_data.extend(...)`). Suurilla alueilla tämä kasvattaa muistiliikennettä.

**Ehdotus**  
Optimoi tapaukset erikseen:
- suora yhden segmentin kopiointi ilman wrapia
- ei-päällekkäinen COPY ilman väliaikaista koko lähdelistaa
- fallback nykyiseen turvalliseen polkuun vain kun wrap/overlap/MMIO vaatii

**Vaikutus**  
Nopeampi muistiblokkien käsittely RAM-painotteisissa workloadissa ja pienempi hetkellinen muistipiikki.

---

## 5) Tee RAM-painotteisille käskyille erillinen “no-MMIO” pikapolku

**Muutoksen tarve**  
`_read_word/_write_word` sisältävät MMIO-haaraketjun jokaiselle luku- ja kirjoitusoperaatiolle. Tavallisissa RAM-osoitteissa nämä tarkistukset ovat turhaa overheadia.

**Ehdotus**  
Dekoodausvaiheessa/handlerissa tunnista “varmasti RAM” -tapaukset ja käytä suoraa `memory.words[...]` polkua, kun osoite ei voi osua MMIO-alueelle.

**Vaikutus**  
STORE/READ-tyyppisten käskyjen nopeutus erityisesti benchmarkeissa, joissa MMIO:ta ei käytetä.

---

## 6) Nopeuta näytön renderöintiä hyödyntämällä dirty-spania laajemmin

**Muutoksen tarve**  
`ScreenDevice` ylläpitää `_dirty_min/_dirty_max`, mutta renderöinti (`render_with_rich_colors`, `render_mode_b`, `render_mode_c`) käy edelleen koko ruudun läpi.

**Ehdotus**  
Renderöi vain muuttunut rivi-/sarakealue ja säilytä valmiiksi rakennettuja rivibuffereita.

**Vaikutus**  
Selvä UI-nopeutus VRAM-kirjoituksissa, joissa muuttuu vain pieni osa ruudusta.

---

## 7) Vähennä toistuvia `memory.read()`-kutsuja renderöinnissä

**Muutoksen tarve**  
Renderöinti kutsuu `memory.read(addr)` jokaiselle solulle. Se tekee aina maskauksen ja metodikutsun, vaikka VRAM on tavallista muistia.

**Ehdotus**  
Lue VRAM suoraan `memory.words`-taulukosta lineaarisena viipaleena renderöinnin alussa.

**Vaikutus**  
Pienempi Python-kutsukustannus per ruutu, mikä parantaa FPS:ää etenkin max/fast-tiloissa.

---

## Priorisointi (suurin käytännön hyöty ensin)

1. `_Ins`-allokaation poisto hot-loopista  
2. Trace append debug-only -tilaan  
3. Keskeytyskutsujen harvennus  
4. RAM no-MMIO pikapolut  
5. FILL/COPY väliaikaisallokaatioiden vähennys  
6. Renderöinnin dirty-span optimointi  
7. VRAM-suoraluku renderöinnissä

