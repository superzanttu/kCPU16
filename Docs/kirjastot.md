# kCPU16:n assembly-kirjastot

Tähän tiedostoon on koottu projektin nykyiset assembly-kirjastot sekä uudet yleiskäyttöiset kirjastorungot. Kuvaukset pidetään tarkoituksella lyhyinä ja käytännönläheisinä.

## Nykyiset kirjastot

### `lib-gfx.asm`
- **Käyttötarkoitus:** grafiikkatilojen B ja C piirtokirjasto.
- **Toiminnot:** ruudun tyhjennys, kaksoispuskuroinnin flip, piirtotilan vaihto, pikselin ja viivan piirto, kuvan skrollaus eri suuntiin, ison ja pienen fontin piirto sekä spritejen XOR-piirto.

### `lib-screen.asm`
- **Käyttötarkoitus:** tekstitilan peruskirjasto terminaalimaisiin ohjelmiin.
- **Toiminnot:** näytön tyhjennys, värin asetus, merkkijonojen tulostus, syötteen lukeminen, kursorin hallinta, automaattinen rivinvaihto ja skrollaus.

### `lib-disk.asm`
- **Käyttötarkoitus:** tallennuslaitteen ja yksinkertaisen tiedostojärjestelmän käyttö.
- **Toiminnot:** levyn alustus, tiedostojen ja hakemistojen luonti, luku, kirjoitus, poisto, listaus, kopiointi, tilankäytön tarkistus, eheystarkistus ja vapaan tilan nollaus.

### `lib-3dobjects.asm`
- **Käyttötarkoitus:** 3D-demoissa käytettävät valmiit objektit ja niihin liittyvät apurutiinit.
- **Toiminnot:** sinitaulukko, kiinteäpisteinen kertolasku/jako sekä kuution, pyramidin ja 3D-kirjainmuotojen geometriadata.

### `lib-font_big.asm`
- **Käyttötarkoitus:** iso 6×8 pikselifontti kello- ja grafiikkademoille.
- **Toiminnot:** numeroiden, pisteen, kaksoispisteen ja välilyönnin fonttidata isoa tekstipiirtoa varten.

### `lib-font_small.asm`
- **Käyttötarkoitus:** pieni 4×5 pikselifontti erityisesti CHIP-8- ja grafiikkakäyttöön.
- **Toiminnot:** heksamerkkien fonttidata, geneerinen tulostettavien merkkien glyphi sekä apurutiini oikean glyfin hakemiseen ASCII-merkin perusteella.

## Projektista löytyvät yhteiset toiminnot

Assembly-ohjelmia läpikäydessä samoja tarpeita näkyi useissa tiedostoissa:

- merkkijonojen käsittely ja tulostuksen apurutiinit (`keyboard.asm`, `algo_gcd.asm`, `interrupt_timer.asm`, `benchmark.asm`)
- laskenta- ja lukusarjarutiinit (`algo_factorial.asm`, `algo_fibonacci.asm`, `algo_gcd.asm`, 3D-demot)
- ajan odotus ja ajastimen käyttö (`benchmark.asm`, `benchmark2.asm`, `clock.asm`, `clock_text.asm`, `interrupt_timer.asm`)
- näppäimistön pollaus ja tapahtumien purku (`keyboard.asm`, `screen.asm`, `kdos.asm`)
- muistialueiden täyttö, kopiointi ja vertailu (`disk_test.asm`, `kdos.asm`, useat demot)

Näiden havaintojen pohjalta projektiin lisättiin yleiskäyttöiset kirjastorungot.

## Uudet kirjastorungot

### `lib-math.asm`
- **Käyttötarkoitus:** yleinen laskentakirjasto ohjelmille, jotka tarvitsevat perusmatematiikkaa ilman omaa toteutusta.
- **Toiminnot:** itseisarvo, minimi, maksimi, arvon rajaus välille, suurin yhteinen tekijä, kertoma ja Fibonacci-luku.
- **Huomio:** 3D-demoissa oleva `smul_div100` sopisi jatkossa luontevasti tämän kirjaston laajennukseksi.

### `lib-string.asm`
- **Käyttötarkoitus:** null-terminoitujen merkkijonojen peruskäsittely.
- **Toiminnot:** pituuden laskenta, merkkijonon kopiointi, kahden merkkijonon vertailu, tyhjyyden tarkistus ja yksittäisen merkin etsintä.

### `lib-memory.asm`
- **Käyttötarkoitus:** muistialueiden käsittely yhtenäisellä aliohjelmarajapinnalla.
- **Toiminnot:** alueen täyttö annetulla arvolla, nollaus, kopiointi, vertailu ja yksittäisen sanan etsiminen.

### `lib-input.asm`
- **Käyttötarkoitus:** kevyt näppäimistökirjasto ohjelmille, jotka käyttävät polling-pohjaista syötettä.
- **Toiminnot:** tapahtumien olemassaolon tarkistus, raakasyötteen luku, painalluksen ja vapautuksen erottelu, seuraavan painalluksen luku, painalluksen odotus ja puskurin tyhjennys.

### `lib-timing.asm`
- **Käyttötarkoitus:** kellon ja ajastuksen apukirjasto demoille, peleille ja mittauksille.
- **Toiminnot:** päiväyksen luku, kellonajan luku, kellonajan luku millisekunteineen, seuraavan sekunnin odotus, useamman sekunnin odotus, millisekuntimuutoksen odotus, ajastinkeskeytyksen asetus ja pysäytys.

## Yhteenveto

Projektissa oli jo vahvat kirjasto-osat grafiikalle, tekstiterminaalille, levytoiminnoille, fonteille ja 3D-objekteille. Uudet rungot täydentävät tätä kokonaisuutta niillä alueilla, joihin assembly-ohjelmissa syntyy helposti toisteista apukoodia: matematiikka, merkkijonot, muisti, syöte ja ajoitus.
