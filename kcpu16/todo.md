# TODO

Tässä tiedostossa on kokoelma tehtäviä, jotka liittyvät KCPU16-projektiin. Näitä tehtäviä voidaan käyttää projektin kehittämiseen ja parantamiseen, ihmisen tai tekoälyn toimesta. Tehtävät tulee pitää lyhyinä ja selkeästi kuvattuina. Isommat tehtäväkokonaisuudet tulee jakaa pienempiin osiin, jotta ne voidaan toteuttaa vaiheittain. 

## Ohjeet

Tehtävät ovat tärkeysjärjestyksessä ylhäältä alas.

Tehtävät on merkitty hakasulkeilla, ja niiden tilaa voidaan päivittää seuraavasti:
- [ ] Tehtävä ei ole aloitettu 
- [W] Tehtävä on aloitettu, mutta ei vielä valmis
- [X] Tehtävä on valmis
- [C] Tehtävä peruttu tai ei enää relevantti. Tehtävä ei saa suorittaa, mutta se on säilytettävä dokumentaation vuoksi.
- [?] Tehtävässä on huomattu jotain epäselvää tai ongelmallista, joka vaatii lisäselvitystä ennen kuin se voidaan suorittaa.

## Ohje tekoälylle: 

- Saat työskennellä kerrallaan vain yhden tehtävän parissa.
- Valitset Tehtävät-kappaleesta listan ensimmäisen tehtävän. 
- Kun ryhdyt suorittamaan tehtävää, päivitä sen tilaksi [W] ja aloita tehtävän suorittaminen. 
- Jos huomaat, että tehtävä on epäselvä tai siinä on ongelmia, merkitse se tilaan [?] ja kuvaile ongelma lyhyesti. 
- Älä yritä suorittaa tehtävää, ennen kuin se on selkeä ja toteuttamiskelpoinen. 
- Älä muuta tehtävän alkuperäistä kuvausta, mutta voit lisätä kommentteja tai huomautuksia, jotka auttavat selventämään tehtävää, sen vaatimuksia tai epäselvyyksiä. 
- Voit myös ehdottaa tehtävän jakamista pienempiin osiin, jos se vaikuttaa liian suurelta tai monimutkaiselta toteutettavaksi kerralla.
- Mikäli nämä ohjeet ovat epäselvät, kuvaile ongelma tämän listan alle, ja lopeta tehtävien suorittaminen.
  
## Tehtävät


[X] Lisää prosessorille käsky, jolla muistialueen voi täyttää nopeasti annetulla arvolla. Tämä voisi olla esimerkiksi "FILL" -käsky, joka ottaa kolme operandia: alku- ja loppuosoitteet sekä täytettävän arvon. Tämä käsky voisi olla hyödyllinen esimerkiksi taulukkojen alustamiseen tai muistialueiden nollaamiseen nopeasti.
[ ] Lisää dokumentaatioon kuvaus uudesta FILL-käskystä.
[ ] Lisää FILL-käskyyn liittyvä testitapaus, joka varmistaa, että käsky toimii oikein eri tilanteissa, kuten erikokoisilla muistialueilla ja erilaisilla täytettävillä arvoilla.
[ ] Päivitä demo_lib_gfx.asm ja demo_3dcube.asm käskyjen FILL käyttöön, missä se on hyödyllinen. Esimerkiksi, voit käyttää FILL-käskyä taulukkojen alustamiseen tai muistialueiden nollaamiseen ennen niiden käyttöä demoissa.
[ ] Tarkista direktiivien .db (masked arvolla 0xFF) ja .dw (masked arvolla 0xFFFF) toiminta ja varmista että ne toimivat oikein.
[ ] Varmista että .db ja .dw direktiivit toimivat oikein 0-65535 arvoilla ja etumerkillisillä arvoilla 
[ ] Päivitä .db ja .dw direktiiveihin liittyvä dokumentaatio.
[ ] Ohjelman suorituksessa on tilat STOPPED, STEP, FULL, SLOW ja RESET. Tämä tila näytetään käyttöliittymän oikeassa yläkulmassa. Varmista, että nämä tilat toimivat oikein ja että ne päivitetään oikein ohjelman suorituksen aikana.
[ ] Lisää dokumentaatioon kuvaus siitä, miten ohjelman suoritustilat (STOPPED, STEP, FULL, SLOW, RESET) toimivat ja miten ne vaikuttavat ohjelman suoritukseen.
[ ] Lisää toiminto jolla ohjelman suoritusnopeutta voi säätää portaattomasti 1-100 käskyä/sekuntti. Tämä voisi olla esimerkiksi liukusäädin käyttöliittymässä. Tämä on sama kuin nykyinen SLOW (10 käskyä/sekuntti)
[ ] Lisää dokumentaatioon kuvaus siitä, miten ohjelman suoritusnopeutta voi säätää ja miten se vaikuttaa ohjelman suoritukseen.
[ ] Vaihda FULL tilan nimeksi FAST ja pidä toiminta samana. Tämä on vain nimimuutos, joka tekee tilan nimen kuvaavammaksi.
[ ] Lisää dokumentaatioon kuvaus siitä, että FULL-tila on nimetty uudelleen FAST-tilaksi, mutta sen toiminta pysyy samana.
[ ] Lisää ohjelmaan MAX-suoritustila ja vastaavat toiminnot käyttöliittymään kuin FAST-tilalla on.. TÄssä tilassa näytön päiviytys tapahtuu vain, kun ohjelma on pysähtynyt, eikä joka käskyn jälkeen. Tämä mahdollistaa erittäin nopean suorituksen ilman näytön päivityksen aiheuttamaa hidastumista. Ohjelman käyttöliittymän tulee kuitenkin toimia normaalisti, ja käyttäjän tulee pystyä pysäyttämään ohjelma milloin tahansa. Tämä tila on hyödyllinen erityisesti silloin, kun halutaan suorittaa suuri määrä käskyjä nopeasti ilman tarvetta nähdä jokaisen käskyn vaikutusta näytöllä.
[ ] Lisää dokumentaatioon kuvaus siitä, miten MAX-tila toimii ja miten se vaikuttaa ohjelman suoritukseen.
[ ] Lisää dokumentaation kuvaus siitä miten ja milloin näppäimenpainallukset välitetään ohjelman suoritukseen.
