# kCPU16 — Grafiikkatila Textual-kirjaston rajoissa

Versio 2.0

---

## 1. Johdanto

kCPU16 käyttää käyttöliittymänään Textual-kirjastoa (Python), joka on
tekstipohjaisen terminaalikäyttöliittymän (TUI) rakennuskirjasto. Se perustuu
Rich-kirjastoon ja toimii täysin terminaalissa — ei ikkunajärjestelmässä eikä
graafisessa ympäristössä.

Tässä suunnitelmassa määritellään kCPU16:n grafiikkatilat. Käytettävissä on
**kolme tilaa**, joista kaikki ovat **yksiväriseen** (monochrome) pikselikoodaukseen
perustuvia: jokaiseen pikseliin käytetään **yksi bitti** (päällä/pois).

| Tunniste | Nimi                  | Resoluutio       | Pikseleitä/merkkiruutu |
| -------- | --------------------- | ---------------- | ---------------------- |
| **A**    | Tekstitila (nykytila) | 80 × 24 merkkiä  | 1 merkki               |
| **B**    | Puoliblokkipikseli    | 80 × 48 pikseliä | 2 (1 bitti/pikseli)    |
| **C**    | Braille               | 160 × 96 pikseliä| 8 (1 bitti/pikseli)    |

---

## 2. Textual-kirjaston grafiikkamahdollisuudet

### 2.1 Terminaalin perusyksikkö: merkkiruutu

Kaikki Textual-renderöinti perustuu **terminaalin merkkiruutuihin** (character
cell). Yksi ruutu vastaa yhtä merkkiä — tyypillisesti 8×16 pikseliä
fonttiriippuvaisesti. Näytöllä ruudut on järjestetty riveittäin.

kCPU16:n nykyinen tekstinäyttö on 80×24 merkkiruutua.

### 2.2 Värituki

Kaikki kCPU16:n grafiikkatilat ovat **yksivärisisiä (monochrome)**: jokainen
pikseli esitetään **yhdellä bitillä** (1 = päällä, 0 = pois). Värisyvyys on
siis 1 bitti per pikseli — ei väripalettia, ei RGB-arvoja.

Renderöinnissä "päällä"-pikseli näytetään edustusvärinä (FG, esim. valkoinen)
ja "pois"-pikseli taustavärinä (BG, esim. musta). Värit ovat Textualin ANSI-tasolla
asetettavia vakioarvoja, eivät ohjelmoijan säädeltävissä olevia attribuutteja.

### 2.3 Pikseliemulointitekniikat

Koska terminaali perustuu merkkeihin, "pikselit" emuloidaan erityisillä
Unicode-merkeillä:

#### B) Puoliblokkiruudut (half-block)

| Merkki | Koodipiste | Kuvaus                   |
| ------ | ---------- | ------------------------ |
| `▀`    | U+2580     | Ylempi puolikas täynnä   |
| `▄`    | U+2584     | Alempi puolikas täynnä   |
| `█`    | U+2588     | Koko ruutu täynnä        |
| ` `    | U+0020     | Tyhjä ruutu              |

Käyttämällä sopivaa puoliblokkimerkkiä edustusvärillä (FG) ja taustavärillä
(BG) saadaan **2 pikseliä per merkkiruutu pystysuunnassa**:

```
80 merkkiä × 24 riviä × 2 pikseliä/rivi = 80 × 48 pikseliä
```

Jokainen pikseli on 1-bittinen (päällä / pois).

#### C) Braille-pisteet

Unicode braille -alue U+2800–U+28FF sisältää 256 merkkiä, joissa jokainen
vastaa 2×4 pikselipiirrettä (8 bittiä, kukin bitti = yksi piste):

```
80 × 2 = 160 pikseliä leveyttä
24 × 4 = 96 pikseliä korkeutta
→ 160 × 96 pikseliä (1-bittinen; yksi päällä/pois-pikseli per piste)
```

Jokainen pikseli on 1-bittinen (päällä / pois).

### 2.4 Textualin renderöintimekanismi

Mukautettu grafiikkawidget toteutetaan ylikirjoittamalla `render_line(y)`
-metodi `Widget`-luokan aliluokassa. Metodi palauttaa `Strip`-olion, joka
koostuu `Segment`-olioista (teksti + tyyli):

```python
from textual.widget import Widget
from textual.strip import Strip
from rich.segment import Segment
from rich.style import Style

_ON  = Style(color="white", bgcolor="black")
_OFF = Style(color="black", bgcolor="black")

_CHARS = {
    (False, False): (" ", Style(bgcolor="black")),   # molemmat pois
    (True,  False): ("▀", _ON),                      # ylempi päällä
    (False, True ): ("▄", _ON),                      # alempi päällä
    (True,  True ): ("█", _ON),                      # molemmat päällä
}

class HalfBlockScreen(Widget):
    def render_line(self, y: int) -> Strip:
        segments = []
        for x in range(self.size.width):
            top = self._get_pixel(x, y * 2)      # ylempi pikseli (bool)
            bot = self._get_pixel(x, y * 2 + 1)  # alempi pikseli (bool)
            ch, style = _CHARS[(top, bot)]
            segments.append(Segment(ch, style))
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

## 3. Grafiikkatilat — vertailu

| Tila | Nimi                    | Resoluutio        | Värisyvyys         | VRAM-tarve (sanat) |
| ---- | ----------------------- | ----------------- | ------------------ | ------------------ |
| **A** | Tekstitila (nykytila)  | 80 × 24 merkkiä   | 8 FG + 8 BG        | 1 920              |
| **B** | Puoliblokkipikseli     | 80 × 48 pikseliä  | 1 bitti/pikseli    | 1 920 (sama VRAM)  |
| **C** | Braille                | 160 × 96 pikseliä | 1 bitti/pikseli    | 1 920 (sama VRAM)  |

Kaikki grafiikkatilat (B ja C) käyttävät täsmälleen samaa VRAM-aluetta
($F800–$FF7F = 1 920 sanaa) kuin tekstitila. Muistikartassa ei tapahdu
muutoksia grafiikkatilaan siirryttäessä.

---

## 4. Tila A — Tekstitila (nykytila)

Tekstitila on kCPU16:n oletustila. Se ei ole varsinainen pikseligrafiikkatila,
mutta se toimii lähtökohtana muille tiloille ja käyttää samaa VRAM-aluetta.

- **Resoluutio**: 80 × 24 merkkiä
- **VRAM**: $F800–$FF7F (1 920 sanaa)
- **VRAM-sanan rakenne**:

```
Bitti 15–14: Attribuutit (vilkkuminen ym.)
Bitti 13–11: BG-väri (3 bittiä, 8 väriä)
Bitti 10–8:  FG-väri (3 bittiä, 8 väriä)
Bitti  7–0:  Merkki (ASCII/CP437)
```

Tekstitilassa näyttötilarekisterin ($FF80) arvo on **0**.

---

## 5. Tila B — Puoliblokkipikseli (80 × 48)

### 5.1 Perusteet

Puoliblokkipikseli-tila jakaa jokaisen merkkiruudun kahteen pikseliriviin
käyttämällä Unicode-puoliblokkiruutuja (`▀`, `▄`, `█`, ` `). Moodi on
**yksiväriinen**: jokainen pikseli on 1-bittinen (päällä tai pois).

- **Resoluutio**: 80 × 48 pikseliä
- **Värisyvyys**: 1 bitti per pikseli
- **VRAM-tarve**: 1 920 sanaa (sama alue $F800–$FF7F kuin tekstitilassa)

### 5.2 VRAM-sanan rakenne (tila B)

Jokainen VRAM-sana koodaa yhden merkkiruudun (yksi sarake, kaksi pikseliriviä):

```
Bitti 15–2:  Käyttämättä (ignoroidaan)
Bitti 1:     Ylempi pikseli  (1 = päällä, 0 = pois)
Bitti 0:     Alempi pikseli  (1 = päällä, 0 = pois)
```

Osoitekaava (sama kuin tekstitilassa):

```
osoite = $F800 + (pikselirivi // 2) * 80 + sarake
```

Esimerkki: pikseli (sarake=10, pikselirivi=5) → ylemmässä puoliskossa:

```
osoite = $F800 + (5 // 2) * 80 + 10 = $F800 + 2 * 80 + 10 = $F90A
bitti  = 1   (rivi 5 on pariton → alempi pikseli → bitti 0)
```

### 5.3 Assembly-esimerkki: pikselin asettaminen

```asm
; Aseta piste (sarake=10, pikselirivi=4) päälle
; Rivi 4 on parillinen → ylempi pikseli → bitti 1
LOAD R1, #0xF90A    ; osoite = F800 + 2*80 + 10
LOAD R2, [R1]       ; lue nykyinen sana
OR   R2, #0x0002    ; aseta bitti 1 (ylempi pikseli)
STORE R2, [R1]

; Aseta piste (sarake=10, pikselirivi=5) päälle
; Rivi 5 on pariton → alempi pikseli → bitti 0
LOAD R1, #0xF90A    ; sama VRAM-sana
LOAD R2, [R1]       ; lue nykyinen sana
OR   R2, #0x0001    ; aseta bitti 0 (alempi pikseli)
STORE R2, [R1]
```

### 5.4 Tilakytkin

Näyttötilarekisteri `$FF80` asetetaan arvoon **1**:

```asm
LOAD R0, #1
LOAD R1, #0xFF80    ; näyttötilarekisteri
STORE R0, [R1]      ; kytke puoliblokkipikseli-tila päälle
```

### 5.5 TUI-widgetin toiminta (tila B)

`ScreenDevice`-widget lukee VRAM-sanoista bitit 1 ja 0 ja valitsee
sopivan puoliblokkimerkin:

| Bitti 1 (ylempi) | Bitti 0 (alempi) | Merkki | Selitys              |
| ---------------- | ---------------- | ------ | -------------------- |
| 0                | 0                | ` `    | Molemmat pois        |
| 1                | 0                | `▀`    | Vain ylempi päällä   |
| 0                | 1                | `▄`    | Vain alempi päällä   |
| 1                | 1                | `█`    | Molemmat päällä      |

---

## 6. Tila C — Braille (160 × 96)

### 6.1 Perusteet

Braille-tila käyttää Unicode-braille-merkkejä (U+2800–U+28FF) koodaamaan
2 × 4 pikselin ruudukon yhdeksi merkkiruuduksi. Jokainen piste on 1-bittinen
(päällä tai pois), joten yhdessä VRAM-sanassa on 8 pikselibittiä.

- **Resoluutio**: 160 × 96 pikseliä
- **Värisyvyys**: 1 bitti per pikseli
- **VRAM-tarve**: 1 920 sanaa (sama alue $F800–$FF7F kuin tekstitilassa)
- **Merkkiruudun koko**: 2 pikseliä leveyttä × 4 pikseliä korkeutta

### 6.2 Braille-pisteiden numerointi ja bittijärjestys

Unicode-braille-standardi numeroi pisteet seuraavasti:

```
Sarake → 0    1
        ┌────┬────┐
Rivi 0  │ 1  │ 4  │
        ├────┼────┤
Rivi 1  │ 2  │ 5  │
        ├────┼────┤
Rivi 2  │ 3  │ 6  │
        ├────┼────┤
Rivi 3  │ 7  │ 8  │
        └────┴────┘
```

Unicode-merkin koodi: `U+2800 + bittikuvio`, jossa:

```
Bitti 0 = piste 1  (sarake 0, rivi 0)
Bitti 1 = piste 2  (sarake 0, rivi 1)
Bitti 2 = piste 3  (sarake 0, rivi 2)
Bitti 3 = piste 4  (sarake 1, rivi 0)
Bitti 4 = piste 5  (sarake 1, rivi 1)
Bitti 5 = piste 6  (sarake 1, rivi 2)
Bitti 6 = piste 7  (sarake 0, rivi 3)
Bitti 7 = piste 8  (sarake 1, rivi 3)
```

### 6.3 VRAM-sanan rakenne (tila C)

Jokainen VRAM-sana koodaa yhden braille-merkkiruudun (2 × 4 pikseliä):

```
Bitti 15–8:  Käyttämättä (ignoroidaan)
Bitti 7–0:   Braille-bittikuvio (8 pikseliä, 1 bitti kukin)
```

VRAM-sanan bitti → pikselikoordinaatti (`(sarake, rivi)` merkkiruudun sisällä):

| Bitti | Piste | Merkkiruudun sarake | Merkkiruudun rivi |
| ----- | ----- | ------------------- | ----------------- |
| 0     | 1     | 0                   | 0                 |
| 1     | 2     | 0                   | 1                 |
| 2     | 3     | 0                   | 2                 |
| 3     | 4     | 1                   | 0                 |
| 4     | 5     | 1                   | 1                 |
| 5     | 6     | 1                   | 2                 |
| 6     | 7     | 0                   | 3                 |
| 7     | 8     | 1                   | 3                 |

Pikseli `(px, py)` (0 ≤ px < 160, 0 ≤ py < 96) kartoitetaan VRAM:iin:

```
merkkiruudun sarake  = px // 2
merkkiruudun rivi    = py // 4
piste-sarake         = px mod 2
piste-rivi           = py mod 4

osoite = $F800 + merkkiruudun_rivi * 80 + merkkiruudun_sarake

bittinumero (pisterivin 0–2 mukaan):
  jos piste-rivi < 3:  bitti = piste-sarake * 3 + piste-rivi
  jos piste-rivi = 3:  bitti = 6 + piste-sarake
```

### 6.4 Assembly-esimerkki: pikselin asettaminen

```asm
; Aseta pikseli (px=5, py=7) päälle
; Merkkiruudun sarake = 5 // 2 = 2
; Merkkiruudun rivi   = 7 // 4 = 1
; Piste-sarake = 5 mod 2 = 1
; Piste-rivi   = 7 mod 4 = 3
; → piste-rivi = 3, piste-sarake = 1 → bitti = 6 + 1 = 7

LOAD R1, #0xF852    ; osoite = F800 + 1*80 + 2
LOAD R2, [R1]       ; lue nykyinen sana
OR   R2, #0x0080    ; aseta bitti 7  (1 << 7)
STORE R2, [R1]
```

### 6.5 Tilakytkin

Näyttötilarekisteri `$FF80` asetetaan arvoon **2**:

```asm
LOAD R0, #2
LOAD R1, #0xFF80    ; näyttötilarekisteri
STORE R0, [R1]      ; kytke braille-tila päälle
```

### 6.6 TUI-widgetin toiminta (tila C)

`ScreenDevice`-widget lukee VRAM-sanan alemman tavun (bitit 7–0) ja
muodostaa braille-merkin:

```python
braille_char = chr(0x2800 + (vram_word & 0xFF))
```

---

## 7. Näyttötilarekisteri ($FF80)

Kaikki tilat valitaan kirjoittamalla muistiosoitteeseen `$FF80`:

| Arvo | Tila                         | Resoluutio        |
| ---- | ---------------------------- | ----------------- |
| 0    | A — Tekstitila (oletustila)  | 80 × 24 merkkiä   |
| 1    | B — Puoliblokkipikseli       | 80 × 48 pikseliä  |
| 2    | C — Braille                  | 160 × 96 pikseliä |

Textual-widget tarkistaa tämän osoitteen `refresh()`-kutsun yhteydessä ja
valitsee renderöintitavan sen mukaan. Muistikartassa ei tapahdu muutoksia
tilaa vaihdettaessa — kaikki tilat käyttävät samaa VRAM-aluetta $F800–$FF7F.

---

## 8. Yhteenveto

| Kriteeri              | A — Tekstitila     | B — Puoliblokkipikseli | C — Braille          |
| --------------------- | ------------------ | ---------------------- | -------------------- |
| Resoluutio            | 80 × 24 merkkiä    | 80 × 48 pikseliä       | 160 × 96 pikseliä    |
| Värisyvyys/pikseli    | 8 FG + 8 BG        | 1 bitti                | 1 bitti              |
| VRAM-tarve            | 1 920 sanaa        | 1 920 sanaa            | 1 920 sanaa          |
| Muistikarttamuutos    | —                  | Ei                     | Ei                   |
| ISA-muutos            | —                  | Ei                     | Ei                   |
| Näyttötilarekisteri   | $FF80 = 0          | $FF80 = 1              | $FF80 = 2            |
| Unicode-tekniikka     | ASCII/CP437        | ▀ ▄ █ (U+2580–U+2588)  | U+2800–U+28FF        |
| Pikseleitä/merkkiruutu| 1 merkki           | 2 (1 × 2)              | 8 (2 × 4)            |
| Toteutuksen monimutkaisuus | Käytössä      | Matala                 | Kohtalainen          |

Kaikki kolme tilaa käyttävät täsmälleen samaa 1 920 sanan VRAM-aluetta
($F800–$FF7F). Tilan valinta tapahtuu yksinomaan näyttötilarekisterin
(`$FF80`) arvolla ilman muistikarttamuutoksia tai uusia konekielen käskyjä.
Grafiikkatilat B ja C ovat **yksivärisisiä**: jokainen pikseli on 1-bittinen
(päällä tai pois).

