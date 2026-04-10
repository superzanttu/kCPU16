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
- Kun ryhdyt suorittamaan tehtävää, päivitä sen tilaksi [W] ja aloita tehtävän suorittaminen. Tämä on tehtävä ehdottomasti ennen mitään tehtävään liittyviä toimia. Lisää tehtävän alle sisennettynä "START: YYYY-MM-DD HH:MM:SS" -rivi, joka kertoo milloin aloitit tehtävän suorittamisen. Tämä auttaa seuraamaan tehtävien etenemistä ja arvioimaan suoritusaikoja.
- Jos huomaat, että tehtävä on epäselvä tai siinä on ongelmia, merkitse se tilaan [?] ja kuvaile ongelma lyhyesti. Lisää tehtävän alle sisennettynä "ISSUE: YYYY-MM-DD HH:MM:SS" -rivi, joka kertoo milloin ongelma havaittiin. Tämä auttaa dokumentoimaan ongelmat ja varmistamaan, että ne käsitellään ennen kuin tehtävää yritetään suorittaa.
- Älä yritä suorittaa tehtävää, ennen kuin se on selkeä ja toteuttamiskelpoinen. 
- Älä muuta tehtävän alkuperäistä kuvausta, mutta voit lisätä kommentteja tai huomautuksia, jotka auttavat selventämään tehtävää, sen vaatimuksia tai epäselvyyksiä. 
- Voit myös ehdottaa tehtävän jakamista pienempiin osiin, jos se vaikuttaa liian suurelta tai monimutkaiselta toteutettavaksi kerralla.
- Voit analysoida tehtävien vaatimuksia ja suorittaa niitä ryhminä.
- Mikäli nämä ohjeet ovat epäselvät, kuvaile ongelma tämän listan alle, ja lopeta tehtävien suorittaminen.
- Suoritettuasi tehtävän, päivitä sen tilaksi [X] ja lisää tehtävän alle sisennettynä "DONE: YYYY-MM-DD HH:MM:SS" -rivi, joka kertoo milloin tehtävä saatiin valmiiksi. Tämä auttaa seuraamaan tehtävien suoritusaikoja ja arvioimaan tulevien tehtävien vaatimuksia.
  
## Tehtävät


[X] Lisää prosessorille käsky, jolla muistialueen voi täyttää nopeasti annetulla arvolla. Tämä voisi olla esimerkiksi "FILL" -käsky, joka ottaa kolme operandia: alku- ja loppuosoitteet sekä täytettävän arvon. Tämä käsky voisi olla hyödyllinen esimerkiksi taulukkojen alustamiseen tai muistialueiden nollaamiseen nopeasti.
[X] Lisää dokumentaatioon kuvaus uudesta FILL-käskystä.
[X] Lisää FILL-käskyyn liittyvä testitapaus, joka varmistaa, että käsky toimii oikein eri tilanteissa, kuten erikokoisilla muistialueilla ja erilaisilla täytettävillä arvoilla.
[X] Päivitä demo_lib_gfx.asm ja demo_3dcube.asm käskyjen FILL käyttöön, missä se on hyödyllinen. Esimerkiksi, voit käyttää FILL-käskyä taulukkojen alustamiseen tai muistialueiden nollaamiseen ennen niiden käyttöä demoissa.
[X] Tarkista direktiivien .db (masked arvolla 0xFF) ja .dw (masked arvolla 0xFFFF) toiminta ja varmista että ne toimivat oikein.
[X] Varmista että .db ja .dw direktiivit toimivat oikein 0-65535 arvoilla ja etumerkillisillä arvoilla 
[X] Päivitä .db ja .dw direktiiveihin liittyvä dokumentaatio.
[X] Ohjelman suorituksessa on suoritustilat STOPPED, STEP, FULL, SLOW ja RESET. Tämä tila näytetään käyttöliittymän oikeassa yläkulmassa. Varmista, että nämä tilat toimivat oikein ja että ne päivitetään oikein ohjelman suorituksen aikana.
[X] Lisää dokumentaatioon kuvaus siitä, miten ohjelman suoritustilat (STOPPED, STEP, FULL, SLOW, RESET) toimivat ja miten ne vaikuttavat ohjelman suoritukseen.
[X] Lisää toiminto jolla ohjelman suoritusnopeutta voi säätää portaattomasti 1-100 käskyä/sekuntti. Tämä voisi olla esimerkiksi liukusäädin käyttöliittymässä. SUoritustilana tämä on sama kuin nykyinen SLOW (10 käskyä/sekuntti), mutta käyttäjälle annetaan mahdollisuus säätää käskujen suoritusnopeutta.
[X] Lisää dokumentaatioon kuvaus siitä, miten ohjelman suoritusnopeutta voi säätää ja miten se vaikuttaa ohjelman suoritukseen.
[X] Vaihda FULL tilan nimeksi FAST ja pidä toiminta samana. Tämä on vain nimimuutos, joka tekee tilan nimen kuvaavammaksi.
[X] Lisää dokumentaatioon kuvaus siitä, että FULL-tila on nimetty uudelleen FAST-tilaksi, mutta sen toiminta pysyy samana.
[X] Lisää ohjelmaan MAX-suoritustila ja vastaavat toiminnot käyttöliittymään kuin FAST-tilalla on.. TÄssä tilassa näytön päiviytys tapahtuu vain, kun ohjelma on pysähtynyt, eikä joka käskyn jälkeen. Tämä mahdollistaa erittäin nopean suorituksen ilman näytön päivityksen aiheuttamaa hidastumista. Ohjelman käyttöliittymän tulee kuitenkin toimia normaalisti, ja käyttäjän tulee pystyä pysäyttämään ohjelma milloin tahansa. Tämä tila on hyödyllinen erityisesti silloin, kun halutaan suorittaa suuri määrä käskyjä nopeasti ilman tarvetta nähdä jokaisen käskyn vaikutusta näytöllä.
[X] Lisää dokumentaatioon kuvaus siitä, miten MAX-tila toimii ja miten se vaikuttaa ohjelman suoritukseen.
[ ] Lisää dokumentaation kuvaus siitä miten ja milloin näppäimenpainallukset välitetään ohjelman suoritukseen.
[ ] Varmista että assebler sallii vain LOAD ja STORE käskyt, eikä salli käskyjen erilaisten osoitusmuotojen käyttöä. Myöskään LOAD-käskun käyttäminen assembler koodissa ei ole sallittu. Tarkoituksena on että ohjelmoija käyttää vain READ ja STORE käskyjä, ja että assembler hoitaa oikeiden LOAD/STORE-käskyjen generoinnin eri osoitusmuodoille. Tämä auttaa pitämään assembler-koodin selkeänä ja yksinkertaisena, ja varmistaa että kaikki muistiviittaukset tapahtuvat turvallisesti ja oikein.
[ ] Lisää dokumentaatioon kuvaus siitä, että assembler sallii vain READ ja STORE käytön.
[ ] Lisää KCPU16:n näyttöön kaksoisbufferionti, joka mahdollistaa näytön päivittämisen ilman välkkymistä. Tämä tarkoittaa, että kaikki näytölle piirretyt muutokset tehdään ensin taustalla olevaan bufferiin, ja sitten koko buffer kopioidaan kerralla näytölle. Tämä parantaa suorituskykyä ja tekee näytön päivityksestä sujuvampaa, erityisesti silloin, kun piirretään paljon pikseleitä tai tehdään suuria muutoksia näytölle.
[ ] Lisää dokumentaatioon kuvaus siitä, miten kaksoisbufferointi toimii ja miten se parantaa näytön päivitystä.
[ ] Määritä kaikille käskyille suoritusikat, jotka kuvaavat kuinka kauan kunkin käskyn suorittaminen kestää. Nämä ajat voivat perustua esimerkiksi käskyjen monimutkaisuuteen tai siihen, kuinka paljon muistiviittauksia ne tekevät. Käskyjen suoritusajat voidaan määrittää esimerkiksi mikrosekunteina tai millisekunteina, ja ne voivat vaihdella käskyittäin. Tämä auttaa tekemään ohjelman suorituksesta realistisempaa ja antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää.
[ ] Lisää dokumentaatioon kuvaus siitä, miten käskyjen suoritusajat määritetään ja miten ne vaikuttavat ohjelman suoritukseen.
[ ] Muuta toimintaa niin että uptime-laskurin arvon kasvattamiseen käytetään konekielisille käskyille määriteltyjä suoritusaikoja.
[ ] Muuta Ajastinkeskeytyksen (TMR) ja Kellokeskeytyksen (CTMR) toimintaa niin, että ne perustuvat käskyjen suoritusaikoihin eikä pelkästään suoritettujen käskyjen lukumäärään. Tämä tarkoittaa, että keskeytykset laukaistaan, kun käskyjen suoritukseen kuluva aika saavuttaa tietyn rajan, eikä vain silloin, kun tietty määrä käskyjä on suoritettu. Tämä tekee keskeytyksistä realistisempia ja antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää. Tämä mahdollistaa prosessorin toiminnan hidastamisen ilman ongelmia.
[ ] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytykset laukaistaan käskyjen suoritusaikojen perusteella ja miten se vaikuttaa ohjelman suoritukseen.
[ ] Lisää Flags-ikkunaan TMR- ja CTRM- keskeytyksiin liittyvät tiedot, kuten jäljellä olevan ajan määrä ennen keskeytyksen laukeamista. Tämä antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää ennen kuin keskeytys laukeaa, ja auttaa suunnittelemaan ohjelman suoritusta tehokkaammin.
[ ] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytyksiin liittyvät tiedot näytetään Flags-ikkunassa ja miten se auttaa käyttäjää ymmärtämään ohjelman suoritusta.
[ ] Step/Full/Slow painikkeet eivät saa käynnistää prosessorin toimintaa, ellei load-komennolla ole ladattu muistii ohjelmaa. Pitää antaa virheilmoitus, jos yritetään käynnistää ilman ladattua ohjelmaa. Tämä varmistaa, että käyttäjä ei vahingossa yritä suorittaa ohjelmaa, joka ei ole ladattu, ja antaa selkeän viestin siitä, että ensin on ladattava ohjelma ennen kuin sitä voi suorittaa.
[ ] Lisää dokumentaatioon kuvaus siitä, että Step/Full/Slow-painikkeet vaativat ladatun ohjelman toimiakseen ja että ne antavat virheilmoituksen, jos yritetään käynnistää ilman ladattua ohjelmaa.
[ ] Tarkista että demo_lib_gfx.asm ja lib_gfx.asm käyttävät FILL-käskyä taulukkojen alustamiseen tai muistialueiden nollaamiseen, missä se on hyödyllinen. Tämä auttaa tekemään demoista tehokkaampia ja selkeämpiä, ja varmistaa että ne hyödyntävät uusia käskyjä parhaalla mahdollisella tavalla.    
[ ] Mitä Flags-ikkunassa näkyvä "State: READY" tieto tarkoittaa?
[ ] VArmista että latatun .asm-ohjelman nimi näkyy käyttöliitymässä. Jos ei ole ladattu älä näytä nimeä.
[ ] Lisää dokumentaatioon kuvaus siitä, että latatun .asm-ohjelman nimi näkyy käyttöliittymässä, ja että nimeä ei näytetä, jos ohjelmaa ei ole ladattu.
[ ] Varmista että ladatun .dsk-levykuvan nimi näkyy käyttöliittymässä tallennuslaitteen kohdalla. Jos ei ole ladattu, älä näytä nimeä.
[ ] Lisää dokumentaatioon kuvaus siitä, että ladatun .dsk-levykuvan nimi näkyy käyttöliittymässä tallennuslaitteen kohdalla, ja että nimeä ei näytetä, jos levykuvaa ei ole ladattu.
[ ] Varmista että .dsk ja .asm-tiedostojen tallennuksen jälkee ko. nimi näytetään käyttöliittymässä, kuin se olisi juuri ladattu. Tämä antaa käyttäjälle selkeän vahvistuksen siitä, että tiedosto on tallennettu onnistuneesti, ja auttaa pitämään käyttöliittymän ajan tasalla ladattujen ja tallennettujen tiedostojen kanssa.
[ ] Lisää dokumentaatioon kuvaus siitä, että .dsk- ja .asm-tiedostojen tallennuksen jälkeen ko. nimi näytetään käyttöliittymässä, kuin se olisi juuri ladattu, ja että tämä auttaa käyttäjää ymmärtämään, että tiedosto on tallennettu onnistuneesti.
[ ] Varmista että .asm tai .dsk-tiedoston lataamisen jälkeen ohjelman suoritustila on STOPPED, eikä esimerkiksi STEP tai FULL. Tämä varmistaa, että ohjelma ei ala suorittaa automaattisesti heti lataamisen jälkeen, ja antaa käyttäjälle mahdollisuuden tarkistaa ladatun ohjelman ennen sen suorittamista.
[ ] Lisää dokumentaatioon kuvaus siitä, että .asm- tai .dsk-tiedoston lataamisen jälkeen ohjelman suoritustila on STOPPED, eikä esimerkiksi STEP tai FULL, ja että tämä antaa käyttäjälle mahdollisuuden tarkistaa ladatun ohjelman ennen sen suorittamista.
[ ] Varmista että käyttöliittymän kaikki osat ovat englanninkielisiä ja johdonmukaisesti nimettyjä, mukaan lukien kaikki painikkeet, valikot, virheilmoitukset. Tämä varmistaa, että käyttöliittymä on yhdenmukainen ja ymmärrettävä kaikille käyttäjille, riippumatta heidän kielitaustastaan.
[ ] Lisää LOAD-painikkeeseen toiminto, jolla ladattava ohjelma (pakotettu code-hakemistoon) valitaan valintaikkunasta, jossa on esillä kaikki code-hakemistossa olevat .asm-tiedostot. Tämä helpottaa ohjelman lataamista, koska käyttäjän ei tarvitse muistaa tai kirjoittaa tarkkaa tiedostopolkua, vaan hän voi valita ladattavan ohjelman visuaalisesta listasta. Valintaikkunasta valitaan ladattava ohjelma hiiren tuplaklikillä tai valitsemalla ohjelma ja painamall Load-painiketta. Toiminnon voi peruttaa Cancel-painikkeella.
[ ] Lisää dokumentaatioon kuvaus siitä, että LOAD-painikkeella voidaan valita ladattava ohjelma ikkunasta, jossa on esillä kaikki code-hakemistossa olevat .asm-tiedostot, ja että tämä helpottaa ohjelman lataamista.
