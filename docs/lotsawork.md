# lotsawork

## 1) Mikä projekti on ja mitä se tekee

kCPU16 on Pythonilla toteutettu 16-bittinen CPU-emulaattori. Projekti sisältää virtuaalisen suorittimen, assemblerin, disassemblerin, muistimallin, laitemallin (näyttö, näppäimistö, tallennus), testiympäristön sekä Textual-pohjaisen TUI-käyttöliittymän ohjelmien ajamiseen ja debuggaamiseen.

## 2) Projektin tekninen laajuus (snapshot)

Alla olevat luvut on kerätty repositorion nykytilasta (git + tiedostolaskenta):

- Committeja: **263**
- Tiedostoja (git-tracked): **272**
- Pull requesteja (GitHub, yhteensä): **49**
- Kokonaisrivimäärä (tracked tiedostot): **40 262**
- Pääkielet tiedostomäärällä:
  - `.asm`: **200 tiedostoa**
  - `.py`: **38 tiedostoa**
  - `.md`: **16 tiedostoa**
- Pääkielet rivimäärällä:
  - Assembly (`.asm`): **20 197 riviä**
  - Python (`.py`): **13 121 riviä**
  - Markdown (`.md`): **5 512 riviä**
- Kirjastot:
  - Selkeä ulkoinen runtime-riippuvuus: **Textual** (`pip install textual`)
  - Muut osat nojaavat pääosin Pythonin standardikirjastoon sekä projektin omaan koodiin.

## 3) Kuinka paljon tekoälystä on ollut hyötyä

Arvio: tekoälystä on ollut tässä projektityypissä **merkittävä hyöty** (noin **30–50 %** ajansäästö) erityisesti:

- laajan ISA- ja laitekäyttäytymisen dokumentoinnissa
- testitapausten luonnissa ja laajentamisessa
- toisteisen koodin sekä refaktorointien nopeuttamisessa
- virheiden paikannuksessa (esim. edge case -polut)

Suurin hyöty syntyy siis toteutuksen nopeudesta ja dokumentaation/testauksen skaalauksesta, ei niinkään siitä, että arkkitehtuurinen vastuu siirtyisi pois kehittäjältä.

## 4) Aika-arvio: tekoälyllä vs. ilman tekoälyä

Tämä on karkea arvio koko projektin kaltaiselle toteutukselle.

- Toteutus tekoälyn avulla: **~120–220 tuntia**

Ilman tekoälyä:

- a) Harrastelija (Python-perusteet): **~700–1200 tuntia**
- b) Keskiverto ohjelmoija: **~350–650 tuntia**
- c) Ammattilaisohjelmoija: **~200–380 tuntia**
- d) Mestariohjelmoija: **~120–240 tuntia**

Huomio: vaihtelu on suuri, koska työmäärään vaikuttavat mm. testauksen syvyys, dokumentaation laatuvaatimukset, arkkitehtuurin muutokset sekä käyttöliittymän viimeistely.

## 5) Mitä teknisiä taitoja projekti vaatii

Projektin onnistunut toteutus vaatii yhdistelmän ohjelmisto- ja järjestelmätason osaamista:

- **Ohjelmointitekniikka**: modulaarinen suunnittelu, rajapinnat, refaktorointi, virheenkäsittely
- **Python-osaaminen**: datamallit, tilakoneajattelu, testaus, CLI/TUI-rakenteet
- **Tietokonearkkitehtuuri**: rekisterit, ALU-logiikka, liput (Z/N/C/V), keskeytykset, privilege-tilat
- **Assembler/ISA-suunnittelu**: käskyformaatti, osoitusmuodot, assemblerin passit, label-resoluutio
- **Muisti- ja laitemallinnus**: MMIO, muistinsuojaus, emuloidut laitteet ja niiden protokollat
- **Debuggaus ja verifiointi**: edge caset, regressiot, laaja testikattavuus
- **Dokumentointi**: arkkitehtuurin, käskykannan ja käyttöohjeiden selkeä kuvaus

## 6) Käytetty prompti (esimerkki)

Luo docs-hakemistoon dokumentti lotsawork.md, jossa kerrot seuraavista asioista selkeästi ja loogisesti.
- Kerro alussa lyhyesti mistä projektissa on kyse ja mitä se tekee.
- Kerro tämän projektin laajuus teknisesti (rivit, tiedostot, commitit, pr:t, yms. numerotieto, kielet, kirjastot). 
- Vertaile kuinka paljon tekoälyn käytöstä on ollut hyötyä tämän projektin toteutuksessa.  
- Arvioi kuinka paljon tämä projekti toteutukseen on mennyt aikaa tekoälyn avulla, sekä arvioi paljon aikaa olisi tarvittu jos projektin olisi  toteuttanut a) harrastelija, jolla on perustiedot pythonista b) keskiverto ohjelmoija c) ammattilaisohjelmoija d) mestariohjelmoija, ilman tekoälyn apua
- Arvioi mitä teknisiä taitoja projektin toteuttaminen vaatii. Esim. ohjelmointitekniikka, laitetuntemus, yms.

Lisää tämä prompti tiedoston loppuun esimerkiksi.
