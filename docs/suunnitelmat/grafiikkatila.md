# kCPU16 — Grafiikkatila Textual-kirjaston rajoissa

Versio 2.0

---

## 1. Johdanto

kCPU16 käyttää käyttöliittymänään Textual-kirjastoa (Python), joka on
tekstipohjaisen terminaalikäyttöliittymän (TUI) rakennuskirjasto. Se perustuu
Rich-kirjastoon ja toimii täysin terminaalissa — ei ikkunajärjestelmässä eikä
graafisessa ympäristössä.

<<<<<<< HEAD
kCPU16:ssa on kolme näyttötilaa:

| Tila | Kuvaus | Resoluutio |
| ---- | ------ | ---------- |
| **A) Tekstitila** | Nykyinen tila — 80×24 ASCII-merkkiä väreillä | 80 × 24 merkkiä |
| **B) Puoliblokkipikseli** | Yksiväriset pikselit half-block-merkeillä | 80 × 48 pikseliä |
| **C) Braille-pikseli** | Yksiväriset pisteet braille-merkeillä | 160 × 96 pikseliä |

Kaikki grafiikkatilat (B ja C) ovat **yksivärisiä**: yksi bitti per pikseli
(pikseli on joko päällä tai pois). Värituki kuuluu vain tekstitilaan (A).

Tässä suunnitelmassa kuvataan kaikkien kolmen tilan VRAM-rakenne,
tilakytkinrekisteri sekä Textual-toteutus.
=======
Tässä suunnitelmassa määritellään kCPU16:n grafiikkatilat. Käytettävissä on
**kolme tilaa**, joista kaikki ovat **yksiväriseen** (monochrome) pikselikoodaukseen
perustuvia: jokaiseen pikseliin käytetään **yksi bitti** (päällä/pois).

| Tunniste | Nimi                  | Resoluutio       | Pikseleitä/merkkiruutu |
| -------- | --------------------- | ---------------- | ---------------------- |
| **A**    | Tekstitila (nykytila) | 80 × 24 merkkiä  | 1 merkki               |
| **B**    | Puoliblokkipikseli    | 80 × 48 pikseliä | 2 (1 bitti/pikseli)    |
| **C**    | Braille               | 160 × 96 pikseliä| 8 (1 bitti/pikseli)    |
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

---

## 2. Textual-kirjaston grafiikkamahdollisuudet

### 2.1 Terminaalin perusyksikkö: merkkiruutu

Kaikki Textual-renderöinti perustuu **terminaalin merkkiruutuihin** (character
cell). Yksi ruutu vastaa yhtä merkkiä — tyypillisesti 8×16 pikseliä
fonttiriippuvaisesti. Näytöllä ruudut on järjestetty riveittäin.

kCPU16:n näyttö on 80×24 merkkiruutua.

<<<<<<< HEAD
### 2.2 Pikseliemulointitekniikat
=======
### 2.2 Värituki

Kaikki kCPU16:n grafiikkatilat ovat **yksivärisisiä (monochrome)**: jokainen
pikseli esitetään **yhdellä bitillä** (1 = päällä, 0 = pois). Värisyvyys on
siis 1 bitti per pikseli — ei väripalettia, ei RGB-arvoja.

Renderöinnissä "päällä"-pikseli näytetään edustusvärinä (FG, esim. valkoinen)
ja "pois"-pikseli taustavärinä (BG, esim. musta). Värit ovat Textualin ANSI-tasolla
asetettavia vakioarvoja, eivät ohjelmoijan säädeltävissä olevia attribuutteja.

### 2.3 Pikseliemulointitekniikat
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

Koska terminaali perustuu merkkeihin, "pikselit" emuloidaan erityisillä
Unicode-merkeillä. kCPU16:ssa käytetään kahta tekniikkaa:

<<<<<<< HEAD
#### Tila B: Puoliblokkiruudut (half-block)
=======
#### B) Puoliblokkiruudut (half-block)
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

| Merkki | Koodipiste | Kuvaus                   |
| ------ | ---------- | ------------------------ |
| `▀`    | U+2580     | Ylempi puolikas täynnä   |
| `▄`    | U+2584     | Alempi puolikas täynnä   |
| `█`    | U+2588     | Koko ruutu täynnä        |
| ` `    | U+0020     | Tyhjä ruutu              |

<<<<<<< HEAD
Käyttämällä `▀`-, `▄`-, `█`- tai ` `-merkkiä saadaan **2 pikseliä per
merkkiruutu pystysuunnassa** (ylempi ja alempi puolikas itsenäisinä bitteinä):
=======
Käyttämällä sopivaa puoliblokkimerkkiä edustusvärillä (FG) ja taustavärillä
(BG) saadaan **2 pikseliä per merkkiruutu pystysuunnassa**:
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

```
80 merkkiä × 24 riviä × 2 pikseliä/rivi = 80 × 48 pikseliä
```

<<<<<<< HEAD
Koska tilat ovat yksivärisiä (1 bitti/pikseli), ylempi puolikas on joko täynnä
tai tyhjä ja samoin alempi — yhteensä neljä yhdistelmää vastaavat neljää eri
merkkiä (` `, `▀`, `▄`, `█`).

#### Tila C: Braille-pisteet
=======
Jokainen pikseli on 1-bittinen (päällä / pois).

#### C) Braille-pisteet
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

Unicode braille -alue U+2800–U+28FF sisältää 256 merkkiä, joissa jokainen
vastaa 2×4 pikselipiirrettä (8 bittiä, kukin bitti = yksi piste):

```
80 × 2 = 160 pikseliä leveyttä
24 × 4 = 96 pikseliä korkeutta
<<<<<<< HEAD
→ 160 × 96 pikseliä (1 bitti/pikseli; 8 pikseliä per merkkiruutu)
```

Jokainen braille-merkki koodaa 2×4 pisteistön, jossa kukin piste on
yksittäinen bitti (päällä/pois).

### 2.3 Textualin renderöintimekanismi
=======
→ 160 × 96 pikseliä (1-bittinen; yksi päällä/pois-pikseli per piste)
```

Jokainen pikseli on 1-bittinen (päällä / pois).

### 2.4 Textualin renderöintimekanismi
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

Mukautettu grafiikkawidget toteutetaan ylikirjoittamalla `render_line(y)`
-metodi `Widget`-luokan aliluokassa. Metodi palauttaa `Strip`-olion, joka
koostuu `Segment`-olioista (teksti + tyyli):

```python
from textual.widget import Widget
from textual.strip import Strip
from rich.segment import Segment
from rich.style import Style

<<<<<<< HEAD
# Käytettävät tyylit yksivärisissä tiloissa
PIXEL_ON  = Style(color="white", bgcolor="black")   # pikseli päällä
PIXEL_OFF = Style(color="black", bgcolor="black")   # pikseli pois
# Käyttö: segments.append(Segment(char, PIXEL_ON if pixel else PIXEL_OFF))
=======
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
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70
```

Tämä on Textualin suosittelema tapa toteuttaa matalan tason pikselijärjestelmä.
`render_line()` kutsutaan kerran per näkyvä rivi ja vain tarvittaessa
(vain likatut alueet piirretään uudelleen).

---

## 3. Tilojen vertailu

| Tila | Resoluutio | Värisyvyys | VRAM-tarve (sanat) | Pikseleitä/sana |
| ---- | ---------- | ---------- | ------------------ | --------------- |
| **A) Tekstitila** | 80 × 24 merkkiä | 8 FG + 8 BG | 1 920 | — |
| **B) Puoliblokkipikseli** | 80 × 48 | 1 bitti/pikseli | 240 | 16 |
| **C) Braille** | 160 × 96 | 1 bitti/pikseli | 960 | 16 |

Kaikki grafiikkatilat käyttävät pienen VRAM-alueen — molemmat mahtuvat
nykyisen VRAM-alueen sisään ($F800–$FF7F = 1 920 sanaa).

---

<<<<<<< HEAD
## 4. Tila B: Puoliblokkipikseli (80 × 48)
=======
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
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

Tekstitila on kCPU16:n oletustila. Se ei ole varsinainen pikseligrafiikkatila,
mutta se toimii lähtökohtana muille tiloille ja käyttää samaa VRAM-aluetta.

<<<<<<< HEAD
Puoliblokkipikseli-tila on yksinkertaisin grafiikkatila kCPU16:ssa:

1. **Monokromaattinen**: Yksi bitti per pikseli — pikseli on joko päällä (1)
   tai pois (0). Värejä ei ole.

2. **Kaksinkertainen pystyresoluutio**: 80×48 pikseliä mahdollistaa
   yksinkertaisten kuvioiden, pisteiden, viivojen ja täytettyjen alueiden
   piirtämisen.

3. **Pieni VRAM-jalanjälki**: 80×48 = 3 840 pikseliä / 16 pikseliä per sana
   = **240 sanaa** VRAM-tilaa.

4. **Yksinkertainen toteutus**: 16 pikseliä pakataan yhteen 16-bittiseen sanaan.
   Bitit luetaan vasemmalta oikealle.

### 4.2 VRAM-sanan rakenne (tila B)

Yksi 16-bittinen sana kattaa 16 vierekäistä pikseliä samalla rivillä:

```
Bitti 15: pikseli 0 (vasemmanpuoleisin)
Bitti 14: pikseli 1
...
Bitti  0: pikseli 15 (oikeanpuoleisin)
```

Osoitekaava — pikseli `(x, y)` sijaitsee:

```
sanaindeksi = y * 5 + x // 16
bitti       = 15 - (x mod 16)
osoite      = VRAM_GFX_B_START + sanaindeksi
```

missä `VRAM_GFX_B_START` on tilan B grafiikka-VRAM:n alku (esim. `$F800`).

VRAM-tarve: 48 riviä × 5 sanaa/rivi = 240 sanaa.

### 4.3 Pikselin asetus assembly-koodissa (tila B)

Esimerkki: aseta pikseli `(x=10, y=5)` päälle.

```
sanaindeksi = 5 * 5 + 10 // 16 = 25 + 0 = 25
bitti       = 15 - (10 mod 16) = 15 - 10 = 5
osoite      = $F800 + 25 = $F819
```

```asm
; Aseta pikseli (x=10, y=5) päälle tilassa B
LOAD  R1, #0xF819       ; VRAM-osoite
LOAD  R0, [R1]          ; lue nykyinen sana
OR    R0, #0x0020       ; aseta bitti 5 (= 1 << 5)
STORE R0, [R1]          ; kirjoita takaisin
```

Pikselin nollaus: käytä `AND`-käskyllä käänteistä maskia (`AND R0, #0xFFDF`).

### 4.4 TUI-renderöinti (tila B)

```python
# Half-block-merkit: (ylempi_bitti, alempi_bitti) → merkki
HALF_BLOCK = {(0, 0): " ", (1, 0): "▀", (0, 1): "▄", (1, 1): "█"}

class HalfBlockScreen(Widget):
    def render_line(self, y: int) -> Strip:
        segments = []
        for x in range(80):
            # Ylempi pikselirivi y*2, alempi y*2+1 — eri VRAM-sanat
            word_top = self._mem_read(0xF800 + (y * 2)     * 5 + x // 16)
            word_bot = self._mem_read(0xF800 + (y * 2 + 1) * 5 + x // 16)
            top = (word_top >> (15 - x % 16)) & 1
            bot = (word_bot >> (15 - x % 16)) & 1
            char = HALF_BLOCK[(top, bot)]
            segments.append(Segment(char, PIXEL_ON if (top or bot) else PIXEL_OFF))
        return Strip(segments)
```

---

## 5. Tila C: Braille-pikseli (160 × 96)

### 5.1 Perusteet

Braille-tila tarjoaa kCPU16:n korkearesoluutioisimman grafiikkatilan:

1. **Monokromaattinen**: Yksi bitti per piste — jokainen piste on joko
   päällä (1) tai pois (0). Värejä ei ole.

2. **Korkein resoluutio**: 160×96 pikseliä (braille-pisteet) mahdollistaa
   yksityiskohtaisempien kuvioiden piirtämisen kuin tila B.

3. **Braille-merkkien rakenne**: Jokainen merkki kattaa 2×4 pistettä (8 bittiä).
   Unicode-braille-alue U+2800–U+28FF sisältää 256 merkkiä kaikille
   yhdistelmille.

4. **VRAM-tarve**: 80 × 24 merkkiruutua × 8 bittiä/ruutu = 15 360 bittiä
   = 15 360 pikseliä = 160 × 96. Sanoja tarvitaan: 15 360 / 16 = **960 sanaa**.

### 5.2 Braille-pisteistön bittijärjestys

Unicode-standardin braille-pisteiden numerointi (U+2800-alue):

```
Pisteistö per merkkiruutu (2 saraketta × 4 riviä):

  sarake 0  sarake 1
  ┌──────┬──────┐
  │  p1  │  p4  │   rivi 0
  │  p2  │  p5  │   rivi 1
  │  p3  │  p6  │   rivi 2
  │  p7  │  p8  │   rivi 3
  └──────┴──────┘

Unicode-bittijärjestys: bitti 0=p1, bitti 1=p2, bitti 2=p3,
                        bitti 3=p4, bitti 4=p5, bitti 5=p6,
                        bitti 6=p7, bitti 7=p8
```

Merkki muodostetaan: `U+2800 + bittikuvio`

### 5.3 VRAM-sanan rakenne (tila C)

Yksi 16-bittinen sana kattaa kaksi vierekkäistä braille-merkkiruutua:

```
Bitti 15–8: oikea merkkiruutu (parillinen col+1; 8 braille-bittiä, pisteet p1–p8)
Bitti  7–0: vasen merkkiruutu (parillinen col;   8 braille-bittiä, pisteet p1–p8)
```

Osoitekaava — braille-merkkiruutu `(col, row)` (col = 0..79, row = 0..23):

```
sanaindeksi  = row * 40 + col // 2
bitti_siirto = (col mod 2) * 8      ; 0 = vasen ruutu (bitit 7-0), 8 = oikea ruutu (bitit 15-8)
osoite = VRAM_GFX_C_START + sanaindeksi
```

Pikseli `(px, py)` (px = 0..159, py = 0..95) → braille-piste:

```
col      = px // 2           ; merkkiruudun sarake (0..79)
pisteX   = px mod 2          ; pisteen x-asema ruudussa (0 tai 1)
row      = py // 4           ; merkkiruudun rivi (0..23)
pisteY   = py mod 4          ; pisteen y-asema ruudussa (0..3)

; Braille-bitin indeksi pisteiden p1..p8 mukaan:
; pisteX=0: bitit 0,1,2,6 (pisteY=0,1,2,3)
; pisteX=1: bitit 3,4,5,7 (pisteY=0,1,2,3)
BITTI_TAULU = [[0,1,2,6], [3,4,5,7]]
braille_bitti = BITTI_TAULU[pisteX][pisteY]

sanaindeksi  = row * 40 + col // 2
bitti_siirto = (col mod 2) * 8 + braille_bitti
osoite       = VRAM_GFX_C_START + sanaindeksi
```

VRAM-tarve: 24 riviä × 40 sanaa/rivi = 960 sanaa.

### 5.4 Pikselin asetus assembly-koodissa (tila C)

Esimerkki: aseta pikseli `(px=3, py=5)` päälle.

```
col       = 3 // 2 = 1
pisteX    = 3 mod 2 = 1
row       = 5 // 4 = 1
pisteY    = 5 mod 4 = 1
→ braille_bitti = BITTI_TAULU[1][1] = 4
→ sanaindeksi   = 1 * 40 + 1 // 2 = 40 + 0 = 40
→ bitti_siirto  = (1 mod 2) * 8 + 4 = 8 + 4 = 12
→ osoite        = $F800 + 40 = $F828
→ maskibitti    = 1 << 12 = 0x1000
```

```asm
; Aseta pikseli (px=3, py=5) päälle tilassa C
LOAD  R1, #0xF828       ; VRAM-osoite
LOAD  R0, [R1]          ; lue nykyinen sana
OR    R0, #0x1000       ; aseta bitti 12
STORE R0, [R1]          ; kirjoita takaisin
```

### 5.5 TUI-renderöinti (tila C)

```python
class BrailleScreen(Widget):
    # Braille-bitin indeksi: [pisteX][pisteY]
    BRAILLE_BIT = [[0, 1, 2, 6], [3, 4, 5, 7]]

    def render_line(self, y: int) -> Strip:
        # y = terminaalirivi 0..23; yksi rivi = 4 braille-pikseliriviä
        segments = []
        for col in range(80):
            word_addr = 0xF800 + y * 40 + col // 2
            word = self._mem_read(word_addr)
            byte_shift = (col % 2) * 8
            braille_byte = (word >> byte_shift) & 0xFF
            char = chr(0x2800 + braille_byte)
            segments.append(Segment(char))
        return Strip(segments)
```

---

## 6. Tilakytkinrekisteri (GMODE)

### 6.1 GMODE-rekisteri ($FF80)

Näyttötila valitaan kirjoittamalla arvo muistiosoitteeseen `$FF80`:

| Arvo | Tila | Kuvaus |
| ---- | ---- | ------ |
| `0`  | **A) Tekstitila** | 80×24 ASCII-merkkiä väreillä (nykyinen) |
| `1`  | **B) Puoliblokkipikseli** | 80×48 yksiväristä pikseliä |
| `2`  | **C) Braille** | 160×96 yksiväristä pikseliä |

### 6.2 Assembly-esimerkit tilanvaihdosta

```asm
; Kytke puoliblokkipikseli-tila päälle (B)
LOAD  R0, #1
STORE R0, [$FF80]

; Kytke braille-tila päälle (C)
LOAD  R0, #2
STORE R0, [$FF80]

; Palaa tekstitilaan (A)
LOAD  R0, #0
STORE R0, [$FF80]
```

Textual-widget tarkistaa GMODE-rekisterin `refresh()`-kutsun yhteydessä
ja valitsee renderöintitavan sen mukaan.

### 6.3 TUI-widgetin toiminta

`ScreenDevice`-widget tarkistaa tilarekisterin ennen renderöintiä:

- **Tekstitila** (GMODE = 0): `render_text_mode()` — ASCII-merkit väreillä.
- **Puoliblokkipikseli** (GMODE = 1): `render_half_block_mode()` — `▀`/`▄`/`█`/` `-merkit VRAM-biteistä.
- **Braille** (GMODE = 2): `render_braille_mode()` — U+2800–U+28FF-merkit VRAM-biteistä.

---

## 7. Muistikartta

```
$0000 – $0008   9 sanaa       Keskeytysvektoritaulukko (ennallaan)
$0009 – $00FF   247 sanaa     Käyttöjärjestelmän varaus
$0100 – $01FF   256 sanaa     Bootloader
$0200 – $F7FF   61 952 sanaa  Vapaa RAM (ohjelmakoodi ja data)
$F800 – $F8EF   240 sanaa     Grafiikka-VRAM tila B (80 × 48 pikseliä, 1 bitti/pikseli)
$F800 – $FBBF   960 sanaa     Grafiikka-VRAM tila C (160 × 96 pikseliä, 1 bitti/pikseli)
$F800 – $FF7F   1 920 sanaa   VRAM tekstitilassa — ennallaan
$FF80           1 sana        GMODE-rekisteri (0=teksti, 1=half-block, 2=braille)
$FF81 – $FFFF   127 sanaa     Kernel-pino
```

**Huomio:** Tilat B ja C käyttävät VRAM-alueen alkupäätä ($F800 alkaen).
Tila B tarvitsee 240 sanaa, tila C 960 sanaa — molemmat mahtuvat
nykyisen VRAM-alueen ($F800–$FF7F) sisään ilman muistikarttamuutoksia.
=======
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
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

---

## 8. Yhteenveto

<<<<<<< HEAD
| Kriteeri | A) Tekstitila | B) Puoliblokkipikseli | C) Braille |
| -------- | ------------- | --------------------- | ---------- |
| Resoluutio | 80 × 24 merkkiä | 80 × 48 pikseliä | 160 × 96 pikseliä |
| Värisyvyys | 8 FG + 8 BG | **1 bitti/pikseli** | **1 bitti/pikseli** |
| VRAM-tarve | 1 920 sanaa | **240 sanaa** | **960 sanaa** |
| Pikseleitä/sana | — | 16 | 16 |
| Merkki/ruutu | ASCII + attribuutit | ▀/▄/█/välilyönti | U+2800–U+28FF |
| GMODE-arvo | 0 | 1 | 2 |
| ISA-muutos | Ei | Ei | Ei |

Kaikki kolme tilaa ohjaavat samaa näyttöaluetta ja vaihtuvat GMODE-rekisterin
($FF80) arvon perusteella. Grafiikkatilat B ja C ovat täysin yksivärisiä
(1 bitti/pikseli) — värituki on vain tekstitilassa A. Mikään tila ei vaadi
uusia konekielen käskyjä; ohjaus tapahtuu tavallisilla `LOAD`/`STORE`-käskyillä.
=======
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
>>>>>>> a16c3782ccbb784cfca458c2ecc036e88c730c70

