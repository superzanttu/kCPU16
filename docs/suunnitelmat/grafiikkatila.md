# kCPU16 — Grafiikkatila Textual-kirjaston rajoissa

Versio 2.0

---

## 1. Johdanto

kCPU16 käyttää käyttöliittymänään Textual-kirjastoa (Python), joka on
tekstipohjaisen terminaalikäyttöliittymän (TUI) rakennuskirjasto. Se perustuu
Rich-kirjastoon ja toimii täysin terminaalissa — ei ikkunajärjestelmässä eikä
graafisessa ympäristössä.

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

---

## 2. Textual-kirjaston grafiikkamahdollisuudet

### 2.1 Terminaalin perusyksikkö: merkkiruutu

Kaikki Textual-renderöinti perustuu **terminaalin merkkiruutuihin** (character
cell). Yksi ruutu vastaa yhtä merkkiä — tyypillisesti 8×16 pikseliä
fonttiriippuvaisesti. Näytöllä ruudut on järjestetty riveittäin.

kCPU16:n näyttö on 80×24 merkkiruutua.

### 2.2 Pikseliemulointitekniikat

Koska terminaali perustuu merkkeihin, "pikselit" emuloidaan erityisillä
Unicode-merkeillä. kCPU16:ssa käytetään kahta tekniikkaa:

#### Tila B: Puoliblokkiruudut (half-block)

| Merkki | Koodipiste | Kuvaus                   |
| ------ | ---------- | ------------------------ |
| `▀`    | U+2580     | Ylempi puolikas täynnä   |
| `▄`    | U+2584     | Alempi puolikas täynnä   |
| `█`    | U+2588     | Koko ruutu täynnä        |
| ` `    | U+0020     | Tyhjä ruutu              |

Käyttämällä `▀`-, `▄`-, `█`- tai ` `-merkkiä saadaan **2 pikseliä per
merkkiruutu pystysuunnassa** (ylempi ja alempi puolikas itsenäisinä bitteinä):

```
80 merkkiä × 24 riviä × 2 pikseliä/rivi = 80 × 48 pikseliä
```

Koska tilat ovat yksivärisiä (1 bitti/pikseli), ylempi puolikas on joko täynnä
tai tyhjä ja samoin alempi — yhteensä neljä yhdistelmää vastaavat neljää eri
merkkiä (` `, `▀`, `▄`, `█`).

#### Tila C: Braille-pisteet

Unicode braille -alue U+2800–U+28FF sisältää 256 merkkiä, joissa jokainen
vastaa 2×4 pikselipiirrettä (8 bittiä, kukin bitti = yksi piste):

```
80 × 2 = 160 pikseliä leveyttä
24 × 4 = 96 pikseliä korkeutta
→ 160 × 96 pikseliä (1 bitti/pikseli; 8 pikseliä per merkkiruutu)
```

Jokainen braille-merkki koodaa 2×4 pisteistön, jossa kukin piste on
yksittäinen bitti (päällä/pois).

### 2.3 Textualin renderöintimekanismi

Mukautettu grafiikkawidget toteutetaan ylikirjoittamalla `render_line(y)`
-metodi `Widget`-luokan aliluokassa. Metodi palauttaa `Strip`-olion, joka
koostuu `Segment`-olioista (teksti + tyyli):

```python
from textual.widget import Widget
from textual.strip import Strip
from rich.segment import Segment
from rich.style import Style

# Käytettävät tyylit yksivärisissä tiloissa
PIXEL_ON  = Style(color="white", bgcolor="black")   # pikseli päällä
PIXEL_OFF = Style(color="black", bgcolor="black")   # pikseli pois
# Käyttö: segments.append(Segment(char, PIXEL_ON if pixel else PIXEL_OFF))
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

## 4. Tila B: Puoliblokkipikseli (80 × 48)

### 4.1 Perusteet

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

---

## 8. Yhteenveto

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

