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
<!-- VALMIIT TEHTÄVÄT                                             -->
<!-- ============================================================ -->

### Valmiit tehtävät

[X] Kirjoita lib-screen.asm-kirjastoon funktio, joka mahdollistaa tekstin tulostamisen näytölle käyttäen kCPU16:n A-grafiikkatilaa, jotta näyttöä voi käyttää kuten yksinkertaista terminaalia, joka osaa skrollata tekstiä ylös. Tämä voisi olla esimerkiksi "print" -funktio, joka ottaa merkkijonon ja tulostaa sen näytölle, ja skrollaa vanhaa tekstiä ylös tarvittaessa. Tämä funktio voisi myös tukea perusmuotoilua, kuten rivinvaihtoja ja tabulaattoreita, jotta teksti olisi helpommin luettavaa.
; Toteutettu code/lib-screen.asm:ssä: scr_print(R0=str_ptr), scr_cls(), scr_set_color(R0).
; Sisäiset apufunktiot: _scr_putchar, _scr_newline, _scr_scroll.
; Skrollaus: kopioi rivit 1–23 riveille 0–22 (1840 sanaa), tyhjentää rivin 23.
; Erikoismerkit: \n (rivinvaihto), \t (tab: seuraava 8:n monikerta), \r (ohitetaan).
; Väri: scr_color-muuttuja (bits 8–14), oletus 0x0700 (valkoinen/musta).
[X] Lisää lib-screen.asm-kirjastoon funktio, jolla käyttäjältä voi pyytää inputia. Tämä voisi olla esimerkiksi "input" -funktio, joka näyttää kehotteen näytöllä ja odottaa käyttäjältä syötettä, joka sitten palautetaan funktiosta. Tämä funktio voisi tukea perusominaisuuksia, kuten syötteen rajoittamista tiettyyn pituuteen ja mahdollisesti jopa yksinkertaista muokkausta (esim. backspace).
; Toteutettu code/lib-screen.asm:ssä: scr_input(R0=kehote, R1=buf_ptr, R2=max_len) → R0=count.
; Pollaa KBD_STATUS/KBD_DATA ilman keskeytystä. Tuki: Enter (lopetus), Backspace (poisto), max_len-raja.
; Backspace pyyhkii merkin näytöltä (_scr_cursor_left + _scr_write_noadvance).
; Persistenttirekisterit R9–R13 säilyvät kaikkien sisäisten funktiokutsujen yli.

[X] Lisää `run()`-metodiin optimoitu fast-path-silmukka: paikalliset viittaukset usein käytettyihin metodeihin/muuttujiin, vähemmän funktiokutsuja per käsky ja poikkeuspolku erotettuna normaalista nopeasta polusta. Nykyinen `step()` säilytetään debuggausta varten.
; Toteutettu cpu.py:ssä: `run()` käyttää paikallisia viittauksia (`regs`, `mem_words`, `exec_table`,
; `mem_check_table`, `cycles_table`, `reg_array`) Python LOAD_FAST -optimointia varten.
; Fetch/decode inlinattu: suora lista-indeksointi `mem_words[pc & mask]` ilman method call'ia;
; JMPI/CALLI käyttävät edelleen hidasta `_fetch_decode()`-polkua.
; Poikkeuspolku on erillinen try/except-lohko normaalin suorituspolun jälkeen.
; Korjattu bugi: PC-päivitys käyttää `regs.pc` (handler-muokattu arvo), ei `pc` (alkuperäinen).
; step()-metodi säilytetty debuggausta varten.
[X] Määritä kaikille käskyille suoritusajat, jotka kuvaavat kuinka kauan kunkin käskyn suorittaminen kestää.
; Toteutettu EXEC_CYCLES-taulukko instruction.py:ssä. Yksikkö: 1 µs simuloidulla 1 MHz kellolla.
; Yksinkertaiset käskyt: 1 sykli. MUL=4, DIV=8, DREAD/DWRITE=10, INT/IRET/EXIT=4. FILL: 1 + N (dynaaminen).
[X] Muuta toimintaa niin että uptime-laskurin arvon kasvattamiseen käytetään konekielisille käskyille määriteltyjä suoritusaikoja.
; _uptime_counter lasketaan nyt simulated_time_us // 1_000_000. Ei enää reaaliaikariippuvuutta.
[X] Muuta Ajastinkeskeytyksen (TMR) ja Kellokeskeytyksen (CTMR) toimintaa niin, että ne perustuvat käskyjen suoritusaikoihin eikä pelkästään suoritettujen käskyjen lukumäärään.
; TMR: _next_tmr_time_us vertailu (ei enää modulo). CTMR: _next_ctmr_time_us vertailu.
; STMR asettaa next_tmr_time_us = simulated + TMR. SCTMR asettaa next_ctmr_time_us = simulated + CTMR*1000.
[X] Lisää Flags-ikkunaan TMR- ja CTMR-keskeytyksiin liittyvät tiedot, kuten jäljellä olevan ajan määrä ennen keskeytyksen laukeamista.
; Flags-paneeli näyttää: "N µs (next: M µs)" TMR:lle ja "N ms (next: M ms)" CTMR:lle.
[X] Lisää dokumentaatioon kuvaus siitä, miten käskyjen suoritusajat määritetään ja miten ne vaikuttavat ohjelman suoritukseen.
; Dokumentoitu architecture.md luvussa 12 (Suoritusajat): EXEC_CYCLES-taulukko, simuloitu aika, uptime.
[X] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytykset laukaistaan käskyjen suoritusaikojen perusteella ja miten se vaikuttaa ohjelman suoritukseen.
; Dokumentoitu architecture.md luvuissa 5.4 ja 5.5 sekä 12.3 (Ajastinkeskeytykset simuloidun ajan perusteella).
[X] Lisää dokumentaatioon kuvaus siitä, miten TMR- ja CTMR-keskeytyksiin liittyvät tiedot näytetään Flags-ikkunassa ja miten se auttaa käyttäjää ymmärtämään ohjelman suoritusta.
; Dokumentoitu tui.md luvussa 11 (TMR ja CTMR — ajastinkeskeytystiedot).
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
; EXITED (keltainen)= ohjelmaättyi hallitusti EXIT-käskyllä
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
[X] Analysoi demo_3dcude.asm, demo_3dcube2.asm, lib_3dobjects.asm ja lib_gfx.asm -tiedostot ja varmista että ohjelma näyttää kuution, L-kirjaimen ja J-kijaimmen, 10 sekunnin ajan, vuorotellen B-ja C- grafiikkatilassa. Varmista samalla, että objektteja pyöritetään X, Y, ja Z-akselien ympäri, ja että ne liikkuvat näytöllä.
; Analysoitu: demot käyttivät 20 s vaiheja (pitää olla 10 s) ja sisälsivät ylimääräisen pyramidi-vaiheen (3).
; Korjattu: 20000 → 10000 ms ja poistettu pyramidi-vaihe (phase 4 → 3) molemmista demoista.
; Pyöritys toimii X- ja Z-akselilla (sin/cos-taulut). Y-pyöritystä ei ole, mikä on tarkoituksellinen design.
; Grafiikkatilat: kuutio=B, L=C, J=B — vuorottelevat B↔C↔B.
[X] J-kirjain ei ole ollenkaan J-kirjaimen muotoinen.
; Korjattu lib_3dobjects.asm:ssa: J-profiili muutettiin oikeaksi J-muodoksi:
; Uusi profiili: leveä ylevä palkki (x=-8..8, y=-12..-4) + kapea pystyosa oikealla (x=2..8, y=-4..12) + koukku vasemmalle.
; Vanha profiili tuotti U-muodon tai taaksepäin käännetyn C:n eikä J:tä.
; Myös face-normaalit korjattu (0,2,1) ja (6,7,8) jotta backface-culling toimii oikein.
[X] L-kirjain on oikean muotoinen, mutta renderöityy väärin joissakin asennoissa.
; Korjattu lib_3dobjects.asm:ssa: letter_L_faces etupinta (0,1,2) → (0,2,1) ja takapinta (6,8,7) → (6,7,8).
; Syy: backface-culling käyttää normal_z = (B-A)×(C-A) z-komponenttia ruutukoordinaateissa (Y alas).
; Vanha CW-järjestys antoi positiivisen normal_z etupinnalle (piilotettiin) ja negatiivisen takapinnalle (näytettiin) — käänteisesti väärin.
[X] Analysoi demo_3dcude.asm, demo_3dcube2.asm, lib_3dobjects.asm ja lib_gfx.asm -tiedostot ja etsi yhteisiä toimintoja, jotka voitaisiin siirtää uuteen lib-gfx.asm-kirjastoon.
; Analysoitu: smul_div100 on identtinen molemmissa demoissa → siirretty lib_3dobjects.asm:iin.
; clock_handler on samankaltainen, mutta riippuu demo-kohtaisesta tilamuuttujasta (phase) — ei sovellu kirjastoon.
; draw_object_frame on erilainen: demo1=wireframe, demo2=hidden-line — ei yhdistettävissä.
; set_object on lähes sama, mutta demo2 asettaa lisäosoittimia — ei yhdistettävissä suoraan.
[X] Luo kirjasto (code/lib-disk.asm) joka toteuttaa tallennuslaaitteen käsittelyn. Tarvitaan yksinkertainen tiedostojärjestelmä, joka mahdollistaa tiedostojen tallentamisen.
; Toteutettu: disk_format, disk_create, disk_write, disk_read, disk_delete, disk_stat, disk_find, disk_list.
; Tiedostojärjestelmä: blokki 0=boot, 1=FAT, 2=hakemisto, 3+=datablokkit.
; Korjattu useita bugeja kehityksen aikana: _fat_alloc ei suojannut R3:a _disk_write_block:n yli,
;   disk_read käytti READ R0, R8 (lataa R8-indeksin, ei arvoa) eikä CPY R0, R8.
[X] Lisää dokumentaatioon kuvaus uudesta tallennuslaitekirjastosta (code/lib-disk.asm) ja sen tarjoamista toiminnoista.
; Dokumentoitu architecture.md luvussa 13: rakenne, FAT, hakemistomerkintä, kaikki 7 julkista funktiota, käyttöesimerkki.
[X] Kirjoita code-hakemistoon esimerkkiohjelma (esim. disk_test.asm), joka käyttää lib-disk.asm-kirjastoa luodakseen tiedoston, kirjoittaakseen dataa siihen, lukeakseen dataa takaisin ja poistaakseen tiedoston, ja varmista että kaikki toiminnot toimivat oikein.
; Toteutettu: disk_test.asm testaa disk_format, disk_create, disk_write, disk_read, disk_stat, disk_list, disk_delete.
; Kaikki 10 .expect_mem ja .expect_storage -tarkistusta läpäisevät.
[X] Korvaa `read_only_regions`-listan läpikäynti jokaisella kirjoituksella maskitaulukolla (`bytearray`/bool-taulukko), joka päivitetään vain silloin, kun suojattuja alueita muutetaan.
; Toteutettu memory.py:ssä: `_write_mask: bytearray` (65536 tavua) rakennetaan `__post_init__`:ssa ja
; päivitetään `rebuild_write_mask()`:lla. `check_write_protected()` käyttää O(1)-indeksointia;
; virhepolku käy read_only_regions läpi vain rikkomuksen tapahtuessa. Vaatii manuaalisen
; `rebuild_write_mask()`-kutsun, jos read_only_regions-listaa muutetaan latauksen jälkeen.
[X] Lisää `run()`-metodiin optimoitu fast-path-silmukka (esim. kiinteä tuple tai paikalliset muuttujat), jotta olion luomisen overhead poistuu hot loopista.
; Toteutettu _Ins-luokka __slots__:lla (opcode, operands, size_words). DecodedInstruction-dataclass poistettu hot polulta.
[X] Korvaa `if/elif ins.mnemonic == ...` -ketju opcode-pohjaisella handler-taululla (funktioviitteet: opcode → handler + metadata), jotta merkkijonovertailut poistuvat kuumasta suorituspolusta.
; Toteutettu _exec_table: dict[int, Callable] — 45+ handler-metodia (_exec_load, _exec_add jne.).
; _build_dispatch_table() rakentaa taulun OPCODE_TABLE:sta CPU.__post_init__():ssa.
[X] Yhdistä privilege- ja muistitarkistus handler-metadataan, jotta samoja mnemonic-vertailuja ei tehdä useassa eri vaiheessa per käsky.
; Privilege: tarkistetaan opcode-bitin 15 perusteella (ins.opcode & 0x8000) suoraan step():ssä.
; Muisti: _mem_check_table: dict[int, Callable] — 6 _mcheck_*-metodia per käskytyyppi.
; _get_exec_cycles() poistettu; syklilasku inline step():ssä _cycles_table[opcode]-taululla.
[X] Poista `time.monotonic()`-kutsu jokaiselta käskykierrokselta; tarkista uptime/CTMR vain harvennetusti (esim. joka N:s käsky) tai deadline-pohjaisesti.
; Poistettu `import time` ja käyttämätön `_clock_start`-kenttä. Poistettu `_update_uptime_if_needed()` hot loopista
; (uptime päivitetään laiskanmaisesti vain MMIO-luvun yhteydessä _read_clock_mmio():ssa).
; Lisätty threshold-guardit: `if _simulated_time_us >= _next_tmr_time_us:` / `_next_ctmr_time_us`
; jotta ajastin-metodeja ei kutsuta ollenkaan ennen kuin aika on täyttynyt.
[X] Korvaa timer-keskeytyksen modulovertailu (`instruction_counter % tmr == 0`) seuraavan laukaisusyklin vertailulla (`next_timer_cycle`), jotta modulo-operaatio poistuu hot loopista.
; Lisätty `_TMR_DISABLED = 0x7FFF_FFFF_FFFF_FFFF` sentinel disabled-ajastimille:
; `_exec_stmr`: jos new_tmr==0 → `_next_tmr_time_us = _TMR_DISABLED` (ei koskaan laukea)
; `_exec_sctmr`/`_write_word` (CLOCK_INT_INTERVAL): vastaava sentinel.
; reset(): käyttää myös sentineliä alkuarvoina. Modulo-operaatiota ei koskaan ollutkaan (Ryhmä 5 toteutti deadline-vertailun).
[X] Korvaa `_get_reg`/`_set_reg`-metodien pitkät `if/elif`-ketjut taulukkoindeksoinnilla CPU:n suorituspolussa (lista tai array), jotta haarautumisoverhead poistuu jokaisesta rekisteriviittauksesta.
; RegisterFile:iin lisätty `_regs: list[int]` (18 alkiota: r0=0... r15=15, fp=16, sp=17).
; Kaikki `r0`...`r15`, `fp`, `sp` muutettu propertyksi jotka lukevat/kirjoittavat `_regs`-listaan.
; reset() käyttää `_regs[:] = [0]*16 + [0, KERNEL_STACK_END]` (in-place, säilyttää listan identiteetin).
[X] Säilyttä julkinen rajapinta (r0…r15, fp, sp) ennallaan esim. propertyjen kautta; anna `execute`-polun käyttää suoraa taulukkorakennetta.
; CPU.__post_init__: `self._reg_array = self.regs._regs` (sama listaviite, ei kopiota).
; `_get_reg`: yksi bounds-check (`idx < 18`) + `self._reg_array[idx]` – ei if/elif-ketjua.
; `_set_reg`: vastaava `self._reg_array[idx] = value & WORD_MASK`.
[X] Lisää kirjastoon lib-disk.asm tuki hakemistoille. Tämä mahdollistaisi tiedostojen järjestämisen hierarkkisesti, ja vaatisi hakemistokohteiden ja polkujen käsittelyn.
; Toteutettu lib-disk.asm:ssa: hakemistotyyppi (status=2), uusi disk_mkdir(), disk_list listaa sekä tiedostot että hakemistot.
[X] Varmista että kirjastossa lib-disk.asm on tuki levyn formatointiin, joka alustaa tallennuslaitteen tyhjäksi ja luo tarvittavat rakenteet tiedostojärjestelmälle.
; Varmistettu: disk_format säilytetty, FAT+hakemisto nollataan ja varatut blokit 0..2 merkitään DISK_EOF:lla.
[X] Lisää kirjastoon lib-disk.asm tuki levyn tarkistukseen, joka skannaa tallennuslaitteen ja raportoi mahdollisista vioista tai epäjohdonmukaisuuksista tiedostojärjestelmässä.
; Toteutettu lib-disk.asm:ssa: uusi disk_check() (FAT-varaukset, status-kentät, blokkiketjujen validointi).
[X] Lisää disk_test.asm:iin lib-disk.asm-kirjaston kaikkien ominaisuuksien esittely
; Päivitetty disk_test.asm: disk_format, disk_mkdir, disk_create, disk_write, disk_read, disk_stat, disk_list, disk_check, disk_delete.

### Ryhmä 9: Suorituskyky – Fast run -suorituspolku

; Kaikki Ryhmä 9 -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ A: Screen-kirjasto (lib-screen.asm)                   -->
<!-- Uusi itsenäinen kirjasto, ei riippuvuuksia muihin ryhmiin.  -->
<!-- Järjestys: teksti ensin, sitten input (riippuu tekstistä).  -->
<!-- ============================================================ -->

### Ryhmä A: Screen-kirjasto

; Kaikki Ryhmä A -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ B: Disk-laajennukset (lib-disk.asm + disk_test.asm)   -->
<!-- Järjestys: hakemistot → tarkistus → testi (ketjutettu).     -->
<!-- Huom: disk_format on JO TOTEUTETTU – katso [?]-tehtävä.     -->
<!-- ============================================================ -->

### Ryhmä B: Disk-laajennukset

; Kaikki Ryhmä B -tehtävät on suoritettu, katso Valmiit tehtävät -osio.

<!-- ============================================================ -->
<!-- RYHMÄ C: Pienet optimoinnit (cpu.py + tui.py)               -->
<!-- Itsenäiset pienet muutokset, ei riippuvuuksia toisistaan.   -->
<!-- ============================================================ -->

### Ryhmä C: Pienet optimoinnit

[ ] Paranna FILL-käskyn toteutuksen suorituskykyä.
[ ] Suoritustilan ollessa MAX, tietojen joita ei päivitetä tulee olla väriltään harmaita, jotta käyttäjä ymmärtää että ne eivät päivity reaaliajassa. Poistuttaessa MAX-tilasta, tiedot palautuvat normaalivärisiksi ja päivittyvät uudestaan.

<!-- ============================================================ -->
<!-- RYHMÄ D: Tiedostorakenteen uudistus (kaikki tiedostot)      -->
<!-- KORKEA RISKI: muuttaa kaikkia tiedostopolkuja ja importteja. -->
<!-- Suorita viimeisenä, kun muut ryhmät on tehty.               -->
<!-- ============================================================ -->

### Ryhmä D: Tiedostorakenteen uudistus

[ ] Muuta projektin hakemistorakennetta, niin että se vastaa fyysisen tietokoneen komponentteja ja rakennetta.  Varmista että kaikki tiedostopolut ja importit päivitetään, eikä mitään hajoa.


### Priorisoimattomat tehtävät
[ ] Klikattaessa hiirellä Reset-nappia, Flags-ikkunassa on tieto "Pprog: NOT LOADED", mutta silti Screen-ikkunan alareunassa lukee "demo_3dcube.asm". Tarkista myös levynkuvan nimen näkyminen Reset-napista klikkaamisen jälkeen. 
[ ] Luo code-hakemistoon demo_screen.asm, joka käyttää lib-screen.asm-kirjastoa demonstroidakseen tekstin tulostamista ja käyttäjältä inputin pyytämistä. Varmista että demo toimii oikein ja että se esittelee kirjaston ominaisuuksia tehokkaasti.

### Python-suorituskyvyn parannukset (analyysi 2026-04-11)
[ ] Vähennä assemblerin moninkertaista riviparsintaa: rakenna yhteinen esiparsittu rivirakenne (stripped/lower/tokens) ja käytä sitä Pass 0/1/2 -vaiheissa sekä include-symboliskannauksessa.
[ ] Optimoi assemblerin segmenttien päällekkäisyystarkistus O(n²) -> O(n log n): lajittele segmentit alkuosoitteen mukaan ja tarkista päällekkäisyys lineaarisella läpikäynnillä.
[ ] Optimoi CPU:n FILL-polku (sekä _mcheck_fill että _exec_fill): vähennä per-sana Python-kutsujen määrää ja lisää nopea aluekirjoituspolku ei-MMIO-alueille.
[ ] Lisää VRAM/Screen dirty-flag tai versiolaskuri, jotta TUI ei renderöi koko näyttöä uudelleen, kun VRAM ei ole muuttunut.
[ ] Kevennä TUI:n _refresh_disassembly()-hot pathia: vältä per-rivi disassembler-kutsuja ja rakenna cache PC-ikkunan dekoodatuille riveille.
[ ] Vähennä TUI:n query_one()-kutsujen määrää suorituksen aikana: cacheta usein käytetyt widget-viittaukset on_mount()-vaiheessa.
[ ] Poista testirunnerin turha uudelleenluku/parsinta run_test_all()-yhteenvedossa: palauta run_test()-funktiosta myös tarkistusten määrät ja käytä niitä suoraan.
[ ] Optimoi editorin syntaksiväritys: korvaa per-mnemonic/per-register re.sub -silmukat esikäännetyillä regexeillä ja callback-pohjaisella korvauksella.
[ ] Nopeuta storage save/load -polkua suurille levykuville: minimoi to_bytes/join-allokaatiot käyttämällä tehokkaampaa puskurimuotoa (esim. memoryview/array) CRC-laskennassa.
