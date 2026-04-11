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
- Valitset Tehtävät-kappaleesta listan ensimmäisen tehtävän, ellet ole analysoinut peräkkäisiä tehtäviä ja päättänyt, että on järkevää suorittaa ne ryhminä.
- Kun ryhdyt suorittamaan tehtävää, päivitä sen tilaksi [W] ja aloita tehtävän suorittaminen. Tämä on tehtävä ehdottomasti ennen mitään tehtävään liittyviä toimia.
- Jos huomaat, että tehtävä on epäselvä tai siinä on ongelmia, merkitse se tilaan [?] ja kuvaile ongelma lyhyesti.
- Älä yritä suorittaa tehtävää, ennen kuin se on selkeä ja toteuttamiskelpoinen. 
- Älä muuta tehtävän alkuperäistä kuvausta, mutta voit lisätä kommentteja tai huomautuksia, jotka auttavat selventämään tehtävää, sen vaatimuksia tai epäselvyyksiä. 
- Voit myös ehdottaa tehtävän jakamista pienempiin osiin, jos se vaikuttaa liian suurelta tai monimutkaiselta toteutettavaksi kerralla.
- Voit analysoida tehtävien vaatimuksia ja suorittaa niitä ryhminä.
- Mikäli nämä ohjeet ovat epäselvät, kuvaile ongelma tämän listan alle, ja lopeta tehtävien suorittaminen.
- Suoritettuasi tehtävän, päivitä sen tilaksi [X] ja siirrä se Tehtävät-kappaleen Valmiit tehtävät -osioon. Älä poista tehtävää, vaan säilytä se dokumentaation vuoksi.
  
## Tehtävät

<!-- ============================================================ -->
<!-- RYHMÄ 1: Selvitystehtävät (itsenäiset, ei riippuvuuksia)     -->
<!-- Suorita ensin – tulokset voivat vaikuttaa muihin ryhmiin.    -->
<!-- ============================================================ -->

### Ryhmä 1: Selvitystehtävät

; Kaikki Ryhmä 1 -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ 2: Assembler-parannukset (assembler.py + cpu.py)       -->
<!-- Muokkaa assembler.py ja cpu.py yhtä aikaa.                   -->
<!-- ============================================================ -->

### Ryhmä 2: Assembler-parannukset

; Kaikki Ryhmä 2 -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ 3: UI – Tiedostohallinta & suoritustila (tui.py)       -->
<!-- Aloita selvitystehtävällä – tulos voi poistaa muita töitä.   -->
<!-- Kaikki koskevat lataus-/tallennus-/käynnistyslogiikkaa.      -->
<!-- ============================================================ -->

### Ryhmä 3: UI – Tiedostohallinta & suoritustila

; Kaikki Ryhmä 3 -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ 4: Suoritusaikajärjestelmä (instruction.py/cpu.py/tui) -->
<!-- Isoin muutos. Tehtävät ovat ketjutettuja: suoritusajat ensin,-->
<!-- sitten uptime, sitten TMR/CTMR, sitten Flags-ikkuna.         -->
<!-- ============================================================ -->

### Ryhmä 4: Suoritusaikajärjestelmä

[ ] Määritä kaikille käskyille suoritusajat, jotka kuvaavat kuinka kauan kunkin käskyn suorittaminen kestää. Nämä ajat voivat perustua esimerkiksi käskyjen monimutkaisuuteen tai siihen, kuinka paljon muistiviittauksia ne tekevät. Käskyjen suoritusajat voidaan määrittää esimerkiksi mikrosekunteina tai millisekunteina, ja ne voivat vaihdella käskyittäin. Tämä auttaa tekemään ohjelman suorituksesta realistisempaa ja antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää.
[ ] Muuta toimintaa niin että uptime-laskurin arvon kasvattamiseen käytetään konekielisille käskyille määriteltyjä suoritusaikoja.
[ ] Muuta Ajastinkeskeytyksen (TMR) ja Kellokeskeytyksen (CTMR) toimintaa niin, että ne perustuvat käskyjen suoritusaikoihin eikä pelkästään suoritettujen käskyjen lukumäärään. Tämä tarkoittaa, että keskeytykset laukaistaan, kun käskyjen suoritukseen kuluva aika saavuttaa tietyn rajan, eikä vain silloin, kun tietty määrä käskyjä on suoritettu. Tämä tekee keskeytyksistä realistisempia ja antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää. Tämä mahdollistaa prosessorin toiminnan hidastamisen ilman ongelmia.
[ ] Lisää Flags-ikkunaan TMR- ja CTRM- keskeytyksiin liittyvät tiedot, kuten jäljellä olevan ajan määrä ennen keskeytyksen laukeamista. Tämä antaa käyttäjälle paremman käsityksen siitä, kuinka kauan ohjelman suorituminen kestää ennen kuin keskeytys laukeaa, ja auttaa suunnittelemaan ohjelman suoritusta tehokkaammin.
[ ] Lisää dokumentaatioon kuvaus siitä, miten käskyjen suoritusajat määritetään ja miten ne vaikuttavat ohjelman suoritukseen.
[ ] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytykset laukaistaan käskyjen suoritusaikojen perusteella ja miten se vaikuttaa ohjelman suoritukseen.
[ ] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytyksiin liittyvät tiedot näytetään Flags-ikkunassa ja miten se auttaa käyttäjää ymmärtämään ohjelman suoritusta.

<!-- ============================================================ -->
<!-- VALMIIT TEHTÄVÄT                                             -->
<!-- ============================================================ -->

### Valmiit tehtävät

[X] Toolbarissa oli aiemmin ohjelman tilaa kuvaava teksti. Selvitä korvaako Flags-ikkunassa oleva State-tieto toolbarissa olleen tilatiedon. Jos toolbarissa oleva tilatieto on tarpeeton, poista sen.
; Toolbarissa ei ole erillistä tilatekstiä — pelkät painikkeet + SpeedSlider. Flags-paneeli (cpu-content) hoitaa tilanäytön. Ei muutoksia tarvittu.
[X] Varmista että käyttöliittymän kaikki osat ovat englanninkielisiä ja johdonmukaisesti nimettyjä, mukaan lukien kaikki painikkeet, valikot, virheilmoitukset. Tämä varmistaa, että käyttöliittymä on yhdenmukainen ja ymmärrettävä kaikille käyttäjille, riippumatta heidän kielitaustastaan.
; Kaikki käyttäjälle näkyvät tekstit (painikkeet, välilehdet, otsikot, virheilmoitukset, lokiviestit) ovat englanninkielisiä. Docstringit ja kommentit ovat suomeksi (sisäinen dokumentaatio, ei näy käyttäjälle).
[X] Step/Full/Slow painikkeet eivät saa käynnistää prosessorin toimintaa, ellei load-komennolla ole ladattu muistii ohjelmaa. Pitää antaa virheilmoitus, jos yritetään käynnistää ilman ladattua ohjelmaa. Tämä varmistaa, että käyttäjä ei vahingossa yritä suorittaa ohjelmaa, joka ei ole ladattu, ja antaa selkeän viestin siitä, että ensin on ladattava ohjelma ennen kuin sitä voi suorittaa.
; Fast/Max/Slow tarkistivat jo is_assembled. Lisättiin vastaava tarkistus action_step_once():iin (tui.py): jos ei ladattu, logitetaan "No program loaded. Use 'load <file>' or Ctrl+O first." eikä suoriteta konekäskyä.
[X] Varmista että .asm tai .dsk-tiedoston lataamisen jälkeen ohjelman suoritustila on STOPPED, eikä esimerkiksi STEP tai FULL. Tämä varmistaa, että ohjelma ei ala suorittaa automaattisesti heti lataamisen jälkeen, ja antaa käyttäjälle mahdollisuuden tarkistaa ladatun ohjelman ennen sen suorittamista.
; _do_assemble() asettaa _exec_mode = "stopped" aina assembloidessa. disk load -komento asettaa _exec_mode = "stopped" ja peruuttaa taustayöntekijän. Jo toteutettu.
[X] VArmista että latatun .asm-ohjelman nimi näkyy käyttöliitymässä. Jos ei ole ladattu älä näytä nimeä.
; _update_program_title() päivittää Screen-paneelin border_subtitle:n tiedostonimellä tai tyhjäksi. Kutsutaan _do_open():ssa. Jo toteutettu.
[X] Varmista että ladatun .dsk-levykuvan nimi näkyy käyttöliittymässä tallennuslaitteen kohdalla. Jos ei ole ladattu, älä näytä nimeä.
; _update_disk_title() päivittää disasm-tabs border_subtitle:n levykuvan nimellä (+ * jos muutoksia) tai tyhjäksi. Jo toteutettu.
[X] Varmista että .dsk ja .asm-tiedostojen tallennuksen jälkee ko. nimi näytetään käyttöliittymässä, kuin se olisi juuri ladattu. Tämä antaa käyttäjälle selkeän vahvistuksen siitä, että tiedosto on tallennettu onnistuneesti, ja auttaa pitämään käyttöliittymän ajan tasalla ladattujen ja tallennettujen tiedostojen kanssa.
; disk save -komento kutsuu _update_disk_title() tallennuksen jälkeen. .asm-tiedostoja ei muokata TUI:ssa (ulkoinen editori), joten .asm-tallennusta ei tarvita.
[X] Lisää LOAD-painikkeeseen toiminto, jolla ladattava ohjelma (pakotettu code-hakemistoon) valitaan valintaikkunasta, jossa on esillä kaikki code-hakemistossa olevat .asm-tiedostot. Tämä helpottaa ohjelman lataamista, koska käyttäjän ei tarvitse muistaa tai kirjoittaa tarkkaa tiedostopolkua, vaan hän voi valita ladattavan ohjelman visuaalisesta listasta. Valintaikkunasta valitaan ladattava ohjelma hiiren tuplaklikillä tai valitsemalla ohjelma ja painamall Load-painiketta. Toiminnon voi peruttaa Cancel-painikkeella.
; FilePickerDialog-modal on jo toteutettu tui.py:ssä. action_open_file() käyttää sitä LOAD-painikkeen ja Ctrl+O-pikavalinnasta. Jo toteutettu.
[X] Lisää dokumentaatioon kuvaus siitä, että Step/Full/Slow-painikkeet vaativat ladatun ohjelman toimiakseen ja että ne antavat virheilmoituksen, jos yritetään käynnistää ilman ladattua ohjelmaa.
; Dokumentoitu tui.md:n luvussa 10 ("Step/Fast/Max/Slow — ohjelman latausvaatimus").
[X] Lisää dokumentaatioon kuvaus siitä, että .asm- tai .dsk-tiedoston lataamisen jälkeen ohjelman suoritustila on STOPPED, eikä esimerkiksi STEP tai FULL, ja että tämä antaa käyttäjälle mahdollisuuden tarkistaa ladatun ohjelman ennen sen suorittamista.
; Dokumentoitu tui.md:n luvussa 10 ("Suoritustila latauksen jälkeen").
[X] Lisää dokumentaatioon kuvaus siitä, että latatun .asm-ohjelman nimi näkyy käyttöliittymässä, ja että nimeä ei näytetä, jos ohjelmaa ei ole ladattu.
; Dokumentoitu tui.md:n luvussa 10 ("Ladattujen tiedostojen nimet käyttöliittymässä").
[X] Lisää dokumentaatioon kuvaus siitä, että ladatun .dsk-levykuvan nimi näkyy käyttöliittymässä tallennuslaitteen kohdalla, ja että nimeä ei näytetä, jos levykuvaa ei ole ladattu.
; Dokumentoitu tui.md:n luvussa 10 ("Ladattujen tiedostojen nimet käyttöliittymässä").
[X] Lisää dokumentaatioon kuvaus siitä, että .dsk- ja .asm-tiedostojen tallennuksen jälkeen ko. nimi näytetään käyttöliittymässä, kuin se olisi juuri ladattu, ja että tämä auttaa käyttäjää ymmärtämään, että tiedosto on tallennettu onnistuneesti.
; Dokumentoitu tui.md:n luvussa 10 ("Ladattujen tiedostojen nimet käyttöliittymässä").
[X] Lisää dokumentaatioon kuvaus siitä, että LOAD-painikkeella voidaan valita ladattava ohjelma ikkunasta, jossa on esillä kaikki code-hakemistossa olevat .asm-tiedostot, ja että tämä helpottaa ohjelman lataamista.
; Dokumentoitu tui.md:n luvussa 10 ("Load-painike ja tiedostonvalintaikkuna").

[X] Mitä Flags-ikkunassa näkyvä "State: READY" tieto tarkoittaa?
; READY (vihreä)   = CPU pyörii normaalisti (ei halted, ei exit_requested)
; HALTED (punainen) = HLT-käsky tai virhe pysäytti suorituksen
; EXITED (keltainen)= ohjelma päättyi hallitusti EXIT-käskyllä

[X] Assemblerin antaessa virheilmoitus, on näytettävä virheen aiheuttavan rivin numero, itse rivi ja kuvaus virheestä. Tämä auttaa ohjelmoijaa ymmärtämään, mikä osa koodista aiheuttaa ongelman, ja antaa selkeän viestin siitä, mitä virhe on, jotta se voidaan korjata tehokkaasti.
; Toteutettu assembler.py:ssä (_current_lineno + _current_line) ja dokumentoitu assembler.md luvussa 8.
[X] Varmista ettö FILL-komennon kohteena oleva muisti alue on kokonaisuudessa kirjoitettavissa, ennen kuin varsinainen kirjoitus aloitetaan. Mikäli kohdealue ei ole kokonaisuutenaa, annetaan virheilmoitus.
; Toteutettu cpu.py:ssä (_check_memory_access: FILL tarkistaa koko alueen ennen kirjoitusta) ja dokumentoitu architecture.md:ssä.
[X] Lisää dokumentaatioon kuvaus siitä, että assemblerin virheilmoitukset sisältävät rivin numeron, itse rivin ja kuvauksen virheestä, ja että tämä auttaa ohjelmoijaa ymmärtämään ja korjaamaan virheet tehokkaasti.
; Dokumentoitu assembler.md luvussa 8 (muoto, esimerkki, huomiot rivinumeroinnista).
[X] Lisää dokumentaatioon kuvaus siitä, että FILL-komennon kohteena olevan muistialueen on oltava kokonaisuudessaan kirjoitettavissa ennen kuin kirjoitus aloitetaan, ja että virheilmoitus annetaan, jos alue ei ole kokonaisuudessaan kirjoitettavissa.
; Dokumentoitu architecture.md:ssä FILL-käskyn kuvauksessa (Kirjoitussuojaus-huomio).

[X] Analysoi kaikki muistialueet-, -rekisterit ja -varaukset päällekkäisyyksien varalta, ja varmista että niissä ei ole päällekkäisyyksiä, jotka voisivat aiheuttaa ongelmia ohjelman suorituksessa. Tämä tarkoittaa, että jokaisella muistialueella, rekisterillä ja varauksella on oma selkeä osoitealueensa, eikä mikään niistä ylitä toisen alueen rajoja. Tämä auttaa varmistamaan, että ohjelma toimii oikein ja että muistiviittaukset tapahtuvat turvallisesti ja oikein.
; Muistikartta analysoitu: ei kriittisiä päällekkäisyyksiä.
; GFX_MODE_REG (0xFF80) == KERNEL_STACK_START (0xFF80) on tarkoituksellinen design:
; GFX_MODE_REG sijaitsee kerneli-pinon pohjassa; pino kasvaa alas 0xFFFF:stä.
; Stack overflow -suojaus laukeaa ennen kuin pino ehtii ylikirjoittaa 0xFF80:n.

[X] Tarkista että demo_lib_gfx.asm ja lib_gfx.asm käyttävät FILL-käskyä taulukkojen alustamiseen tai muistialueiden nollaamiseen, missä se on hyödyllinen. Tämä auttaa tekemään demoista tehokkaampia ja selkeämpiä, ja varmistaa että ne hyödyntävät uusia käskyjä parhaalla mahdollisella tavalla.
; lib-gfx.asm käyttää jo FILL:ä gfx_clear-funktiossa (koko VRAM nollataan yhdellä käskyllä).
; demo_lib_gfx.asm:ssä ei ole sopivia kohteita: vain yksi phase-byte, ei taulukoita.

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
[X] Lisää dokumentaation kuvaus siitä miten ja milloin näppäimenpainallukset välitetään ohjelman suoritukseen.
[X] Varmista että assebler sallii vain LOAD ja STORE käskyt, eikä salli käskyjen erilaisten osoitusmuotojen käyttöä. Myöskään LOAD-käskyn käyttäminen assembler koodissa ei ole sallittu. Tarkoituksena on että ohjelmoija käyttää vain READ ja STORE käskyjä, ja että assembler hoitaa oikeiden LOAD/STORE-käskyjen generoinnin eri osoitusmuodoille. Tämä auttaa pitämään assembler-koodin selkeänä ja yksinkertaisena, ja varmistaa että kaikki muistiviittaukset tapahtuvat turvallisesti ja oikein.
[X] Lisää dokumentaatioon kuvaus siitä, että assembler sallii vain READ ja STORE käytön.
[X] Lisää KCPU16:n näyttöön kaksoisbufferionti, joka mahdollistaa näytön päivittämisen ilman välkkymistä. Tämä tarkoittaa, että kaikki näytölle piirretyt muutokset tehdään ensin taustalla olevaan bufferiin, ja sitten koko buffer kopioidaan kerralla näytölle. Tämä parantaa suorituskykyä ja tekee näytön päivityksestä sujuvampaa, erityisesti silloin, kun piirretään paljon pikseleitä tai tehdään suuria muutoksia näytölle. Säilytä kuitenkin mahdollisuus olla käyttämättä kaksoisbufferointia, jos käyttäjä haluaa nähdä jokaisen käskyn vaikutuksen näytöllä välittömästi.
[X] Lisää dokumentaatioon kuvaus siitä, miten kaksoisbufferointi toimii ja miten se parantaa näytön päivitystä.


<!-- ============================================================ -->
<!-- RYHMÄ 10: 3D-demot – analyysi ja korjaukset                 -->
<!-- Järjestys: analyysi → J-korjaus → L-korjaus → refaktorointi.-->
<!-- Kaikki koskevat samaa koodikantaa (lib_3dobjects.asm).       -->
<!-- ============================================================ -->

### Ryhmä 10: 3D-demot – analyysi ja korjaukset

[ ] Analysoi demo_3dcude.asm, demo_3dcube2.asm, lib_3dobjects.asm ja lib_gfx.asm -tiedostot ja varmista että ohjelma näyttää kuution, L-kirjaimen ja J-kijaimmen, 10 sekunnin ajan, vuorotellen B-ja C- grafiikkatilassa. Varmista samalla, että objektteja pyöritetään X, Y, ja Z-akselien ympäri, ja että ne liikkuvat näytöllä.
[ ] J-kirjain ei ole ollenkaan J-kirjaimen muotoinen.
[ ] L-kirjain on oikeian muotoinen, mutta renderöityy väärin joissakin asennoissa.
[ ] Analysoi demo_3dcude.asm, demo_3dcube2.asm, lib_3dobjects.asm ja lib_gfx.asm -tiedostot ja etsi yhteisiä toimintoja, jotka voitaisiin siirtää uuteen lib-gfx.asm-kirjastoon.

<!-- ============================================================ -->
<!-- RYHMÄ 11: Tallennuslaitekirjasto (lib-disk.asm)             -->
<!-- Itsenäinen uusi ominaisuus, ei riippuvuuksia muihin ryhmiin. -->
<!-- ============================================================ -->

### Ryhmä 11: Tallennuslaitekirjasto

[ ] Luo kirjasto (code/lib-disk.asm) joka toteuttaa tallennuslaaitteen käsittelyn. Tarvitaan yksinkertainen tiedostojärjestelmä, joka mahdollistaa tiedostojen tallentamisen. Hakemistoja ei tarvita. Tiedostoilla on nimi (1-32 merkkiä) ja koko (0-65535 tavua). Kirjasto toteuttaa seuraavat toiminnot: tiedoston luominen, tiedoston kirjoittaminen, tiedoston lukeminen, tiedoston poistaminen, tiedostojen listaaminen ja tiedoston ominaisuuksien lukeminen. Kirjasto käsittelee tallennuslaitteen blockkia (256 tavua) perinteisen tallennuslaitten "sektorina" ja tallentaa yhteen "sektoriin" useamman tiedoston dataa, jakaen ne lohkoihin. TIedostojärjestelmä blokki 0 on varattu ns. boot-sektoriksi, josta kCPU16-lukee käynnistyksen yhteydessä boot-ohjelman.
[ ] Lisää dokumentaatioon kuvaus uudesta tallennuslaitekirjastosta (code/lib-disk.asm) ja sen tarjoamista toiminnoista.

<!-- ============================================================ -->
<!-- RYHMÄ 5: Suorituskyky – Opcode-pohjainen dispatch (cpu.py)  -->
<!-- Korvaa merkkijonopohjainen dispatch handler-taululla.        -->
<!-- ============================================================ -->

### Ryhmä 5: Suorituskyky – Opcode-pohjainen dispatch

[ ] Korvaa `DecodedInstruction`-olion luonti jokaisessa askeleessa kevyemmällä rakenteella (esim. kiinteä tuple tai paikalliset muuttujat), jotta olion luomisen overhead poistuu hot loopista.
[ ] Korvaa `if/elif ins.mnemonic == ...` -ketju opcode-pohjaisella handler-taululla (funktioviitteet: opcode → handler + metadata), jotta merkkijonovertailut poistuvat kuumasta suorituspolusta.
[ ] Yhdistä privilege- ja muistitarkistus handler-metadataan, jotta samoja mnemonic-vertailuja ei tehdä useassa eri vaiheessa per käsky.

<!-- ============================================================ -->
<!-- RYHMÄ 6: Suorituskyky – Ajanotto- ja keskeytystarkistukset  -->
<!-- Riippuvuus: Ryhmä 4 (suoritusajat) suoritettava ensin, jotta -->
<!-- TMR/CTMR-optimoinnit ovat yhteensopivia simuloitujen         -->
<!-- aikojen kanssa. Vähentää time.monotonic()-kutsuja hot        -->
<!-- loopissa ja korvaa modulo-vertailun next_cycle-vertailulla.  -->
<!-- ============================================================ -->

### Ryhmä 6: Suorituskyky – Ajanotto- ja keskeytystarkistukset

[ ] Poista `time.monotonic()`-kutsu jokaiselta käskykierrokselta; tarkista uptime/CTMR vain harvennetusti (esim. joka N:s käsky) tai deadline-pohjaisesti.
[ ] Korvaa timer-keskeytyksen modulovertailu (`instruction_counter % tmr == 0`) seuraavan laukaisusyklin vertailulla (`next_timer_cycle`), jotta modulo-operaatio poistuu hot loopista.

<!-- ============================================================ -->
<!-- RYHMÄ 7: Suorituskyky – Taulukkopohjaiset rekisterit        -->
<!-- Korvaa if/elif-rekisteriketjut indeksoinnilla cpu.py:ssä.   -->
<!-- ============================================================ -->

### Ryhmä 7: Suorituskyky – Taulukkopohjaiset rekisterit

[ ] Korvaa `_get_reg`/`_set_reg`-metodien pitkät `if/elif`-ketjut taulukkoindeksoinnilla CPU:n suorituspolussa (lista tai array), jotta haarautumisoverhead poistuu jokaisesta rekisteriviittauksesta.
[ ] Säilytä julkinen rajapinta (r0…r15, fp, sp) ennallaan esim. propertyjen kautta; anna `execute`-polun käyttää suoraa taulukkorakennetta.

<!-- ============================================================ -->
<!-- RYHMÄ 8: Suorituskyky – Memory.write O(1)-suojaustarkistus  -->
<!-- Korvaa alue-listan läpikäynti maskitaulukolla.              -->
<!-- ============================================================ -->

### Ryhmä 8: Suorituskyky – Memory.write O(1)-suojaustarkistus

[ ] Korvaa `read_only_regions`-listan läpikäynti jokaisella kirjoituksella maskitaulukolla (`bytearray`/bool-taulukko), joka päivitetään vain silloin, kun suojattuja alueita muutetaan.

<!-- ============================================================ -->
<!-- RYHMÄ 9: Suorituskyky – Fast run -suorituspolku (cpu.py)    -->
<!-- Erillinen optimoitu hot loop jatkuvaan ajoon.               -->
<!-- ============================================================ -->

### Ryhmä 9: Suorituskyky – Fast run -suorituspolku

[ ] Lisää `run()`-metodiin optimoitu fast-path-silmukka: paikalliset viittaukset usein käytettyihin metodeihin/muuttujiin, vähemmän funktiokutsuja per käsky ja poikkeuspolku erotettuna normaalista nopeasta polusta. Nykyinen `step()` säilytetään debuggausta varten.
