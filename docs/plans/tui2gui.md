# kCPU16 – Suunnitelma TUI:sta GUI:hin siirtymiseksi

Versio 1.0

Tämä dokumentti kuvaa suunnitelman kCPU16-emulaattorin käyttöliittymän muuttamiseksi Textual-pohjaisesta TUI:sta (Text User Interface) graafiseksi GUI-sovellukseksi (Graphical User Interface). Koska lopullisesta GUI-kirjastosta ei ole tehty päätöstä, suunnitelma painottaa koodin rakenteen muokkaamista kirjastoriippumattomaksi ennen varsinaisen GUI-kirjaston valintaa.

---

## 1. Nykytilan analyysi

### 1.1 Nykyinen arkkitehtuuri

Projektin ydintoiminnallisuus on jo hyvin eriytetty omiin moduuleihinsa:

| Moduuli | Vastuualue | Kirjastoriippuvuudet |
|---|---|---|
| `machine.py` | Virtuaalikoneen korkean tason rajapinta | Ei |
| `cpu.py` | Fetch-Decode-Execute-ydin | Ei |
| `memory.py` | 64 K sanan muisti | Ei |
| `registers.py` | Rekisteritiedosto | Ei |
| `assembler.py` | Assembly → konekieli | Ei |
| `disassembler.py` | Konekieli → assembly | Ei |
| `debugger.py` | Breakpointit, rekisterimuutosten seuranta | Ei |
| `devices/` | Näyttö, näppäimistö, tallennuslaite | Ei |
| `editor.py` | `AssemblySyntaxHighlighter` (Rich-markup), `SimpleEditor` | Rich (markup-merkkijonot) |
| `tui.py` | Koko käyttöliittymä | **Textual, Rich** |

### 1.2 Ongelmat GUI-migraation näkökulmasta

1. **`tui.py` on monoliitti** – tiedosto sisältää sekaisin UI-asettelun (Textual-widgetit), tapahtumasidonnaisuudet, komentotulkin logiikan (`_execute_command`) ja apufunktioita (`_build_addr_to_line`). Kaikki nämä ovat vahvasti sidottuja Textual-APIin.

2. **`AssemblySyntaxHighlighter` tuottaa Rich-markup-merkkijonoja** – tulostusmuoto (`[bold yellow]LOAD[/bold yellow]`) on Rich-spesifinen eikä suoraan käytettävissä GUI-kirjastoissa, jotka odottavat esimerkiksi väriattribuutteja tai token-listoja.

3. **Ei erillistä sovelluslogiikkakerroksen (controller/presenter) abstraktiota** – UI:n tapahtumankäsittelijät kutsuvat suoraan `KCPU16Machine`-metodeja ja päivittävät widgettejä samassa metodissa. Testattavuus ja GUI-kirjaston vaihto ovat tämän takia vaikeita.

4. **`_build_addr_to_line`-funktio on `tui.py`:ssä** – se on puhtaasti looginen apufunktio (osoite → lähdekoodirivi), jonka pitäisi olla kirjastoriippumattomassa moduulissa.

---

## 2. Tavoitearkkitehtuuri

Siirtymä tehdään **MVP-mallia** (Model-View-Presenter) noudattaen. Malli pitää loogisen tilan, View vastaa piirtämisestä, ja Presenter yhdistää ne.

```
┌──────────────────────────────────────────────────────────────────┐
│                         VIEW-KERROS                              │
│  (GUI-kirjasto, esim. PyQt6 / wxPython / Dear PyGui)            │
│  – widgetit, asettelu, tapahtumien välitys Presenterille        │
└────────────────────────┬─────────────────────────────────────────┘
                         │ kutsuu / vastaanottaa
┌────────────────────────▼─────────────────────────────────────────┐
│                      PRESENTER-KERROS                            │
│  kcpu16/presenter.py                                             │
│  – EmulatorPresenter-luokka                                      │
│  – Komentotulkki (_execute_command)                              │
│  – _build_addr_to_line (siirretty tänne tui.py:stä)             │
│  – DebugState-instanssi                                          │
│  – Ei riippuvuuksia GUI-kirjastoon                               │
└────────────────────────┬─────────────────────────────────────────┘
                         │ käyttää
┌────────────────────────▼─────────────────────────────────────────┐
│                       MODEL-KERROS (ennallaan)                   │
│  machine.py · cpu.py · memory.py · registers.py                  │
│  assembler.py · disassembler.py · debugger.py · devices/         │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Muutokset moduuleihin

### 3.1 Uusi moduuli: `kcpu16/presenter.py`

Siirretään `tui.py`:stä kirjastoriippumaton logiikka omaan moduuliinsa:

- **`EmulatorPresenter`-luokka**
  - Hallinnoi `KCPU16Machine`- ja `DebugState`-instansseja
  - Toteuttaa komentotulkin (nykyinen `_execute_command`)
  - Toteuttaa `step()`, `run_until_break()`, `assemble_and_load()`, `reset()` -metodit
  - Pitää yllä sovellustilaa (onko koodi assembloitu, mikä tiedosto on auki jne.)
  - Ei kutsu GUI-kirjaston metodeja suoraan; sen sijaan käyttää **callback-funktioita tai tapahtumia**, jotka View-kerros rekisteröi
- **`_build_addr_to_line`-funktio** siirretään tänne (tai `assembler.py`:hen)

Presenter ei importoi mitään GUI-kirjastoa. View voi olla TUI, graafinen ikkuna tai testitynkä.

### 3.2 Muutos: `kcpu16/editor.py` – `AssemblySyntaxHighlighter`

Nykyinen `highlight_line`-metodi palauttaa Rich-markup-merkkijonon. GUI-kirjastot tarvitsevat väri-informaation eri muodossa.

**Ratkaisu:** Lisätään uusi metodi `tokenize_line`, joka palauttaa listan `(teksti, väriavain)` -pareista sen sijaan, että käytettäisiin Rich-markup-tageja:

```python
# Nykyinen (Rich-spesifinen):
"[bold yellow]LOAD[/bold yellow] [cyan]R0[/cyan], [green]#42[/green]"

# Uusi (kirjastoriippumaton):
[("LOAD", "mnemonic"), (" R0", "register"), (", ", None), ("#42", "number")]
```

Väriavaimen (`"mnemonic"`, `"register"`, `"number"`, `"comment"`, `"label"`, `"directive"`) kuvaus väriksi tapahtuu View-kerroksessa, jolloin jokainen GUI-toteutus voi käyttää omaa väriteemaansa. Vanha `highlight_line`-metodi voidaan säilyttää taaksepäin yhteensopivuuden vuoksi CLI-käyttöön.

### 3.3 Muutos: `kcpu16/tui.py`

TUI säilyy toimivana, mutta refaktoroidaan käyttämään `EmulatorPresenter`-luokkaa suoran `KCPU16Machine`-kutsun sijaan. Textual-widgetit rekisteröivät callback-funktiot Presenterille, jotka päivittävät näytön. Tämä varmistaa, että TUI-toteutus ja tuleva GUI-toteutus käyttävät täsmälleen samaa Presenter-rajapintaa.

### 3.4 Uusi moduuli: `kcpu16/gui_protocol.py` (valinnainen)

Voidaan määritellä `ViewProtocol` (Python `typing.Protocol`) kuvaamaan mitä metodeja Presenter odottaa View-objektilta. Tämä mahdollistaa staattisen tyyppitarkistuksen ja selkeyttää sopimusta.

```python
class ViewProtocol(Protocol):
    def update_registers(self, regs: dict[str, int], changed: dict[str, bool]) -> None: ...
    def update_disassembly(self, lines: list[str], pc_addr: int) -> None: ...
    def update_screen(self, text: str) -> None: ...
    def show_log(self, message: str, level: str = "info") -> None: ...
    def set_editor_content(self, text: str) -> None: ...
    def get_editor_content(self) -> str: ...
```

---

## 4. GUI-kirjastoehdotukset

Alla on kolme parasta vaihtoehtoa kCPU16:n GUI:lle. Jokainen sopii eri priorisointitilanteeseen.

### 4.1 PyQt6 / PySide6 ⭐ suositeltu

| Ominaisuus | Arvio |
|---|---|
| Kypsyys | Erittäin kypsynyt, laaja ekosysteemi |
| Alustakattavuus | Windows, macOS, Linux |
| Widgetit | Täydellinen joukko (tekstieditori, taulukkonäkymät, välilehdet) |
| Syntaksiväritys | `QSyntaxHighlighter` (rakennettu API) |
| Lisenssi | PyQt6: GPL/kaupallinen; **PySide6: LGPL** (vapaampi) |
| Oppimiskynnys | Kohtalainen |

PyQt6/PySide6 soveltuu parhaiten, koska `QSyntaxHighlighter`-luokka mahdollistaa laadukkaan syntaksivärityksen koodieditoriin ilman ylimääräisiä kirjastoja. `QPlainTextEdit` ja `QTableWidget` vastaavat lähes 1:1 TUI:n editoria ja muistilistaa. PySide6 on lisenssin puolesta parempi valinta avoimen lähdekoodin projektille.

### 4.2 wxPython

| Ominaisuus | Arvio |
|---|---|
| Kypsyys | Erittäin kypsynyt |
| Alustakattavuus | Windows, macOS, Linux (natiivit widgetit) |
| Widgetit | Kattava joukko |
| Syntaksiväritys | `wx.stc.StyledTextCtrl` (Scintilla-pohjainen) |
| Lisenssi | wxWindows (LGPL-yhteensopiva) |
| Oppimiskynnys | Kohtalainen–korkea |

wxPython tuottaa natiiveja widgettejä, joten sovellus näyttää oikealta jokaisella alustalla. `StyledTextCtrl` on erittäin tehokas koodieditoriin. Pienemmän yhteisön takia dokumentaatio on osin puutteellisempaa.

### 4.3 Dear PyGui

| Ominaisuus | Arvio |
|---|---|
| Kypsyys | Aktiivinen kehitys, nuorempi projekti |
| Alustakattavuus | Windows, macOS, Linux |
| Widgetit | Debuggeri- ja työkalutyyliset widgetit erinomaiset |
| Syntaksiväritys | Ei natiivitukea, vaatii oman toteutuksen |
| Lisenssi | MIT |
| Oppimiskynnys | Matala (välitön tila, ei tapahtumasilmukka-arkkitehtuuri) |

Dear PyGui sopii erityisesti debuggeri-tyylisiin sovelluksiin: se on inspiroitunut ImGui:sta ja tarjoaa valmiiksi erinomaisen tuen liukusäätimille, taulunäkymille ja reaaliaikaisesti päivittyville arvoille. Koodieditorin syntaksiväritys pitää toteuttaa itse, mikä on merkittävä lisätyö.

---

## 5. Migraatiosuunnitelma vaiheittain

### Vaihe 1 – Presenter-kerroksen luominen (tärkeintä ensin)

1. Luo `kcpu16/presenter.py`
2. Siirrä `_execute_command`-metodi ja komentotulkin logiikka sinne
3. Siirrä `_build_addr_to_line`-funktio sinne (tai `assembler.py`:hen)
4. Refaktoroi `tui.py` käyttämään `EmulatorPresenter`-luokkaa
5. Varmista, että TUI toimii edelleen kuten ennen

### Vaihe 2 – Syntaksivärityksen irrottaminen Rich:stä

1. Lisää `tokenize_line`-metodi `AssemblySyntaxHighlighter`-luokkaan
2. Säilytä `highlight_line` taaksepäin yhteensopivuuden vuoksi
3. Päivitä TUI käyttämään uutta metodia (jos mahdollista), tai jätä Rich-käyttö TUI:ssa

### Vaihe 3 – `ViewProtocol`-rajapinnan määrittely

1. Luo `kcpu16/gui_protocol.py` `ViewProtocol`-tyypillä
2. Tarkista, että `tui.py`:n `KCPU16TUI`-luokka täyttää protokollan
3. Lisää tyyppivihjeet `EmulatorPresenter`-luokkaan

### Vaihe 4 – GUI-toteutus (kirjaston valinnan jälkeen)

1. Luo `kcpu16/gui.py` (tai `kcpu16/qt_gui.py` jne.)
2. Toteuta `ViewProtocol`-rajapinta valitulla kirjastolla
3. Lisää `main.py`:n CLI:hin `--gui`-lippu käynnistämään graafinen versio
4. TUI säilyy `--tui`-lipulla tai oletusarvona terminaalikäytössä

---

## 6. Yhteenveto

| Prioriteetti | Toimenpide | Vaikutus |
|---|---|---|
| Korkea | Luo `presenter.py`, siirrä liiketoimintalogiikka pois `tui.py`:stä | Mahdollistaa GUI-kirjaston lisäämisen ilman tui.py:n muuttamista |
| Korkea | Lisää `tokenize_line` syntaksiväritykseen | Syntaksiväritys toimii millä tahansa GUI-kirjastolla |
| Keskitaso | Määrittele `ViewProtocol` | Selkeyttää rajapintasopimusta, helpottaa testausta |
| Matala | Valitse GUI-kirjasto ja toteuta View | Tehdään vaiheiden 1–3 jälkeen |

**Suositeltu GUI-kirjasto:** PySide6, koska se on LGPL-lisensoitu, kypsä, alustariippumaton, ja sen `QSyntaxHighlighter`-tuki ja `QPlainTextEdit` sopivat luontevasti koodieditorin tarpeisiin.
