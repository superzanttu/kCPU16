# TODO

Tässä tiedostossa on kokoelma tehtäviä, jotka liittyvät KCPU16-projektiin. Näitä tehtäviä voidaan käyttää projektin kehittämiseen ja parantamiseen, ihmisen tai tekoälyn toimesta. Tehtävät tulee pitää lyhyinä ja selkeästi kuvattuina. Isommat tehtäväkokonaisuudet tulee jakaa pienempiin osiin, jotta ne voidaan toteuttaa vaiheittain. 

## Ohjeet

Tehtävät on merkitty hakasulkeilla, ja niiden tilaa voidaan päivittää seuraavasti:
- [ ] Tehtävä ei ole aloitettu 
- [W] Tehtävä on aloitettu, mutta ei vielä valmis
- [X] Tehtävä on valmis
- [C] Tehtävä peruttu tai ei enää relevantti. Tehtävä ei saa suorittaa, mutta se on säilytettävä dokumentaation vuoksi.
- [?] Tehtävässä on huomattu jotain epäselvää tai ongelmallista, joka vaatii lisäselvitystä ennen kuin se voidaan suorittaa.
  
## Tehtävät

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
