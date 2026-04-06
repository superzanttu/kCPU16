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

## 6. Ehdotus: 640 × 480 pikseliä Textual-toteutuksena

### 6.1 Reunaehdot

Ennen kuin 640 × 480 on mahdollinen, on ratkaistava kaksi perusongelmaa:

| Ongelma | Syy |
| ------- | --- |
| **Muistinpuute** | 640 × 480 pikseliä vaatii 38 400–76 800 sanaa, mutta kCPU16:n koko osoiteavaruus on 65 536 sanaa. GVRAM ei mahdu normaaliin muistikarttaan. |
| **Terminaalin koko** | 640 × 480 pikseliä half-block-tekniikalla vaatisi 640 saraketta × 240 riviä, mikä ylittää jokaisen käytännön terminaalin. |

Molemmat ongelmat ovat ratkaistavissa: muisti pankkikytkennällä ja
terminaalinäkymä skaalaamalla.

---

### 6.2 Grafiikkamuisti: GVRAM-pankkikytkentä

#### Pikseliformaatti: 3 bittiä / pikseli, 5 pikseliä / sana

Säilyttämällä kCPU16:n olemassa oleva 8 värin paletti (sama kuin tekstitilassa)
saadaan kompakti esitys: 3 bittiä per pikseli, 5 pikseliä per 16-bittinen sana
(5 × 3 = 15 bittiä; bitti 15 jätetään käyttämättä).

```
Sana: [14–0] = px4[2:0] | px3[2:0] | px2[2:0] | px1[2:0] | px0[2:0]
```

Muistintarve:

```
640 / 5 = 128 sanaa / rivi
128 × 480 = 61 440 sanaa yhteensä
→ 8 pankkia à 8 192 sanaa (8 × 8 192 = 65 536)
```

#### Pankkikytkentärekisteri GBANK

Lisätään uusi **järjestelmärekisteri GBANK** (indeksi 6 tai erillinen portti).
Se valitsee aktiivisen GVRAM-pankin 0–7, joka kartoitetaan osoitteisiin
`$2000–$3FFF` (8 192 sanaa).

| Rekisteri | Arvo   | Kuvaus                                        |
| --------- | ------ | --------------------------------------------- |
| GBANK     | 0–7    | Aktiivinen GVRAM-pankki                       |
| GMODE     | 0 / 1  | Näyttötila: 0 = teksti/80×48, 1 = 640×480     |

Fyysinen GVRAM on emulaattorin Python-tasolla 65 536 sanaa pitkä taulukko,
erillään normaalista muistista. CPU lukee ja kirjoittaa sitä osoitteiden
`$2000–$3FFF` kautta, ja GBANK-rekisteri kertoo emulaattorille, mikä
8 192 sanan lohko on näkyvissä.

#### Muistikartta GVRAM-ikkunan kanssa

```
$0000 – $0008   9 sanaa       Keskeytysvektoritaulukko (ennallaan)
$0009 – $00FF   247 sanaa     Käyttöjärjestelmän varaus
$0100 – $01FF   256 sanaa     Bootloader
$0200 – $1FFF   7 680 sanaa   Vapaa RAM (ohjelmakoodi)
$2000 – $3FFF   8 192 sanaa   ← GVRAM-ikkuna (pankkikytkentä, GBANK 0–7)
$4000 – $F7FF   47 104 sanaa  Vapaa RAM (data, pinorakenne)
$F800 – $FF7F   1 920 sanaa   VRAM (tekstitila) — ennallaan
$FF80 – $FF81   2 sanaa       GMODE-rekisteri ($FF80) ja GBANK-rekisteri ($FF81)
$FF82 – $FFFF   126 sanaa     Kernel-pino
```

---

### 6.3 Uudet käskyt ja rekisterit

#### Uusi järjestelmärekisteri GBANK

Pankkikytkentärekisterin kirjoittaminen onnistuu uudella etuoikeutetulla käskyllä:

| Käsky          | Operandit      | Kuvaus                              |
| -------------- | -------------- | ----------------------------------- |
| `SGBANK Rx`    | rekisteri      | Aseta GBANK ← Rx (Kernel-tila)      |
| `LGBANK Rx`    | rekisteri      | Lue GBANK → Rx                      |

Vaihtoehtoisesti GBANK voidaan toteuttaa muistikartatun rekisterin avulla
(`STORE R0, [$FF81]` / `LOAD R0, [$FF81]`), jolloin uusia käskyjä ei tarvita.
Tämä on yksinkertaisempi ja suositeltava lähestymistapa.

#### GMODE-rekisteri

Kirjoitetaan muistikartatusti, samoin kuin nykyinen näyttötilarekisteri:

```asm
; Kytke 640×480 grafiikkatila päälle
LOAD R0, #1
STORE R0, [$FF80]     ; GMODE = 1 (grafiikkatila)
LOAD R0, #0
STORE R0, [$FF81]     ; GBANK = 0 (ensimmäinen pankki)
```

---

### 6.4 GVRAM-pikselioperaatiot assembly-koodissa

#### Pikselin osoitteen laskenta

Pikseli `(x, y)`:

```
pankki         = (y * 128 + x / 5) / 8192
pankkisisäinen = (y * 128 + x / 5) mod 8192
bitti-siirtymä = (x mod 5) * 3
osoite         = $2000 + pankkisisäinen
```

Pikselivärin lukeminen (3 bittiä):

```
arvo = (GVRAM[osoite] >> bitti-siirtymä) & 0x7
```

#### Assembly-esimerkki: pikselin asettaminen

```asm
; Aseta pikseli (x=10, y=5) väriksi punainen (1)
; Laske: sanaindeksi = 5*128 + 10/5 = 640 + 2 = 642
;        pankki = 642 / 8192 = 0
;        pankkisisäinen = 642 mod 8192 = 642
;        bitti-siirtymä = (10 mod 5) * 3 = 0

LOAD R0, #0
STORE R0, [$FF81]       ; GBANK = 0

LOAD R1, #0x2000        ; GVRAM-ikkunan alku
LOAD R2, #642           ; pankkisisäinen osoite
ADD R1, R2              ; R1 = $2000 + 642

LOAD R3, [R1]           ; lue nykyinen sana
AND R3, #0xFFF8         ; tyhjennä bitit 2-0 (pikseli 0:n paikka)
OR  R3, #1              ; aseta väri = punainen (1)
STORE R3, [R1]          ; kirjoita takaisin
```

---

### 6.5 Textual-renderöinti: skaalaus 640 × 480 → 80 × 48

640 × 480 pikseliä ei voi näyttää suoraan terminaalissa — terminaalin
käytännöllinen maksimikoko on noin 200 × 50 merkkiä. Ratkaisu on
**lähimmän naapurin skaalaus** (nearest-neighbor) loogisesta framebufferista
Textual-widgetin `render_line()`-metodissa:

```
Horisontaalinen skaalaus: 640 / 80 = 8 (jokainen terminaalipikseliä = 8 loogista pikseliä)
Vertikaalinen skaalaus:   480 / 48 = 10 (jokainen half-block rivi = 10 loogista pikseliä)
```

```python
class GfxScreen640x480(Widget):
    """Textual-widget, joka renderöi 640×480 GVRAM:n skaalatusti 80×24-terminaaliin."""

    def render_line(self, y: int) -> Strip:
        # y = terminaalin rivi 0..23; yksi rivi = 2 half-block pikseliä
        top_row = y * 20       # Ylempi puolikas: looginen pikselirivi (480 / 24 = 20)
        bot_row = y * 20 + 10  # Alempi puolikas: 10 riviä alempana

        segments = []
        for x in range(80):
            px_col = x * 8     # 640 / 80 = 8 loogista pikseliä per sarake

            top_color = self._read_gvram_pixel(px_col, top_row)
            bot_color = self._read_gvram_pixel(px_col, bot_row)

            style = Style(
                color=_PALETTE[top_color],
                bgcolor=_PALETTE[bot_color],
            )
            segments.append(Segment("▀", style))
        return Strip(segments)

    def _read_gvram_pixel(self, x: int, y: int) -> int:
        """Lue pikseliväri (0-7) GVRAM:sta."""
        word_idx = y * 128 + x // 5       # 128 sanaa/rivi
        bit_shift = (x % 5) * 3           # 3 bittiä/pikseli
        bank = word_idx // 8192
        offset = word_idx % 8192
        addr = 0x2000 + offset
        # Valitse pankki ja lue muistista
        self._machine.memory.write(0xFF81, bank)
        word = self._machine.memory.read(addr)
        return (word >> bit_shift) & 0x7
```

Tuloksena koko 640 × 480 framebuffer esitetään 80 × 24 merkkiruudussa
(80 × 48 half-block pikseliä), jossa jokainen näyttöpiste vastaa
8 × 10 loogista pikseliä.

---

### 6.6 Tarvittavat arkkitehtuurimuutokset yhteenveto

| Muutos                     | Tyyppi               | Kuvaus |
| -------------------------- | -------------------- | ------ |
| **GVRAM-puskuri**          | Emulaattori (Python) | 65 536 sanan erillinen taulukko `Machine`-luokkaan |
| **GBANK-rekisteri**        | CPU / muistikartta   | Muistikartattu `$FF81`: valitsee aktiivisen 8 192 sanan GVRAM-pankin 0–7 |
| **GMODE-rekisteri**        | CPU / muistikartta   | Muistikartattu `$FF80`: `0` = tekstitila, `1` = 640×480 grafiikkatila |
| **Pankkikytkentä `Memory`-luokassa** | Emulaattori | `read()`/`write()` tarkistaa `$2000–$3FFF`: osoite ohjataan `gvram[GBANK * 8192 + offset]` |
| **`ScreenDevice`-päivitys** | Python / TUI        | Uusi `render_pixel_mode_640()` -metodi, joka kutsuu `render_line()` + skaalaus 8×10 |
| **Textual-widget**         | TUI (`tui.py`)       | `GfxScreen640x480` toteuttaa `render_line(y)` + `_read_gvram_pixel()` |
| **Uusi näppäinsidos**      | TUI                  | F8 tai `Ctrl+G`: vaihda tekstitila ↔ 640×480 grafiikkatila |
| **Assembly-vakiot**        | `constants.py`       | `GVRAM_WINDOW`, `GVRAM_BANK_SIZE`, `GMODE_ADDR`, `GBANK_ADDR` |

Yksikään muutos ei edellytä ISA:n laajentamista uusilla konekielen käskyillä —
kaikki kontrolli tapahtuu muistikartattujen rekisterien (`$FF80`, `$FF81`)
kautta, joihin voidaan kirjoittaa tavallisilla `LOAD`/`STORE`-käskyillä.

---

## 7. Yhteenveto

| Kriteeri              | Perustoteutus (puoliblokkipikseli) | 640 × 480 Textual-toteutus                  |
| --------------------- | ---------------------------------- | ------------------------------------------- |
| Resoluutio            | 80 × 48 pikseliä                   | 640 × 480 pikseliä (looginen framebuffer)   |
| Terminaalinäyttö      | 80 × 24 merkkiä                    | 80 × 24 merkkiä (skaalattu 8×10)            |
| Värisyvyys            | 8 väriä per pikseli                | 8 väriä per pikseli (sama 3-bittinen paletti) |
| VRAM-tarve            | 1 920 sanaa ($F800–$FF7F)          | 61 440 sanaa (8 pankkia à 8 192)            |
| Muistikarttamuutos    | Ei (sama VRAM)                     | GVRAM-ikkuna $2000–$3FFF + GBANK $FF81      |
| ISA-muutos            | Ei                                 | Ei (muistikartattu ohjaus)                  |
| Uudet vakiot          | GMODE_ADDR ($FF80)                 | + GBANK_ADDR ($FF81), GVRAM_BANK_SIZE       |
| Textual-mekanismi     | `render_line()` + `Strip`          | `render_line()` + skaalaus 8×10 + GBANK     |
| Toteutuksen monimutkaisuus | Matala                        | Kohtalainen                                 |

Textual-kirjasto mahdollistaa tehokkaan pikseligrafiikan toteuttamisen
Unicode-puoliblokkiruuduin (`▀`) ja true-color -väreillä. Perustoteutuksena
**80 × 48 pikseliä, 8 väriä** toimii nykyisen VRAM-rakenteen kanssa ilman
muistikarttatmuutoksia. Täysi **640 × 480** on toteutettavissa pankkikytkennällä
ja muistikartatuilla GMODE/GBANK-rekistereillä ilman uusia konekielen käskyjä —
Textual skaalaa loogisen framebufferin 80 × 24 terminaalinäyttöön automaattisesti.
