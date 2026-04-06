# kCPU16 — Grafiikkatila Textual-kirjaston rajoissa

Versio 1.0

---

## 1. Johdanto

kCPU16 käyttää käyttöliittymänään Textual-kirjastoa (Python), joka on
tekstipohjaisen terminaalikäyttöliittymän (TUI) rakennuskirjasto. Se perustuu
Rich-kirjastoon ja toimii täysin terminaalissa — ei ikkunajärjestelmässä eikä
graafisessa ympäristössä.

Tässä selvityksessä kartoitetaan, millainen grafiikkatila on mahdollista
toteuttaa Textual-kirjaston ominaisuuksien rajoissa, ja vertaillaan eri
vaihtoehtojen resoluutiota, värisyvyyttä ja toteutettavuutta.

---

## 2. Textual-kirjaston grafiikkamahdollisuudet

### 2.1 Terminaalin perusyksikkö: merkkiruutu

Kaikki Textual-renderöinti perustuu **terminaalin merkkiruutuihin** (character
cell). Yksi ruutu vastaa yhtä merkkiä — tyypillisesti 8×16 pikseliä
fonttiriippuvaisesti. Näytöllä ruudut on järjestetty riveittäin.

kCPU16:n nykyinen tekstinäyttö on 80×24 merkkiruutua.

### 2.2 Värituki

| Taso            | Värimäärä       | Rich-syntaksi                          |
| --------------- | --------------- | -------------------------------------- |
| ANSI 8 väriä    | 8 edustus + 8 tausta = 16 | `[red on black]`             |
| ANSI 256 väriä  | 256 (indeksoitu) | `[color(200)]`                        |
| True color      | 16 777 216 (24-bit RGB) | `Style(color=Color.from_rgb(r,g,b))` |

Textual (ja Rich) tukevat kaikkia kolmea tasoa. Useimmat modernit
terminaaliemulaattorit (Alacritty, Kitty, iTerm2, Windows Terminal, GNOME
Terminal jne.) tukevat **true color** -tilaa.

### 2.3 Pikseliemulointitekniikat

Koska terminaali perustuu merkkeihin, "pikselit" emuloidaan erityisillä
Unicode-merkeillä:

#### A) Puoliblokkiruudut (half-block)

| Merkki | Koodipiste | Kuvaus                   |
| ------ | ---------- | ------------------------ |
| `▀`    | U+2580     | Ylempi puolikas täynnä   |
| `▄`    | U+2584     | Alempi puolikas täynnä   |
| `█`    | U+2588     | Koko ruutu täynnä        |
| `▌`    | U+258C     | Vasen puolikas täynnä    |
| `▐`    | U+2590     | Oikea puolikas täynnä    |

Käyttämällä `▀`-merkkiä edustusvärillä (FG) ylemmälle pikselille ja
taustavärillä (BG) alemmalle pikselille saadaan **2 pikseliä per
merkkiruutu pystysuunnassa**:

```
80 merkkiä × 24 riviä × 2 pikseliä/rivi = 80 × 48 pikseliä
```

#### B) Neljäsosablokkiruudut (quarter-block)

Merkit U+2596–U+259F koodaavat 2×2 pikselipiirteitä (16 yhdistelmää).
Yksi väri per ruutu, mutta 4 pikseliä per merkkiruutu:

```
80 × 2 = 160 pikseliä leveyttä
24 × 2 = 48 pikseliä korkeutta
→ 160 × 48 pikseliä (yksi väri per 2×2 blokki)
```

#### C) Braille-pisteet

Unicode braille -alue U+2800–U+28FF sisältää 256 merkkiä, joissa jokainen
vastaa 2×4 pikselipiirrettä (8 bittiä, kukin bitti = yksi piste):

```
80 × 2 = 160 pikseliä leveyttä
24 × 4 = 96 pikseliä korkeutta
→ 160 × 96 pikseliä (1-bittinen; yksi väri per merkkiruutu)
```

#### D) Yksittäiset merkkiruudut taustavärillä (true color)

Välilyöntimerkeillä (`' '`) ja true-color taustavärillä saadaan **1 pikseliä
per merkkiruutu**, mutta 24-bittisenä RGB-värinä:

```
80 × 24 = 1920 pikseliä (true color, 16 777 216 väriä)
```

### 2.4 Textualin renderöintimekanismi

Mukautettu grafiikkawidget toteutetaan ylikirjoittamalla `render_line(y)`
-metodi `Widget`-luokan aliluokassa. Metodi palauttaa `Strip`-olion, joka
koostuu `Segment`-olioista (teksti + tyyli):

```python
from textual.widget import Widget
from textual.strip import Strip
from rich.segment import Segment
from rich.style import Style
from rich.color import Color

class PixelScreen(Widget):
    def render_line(self, y: int) -> Strip:
        segments = []
        for x in range(self.size.width):
            top_rgb = self._get_pixel(x, y * 2)      # ylempi pikseli
            bot_rgb = self._get_pixel(x, y * 2 + 1)  # alempi pikseli
            style = Style(
                color=Color.from_rgb(*top_rgb),
                bgcolor=Color.from_rgb(*bot_rgb),
            )
            segments.append(Segment("▀", style))
        return Strip(segments)
```

Tämä on Textualin suosittelema tapa toteuttaa matalan tason pikselijärjestelmä.
`render_line()` kutsutaan kerran per näkyvä rivi ja vain tarvittaessa
(vain likatut alueet piirretään uudelleen).

### 2.5 Textualin kokeellinen Canvas-moduuli

Textual sisältää `textual.canvas`-moduulin (merkitty kokeelliseksi).
Se tukee geometrisia primitiivejä (viivat, suorakulmiot) merkkiruutuperustaisena,
mutta **ei rasterikuviin soveltuvaa pikselipohjaiseta API:a**. Se soveltuu
parhaiten viivakuvioihin (UI:n reunaviivat, kehykset).

---

## 3. Vaihtoehtojen vertailu

| Vaihtoehto               | Resoluutio  | Värisyvyys      | VRAM-tarve (sanat) | Soveltuvuus kCPU16:lle |
| ------------------------ | ----------- | --------------- | ------------------ | ---------------------- |
| **Tekstinäyttö** (nykytila) | 80 × 24 merkkiä | 8 FG + 8 BG   | 1 920              | Käytössä               |
| **Puoliblokkipikseli (A)**  | 80 × 48     | 8 väriä/pikseli | 1 920 (sama VRAM)  | ★★★★★ Suositeltu       |
| **Neljäsosablokkipikseli (B)** | 160 × 48 | 8 väriä/blokki | 1 920 (sama VRAM)  | ★★★☆☆                |
| **Braille (C)**          | 160 × 96    | 8 väriä/merkki  | 1 920 (sama VRAM)  | ★★☆☆☆                 |
| **True color (D)**       | 80 × 24     | 16 777 216/piks | 4 320 (RGB, 3 kpl) | ★★★☆☆                 |

---

## 4. Suositeltu toteutus: puoliblokkipikseli (80 × 48)

### 4.1 Perusteet

Puoliblokkipikseli-tila on optimaalisin vaihtoehto kCPU16:n rajoissa:

1. **VRAM-yhteensopivuus**: Nykyinen 16-bittinen VRAM-sana sopii suoraan
   grafiikkatilaan. FG-bitit (8–10) koodaavat ylemmän pikselin värin, BG-bitit
   (11–13) koodaavat alemman pikselin värin. Merkkibittejä (0–7) ei grafiikkatilassa
   käytetä.

2. **Kaksinkertainen pystyresoluutio**: 80×48 pikseliä mahdollistaa
   yksinkertaisten kuvioiden, pisteiden, viivojen ja täytettyjen alueiden
   piirtämisen.

3. **Tuttu värimalini**: 8 värin paletti (musta, punainen, vihreä, keltainen,
   sininen, magenta, syaani, valkoinen) on jo tuettu tekstitilassa ja
   assembly-ohjelman näkökulmasta ei tarvita uusia värimäärittelyjä.

4. **Yksinkertainen toteutus**: Yksi VRAM-sana = yksi merkkiruutu =
   kaksi pikseliä. Ei tarvita uutta VRAM-aluetta.

### 4.2 VRAM-sanan rakenne grafiikkatilassa

```
Bitti 15–14: Attribuutit (sama kuin tekstinäytössä, ignoroidaan grafiikkatilassa)
Bitti 13–11: Alempi pikseli – BG-väri (3 bittiä = 8 väriä)
Bitti 10–8:  Ylempi pikseli – FG-väri (3 bittiä = 8 väriä)
Bitti 7–0:   Ei käytetty grafiikkatilassa (merkki ignoroidaan)
```

Osoitekaava (sama kuin tekstinäytössä):

```
osoite = VRAM_START + (rivi // 2) * 80 + sarake
```

Esimerkki: pikseliä (kolumni=10, rivi=5) vastaava VRAM-osoite:

```
osoite = 0xF800 + (5 // 2) * 80 + 10 = 0xF800 + 2 * 80 + 10 = 0xF90A
```

Pikselin värin asetus ylemmälle pikselille:

```asm
; Aseta piste (10, 4) punaiseksi (värikoodi 1 = punainen)
; Rivi 4 on ylempi pikseli merkkiruudussa (4//2 = 2)
; FG-bitit (8-10), punainen = 1 → siirrä 8 bittiä vasemmalle
LOAD R0, #0x0100    ; FG = punainen (1 << 8)
LOAD R1, #0xF80A    ; osoite = F800 + 2*80 + 10
STORE R0, [R1]
```

### 4.3 Tilakytkin: tekstitila vs. grafiikkatila

Tila voidaan kytkeä käyttämällä erillistä muistiosoitetta tilarekisterinä,
esimerkiksi VRAM-alueen jälkeistä osoitetta:

| Osoite  | Kuvaus                              |
| ------- | ----------------------------------- |
| `$FF80` | Näyttötilarekisteri: `0` = tekstitila, `1` = grafiikkatila |

Assembly-esimerkki grafiikkatilan kytkemisestä:

```asm
LOAD R0, #1
LOAD R1, #0xFF80    ; näyttötilarekisteri
STORE R0, [R1]      ; kytke grafiikkatila päälle
```

Textual-widgetti tarkistaa tämän osoitteen `refresh()`-kutsun yhteydessä
ja valitsee renderöintitavan sen mukaan.

### 4.4 TUI-widgetin toiminta

`ScreenDevice`-widget muokataan tarkistamaan tilarekisteri ennen renderöintiä:

- **Tekstitila** (0): Nykyinen `render_with_rich_colors()` — ASCII-merkit väreillä.
- **Grafiikkatila** (1): Uusi `render_pixel_mode()` — `▀`-merkit, jossa
  FG-väri = ylempi pikseli ja BG-väri = alempi pikseli.

---

## 5. True-color-laajennus (vaihtoehto)

Jos väripalettia halutaan laajentaa 8 väristä true-coloriin (16 777 216 väriä),
tarvitaan uusi GVRAM-alue (Graphics VRAM).

### 5.1 GVRAM-muistikartta (80 × 24 true-color pikseli)

```
Pikseli (x, y):
    R-osoite = GVRAM_START + y * 80 * 3 + x * 3
    G-osoite = GVRAM_START + y * 80 * 3 + x * 3 + 1
    B-osoite = GVRAM_START + y * 80 * 3 + x * 3 + 2
```

Koko: 80 × 24 × 3 = 5 760 sanaa.

Koska nykyinen VRAM ($F800–$FF7F = 1 920 sanaa) ei riitä, GVRAM sijoitetaan
vapaalle RAM-alueelle, esimerkiksi:

```
$E200 – $F7FF = 5 888 sanaa (riittää 5 760 sanan GVRAM:lle)
```

True-color-laajennus vaatii merkittävästi enemmän muistia ja monimutkaisemman
assembly-ohjelmoinnin, joten se soveltuu lähinnä erikoiskäyttöön.

---

## 6. Yhteenveto

| Kriteeri              | Suositeltava toteutus (puoliblokkipikseli) |
| --------------------- | ----------------------------------------- |
| Resoluutio            | 80 × 48 pikseliä                          |
| Värisyvyys            | 8 väriä per pikseli                       |
| VRAM-tarve            | 1 920 sanaa (sama alue $F800–$FF7F)       |
| Tekstinäyttöyhteensop. | Kyllä (sama VRAM, tilarekisterikytkentä)  |
| Toteutuksen monimutkaisuus | Matala (ScreenDevice-muutos + tilarekisteri) |
| Textual-mekanismi     | `render_line()` + `Strip` + `Segment`     |

Textual-kirjasto mahdollistaa tehokkaan pikseligrafiikan toteuttamisen
Unicode-puoliblokkiruuduin (`▀`) ja true-color -väreillä. Suositeltu
**80 × 48 pikseliä, 8 väriä** -grafiikkatila on yhteensopiva nykyisen
VRAM-rakenteen kanssa eikä vaadi muutoksia muistikartalle — ainoastaan
tilarekisterin lisääminen ja `ScreenDevice`-widgetin muokkaaminen riittää.
