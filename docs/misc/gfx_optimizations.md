# lib-gfx.asm optimointianalyysi

Tama muistio kokoaa viimeisimmät `lib-gfx.asm`-optimointipaatokset ja niiden perustelut.

## Yhteenveto

- Koko ruudun taytto on nyt oma julkinen rutiininsa: `gfx_fill_screen(R0=0/1)`.
- `gfx_clear` on ohut wrapper `gfx_fill_screen`-rutiinin paalle, jotta koko ruudun nollaus kulkee aina saman nopean polun kautta.
- Demo (`demo_lib_gfx.asm`) kayttaa nyt samaa taytto-API:a yhteisessa kehysalustuksessa.
- Pac-Man- ja haamuliike kayttaa `gfx_step_towards_point_1px`-apuria, jotta liike on deterministisesti korkeintaan 1 pikseli per frame.
- Spritejarjestelma pysyy tarkoituksella kiinteana 8x8-mallina. Tormaysboksin koko johdetaan automaattisesti vakiosta `GFX_SPRITE8_SIZE`, joten erillista kayttajan antamaa bounding box -parametria ei enaa tarvita.

## Tarkastellut vaihtoehdot

### 1. Koko ruudun tyhjennys / taytto

Vaihtoehdot:
- Per-pixel silmukka `gfx_pixel`-kutsuilla
- Taytetty suorakaide `gfx_rect`-rutiinilla
- Suora `FILL` VRAM-alueelle moodikohtaisella taytesanalla

Valinta: suora `FILL`.

Perustelu:
- Molemmissa grafiikkatiloissa koko ruutu on lineaarinen VRAM-alue.
- Moodikohtainen taytesana on vakio (`0x0003` tilassa B, `0x00FF` tilassa C), joten koko ruudun taytto ei tarvitse per-pixel logiikkaa.
- Ratkaisu on samalla nopein ja yksinkertaisin mahdollinen hot path koko ruudun alustukseen.

### 2. Spritejen liike demossa

Vaihtoehdot:
- Paikallinen demoapu, joka liikuttaa x- ja y-akselia samassa framessa
- Julkinen apurutiini, joka ottaa korkeintaan yhden 1 px -askeleen kohti kohdetta

Valinta: julkinen `gfx_step_towards_point_1px`.

Perustelu:
- Demo tarvitsi eksplisiittisesti 1 px/frame -liikkeen vaiheisiin 9 ja 10.
- Yhteinen apurutiini tekee kayttaytymisesta saman kaikille spriteille ja poistaa paikallisen duplikaattilogiikan.
- Tasatilanteessa x-akselin priorisointi tekee liikkeesta deterministisen, mutta edelleen helposti ennakoitavan.

### 3. Spritejen bounding box -malli

Vaihtoehdot:
- Lisaa erilliset bbox-kentat jokaiselle spritelle ja tue arvoa 0 = auto
- Pida spritejarjestelma kiinteana 8x8-mallina ja johda tormaysboksi aina samasta koosta

Valinta: kiintea 8x8-malli.

Perustelu:
- Kirjaston nykyinen sprite-API tukee vain 8x8-spritetta, joten erillinen bbox-konfiguraatio kasvattaisi tilaa ja monimutkaisuutta ilman todellista hyotya.
- Kiintea `GFX_SPRITE8_SIZE` tarkoittaa, etta collision-bbox on jo automaattisesti "auto" jokaiselle slotille.
- Ratkaisu tekee sekavasti muotoillusta vanhasta todo-kohdasta yksiselitteisen nykyarkkitehtuurissa: bbox johdetaan aina spriten kiinteasta koosta.

## Mitka hotspotit jaivat ennalleen

- `gfx_line`, `gfx_rect` ja `gfx_circle` ovat edelleen pitkaltikutsupohjaisia, koska ne rakentuvat `gfx_pixel`-operaation varaan.
- Tilojen B ja C bittipakkaus tekee turvallisesta bulk-optimoidusta span-piirtamisesta hankalamman kuin koko ruudun taytosta.
- Sprite-renderointi kayttaa edelleen per-pikseli `gfx_pixel`-kutsua, koska draw mode -semantiikka (`0/1/XOR`) halutaan pitaa tasmalleen samana kuin muualla kirjastossa.

## Kaytannon lopputulos

- Koko ruudun alustukset ovat nyt yksi selkea hot-path-rutiini.
- Demo ei teleporttaa Pac-Mania satunnaispaikkaan joka framella, vaan liikkuu kohti kohdetta hallitusti.
- 8x8 spritekoko ja siita johdettu collision-bbox on nyt eksplisiittisesti dokumentoitu sekä kirjastossa etta projektidokumentaatiossa.