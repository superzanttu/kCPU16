Tässä dokumentissa kuvataan ohjelman tekstipohjaisen käyttöliittymän asettelu.

+-------------------------------------------------+
|toolbar                                          |
+--------------+-------------+--------------------+
|screen        |diassembly   |editor              |
|              |             |                    |
+--------------+-------------+                    |
|output                      |                    |
+                            |                    |
|                            |                    |
+----------------------------+--------------------+
|input                       |flags   | registers |
+----------------------------+--------+-----------+

# screen

Tähän mahtuu 80x24 merkkiä, eli VRAM:n sisältö. 
Ikkuna on kiinteän kokoinen, eikä sitä voi muuttaa, eikä sitä voi skrollata. Näytölle mahtuu siis aina 80x24 merkkiä, eikä vanhaa sisältöä voi skrollata pois.
80x24 merkin alueen ympärillä on ohut reunus.
Ikkunan yläosassa, reunaviivan päällä on sen nimi "Screen"

# output

Tähän ikkunaan tuostuu käyttäjän antamisen komentojen tulosteet.
Tähän ikkunaan ohjelma tulostaa lokitiedot, jotka kertovat sen toiminnasta.
Ikkunan ympärillä on ohut reunus.
Ikkunan yläosassa, kehyksen päällä on sen nimi "Output"
Ikkunan sisältö skrollataan pystysuunnassa.
Command output-ikkuna on yhtä leveä kuin screen ja diassembly-ikkunat yhteensä.

# input

Tähän käyttäjä kirjoittaa komentoja, jotka tulostuvat merkki kerrallaan näytölle.
Ikkunan ympärillä ei ole reunusta.
Ikkunan leveys on yhtä leveä kuin screen ja diassembly-ikkunat yhteensä.
Ikkunan korkeus on kiinteästi yksi rivi.
Ikkuna sijaitsee kiinteästi terminaalin alareunassa.

# disassembly

Tähän ohjelma tulostaa muistin sisällön diassemblyn.
Ikkunan ympärillä on ohut reunus.
Ikkunassa on välilehteä "Diassembly", "Memory" ja "Stack"
"Diassembly"-välilehdelle tulostuu muistin sisällön perusteella tehty diasseblylistaus.
"Memory"-välilehdelle tulostuu muistin sisältö.
"Stack"-välilehdelle tulostuu prosessorin stack.
Ikkunan leveys on kiinteä, ja määräytyy siihen tulostettavan tiedon mukaan toteutusvaiheessa.
Ikkunan korkeus säätyy automaattisesti.
Ikkunan sisältö skrollataan pystysuunnassa.

# flags 

Tähän ikkunaan ohjelma tulostaa lippujen tilan, sekä prosessorin tilatiedon ja muut sen toiminnasta kertovat tiedot.
Ikkunan ympärillä on ohut reunus.
Ikkunan yläosassa, kehyksen päällä on sen nimi "Flags"
Ikkunan leveys ja korkeus ovat kiinteitä, ja mmääräytyvät siihen tulostettavan tiedon mukaan toteutusvaiheessa.
Ikkunan sisältö pysyy paikallaan, eikä sitä voi skrollata.

# editor

Tässä ikkunassa tapahtuu lähdekielen editointi.
Ikkunan koko määräytyy sen mukaan, mitä muiden ikkunoiden kokojen määrittämisen jälkeen jää häljelle.
Ikkunan ympärillä on ohut kehys.
Ikkunan yläosassa, kehyksen päällä lukee sen nimi "Editor"
Ikkunan sisältö skrollataan pystysuunnassa.

# registers

Tähän ikkunaan ohjelma tulostaa prosessorin rekisterien tila.
Ikkunan leveys ja korkeus ovat kiinteitä, ja määräytyvät siihen tulostettavan tiedon mukaan toteutusvaiheessa.
Ikkunan ympärillä on ohut reunus.
Ikkunan yläosassa, kehyksen päällä on sen nimi "Registers"
Ikkunan sisältö pysyy paikallaan, eikä sitä voi skrollata.
Flags- ja Registers-ikkunat ovat saman korkuisia, korkeuden määrää se, joka on korkeampi.
Flags- ja Registers-ikkunan ovat yhdessä yhtä leveät kuin Editor-ikkuna.

# toolbar

Tähän ohjelma luo tärkeimpien toimintojen pikavalinnat painikkeina, joissa lukee sen toiminnon nimi.
Tämä käyttää koko terminaalin leveyden, ja on kiinteän korkuinen.
Ikkunan ympärillä ei ole reunusta.
Ikkunan sisältö pysyy paikallaan, eikä sitä voi skrollata.