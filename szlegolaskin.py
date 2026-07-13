#!/usr/bin/env python3
"""
szlegolaskin.py - LEGO-palikoiden yhdistelmälaskuri

Laskee kuinka monta erilaista tapaa N kappaletta k×l-kokoisia LEGO-palikoita
voidaan liittää yhteen (palikat kiinnittyvät nuppien kautta, pysty- tai
vaakatasossa).

Käyttö:
    python szlegolaskin.py [tiedostonimi] [palikoita] [korkeus] [leveys] [aloitus]

Argumentit (numeeriset luetaan järjestyksessä; tiedostonimi on muu merkkijono):
    tiedostonimi  Tietokantahakemisto (oletus: kombot.db)
    palikoita     Yhdistelmään käytettävien palikoiden määrä (oletus: 6)
    korkeus       Palikan korkeus nuppeina (oletus: 4)
    leveys        Palikan leveys nuppeina (oletus: 2)
    aloitus       Mistä palikkamäärästä laskenta aloitetaan (oletus: 1)

Esimerkki:
    python szlegolaskin.py kombot.db 6 4 2 1
"""

import sqlite3
import sys
import time


# ---------------------------------------------------------------------------
# Palikoiden koodaus ja dekoodaus
# ---------------------------------------------------------------------------


def koodaa(z: int, x: int, y: int, asento: int) -> str:
    """Koodaa palikan sijainnin ja asennon yhdeksi Unicode-merkiksi.

    Args:
        z: Kerros (0 = alin).
        x: X-koordinaatti (-6..+6 käytännössä).
        y: Y-koordinaatti (-6..+6 käytännössä).
        asento: 0 = normaali, 1 = 90° käännetty.

    Returns:
        Yksi Unicode-merkki, joka koodaa kaikki neljä arvoa.
    """
    return chr(z * 2048 + (x + 6) * 64 + (y + 6) * 2 + asento + 1)


def dekoodaa(pala: str) -> tuple[int, int, int, int]:
    """Dekoodaa merkin palikan z-, x-, y-koordinaateiksi ja asennoksi.

    Args:
        pala: Yksittäinen koodattu merkki.

    Returns:
        Tuple (z, x, y, asento).
    """
    num = ord(pala) - 1
    z = num // 2048
    x = (num % 2048) // 64 - 6
    y = (num % 64) // 2 - 6
    return z, x, y, num % 2


# ---------------------------------------------------------------------------
# Apufunktiot kombinaatioiden käsittelyyn
# ---------------------------------------------------------------------------


def hae_minimit(kombo: str) -> tuple[int, int, int]:
    """Hakee yhdistelmän pienimmät z-, x- ja y-arvot.

    Args:
        kombo: Yhdistelmä koodattuna merkkijonona.

    Returns:
        Tuple (min_z, min_x, min_y).
    """
    min_z = min_x = min_y = 100
    for pala in kombo:
        z, x, y, _ = dekoodaa(pala)
        if z < min_z:
            min_z = z
        if x < min_x:
            min_x = x
        if y < min_y:
            min_y = y
    return min_z, min_x, min_y


def hae_mitat(kombo: str, leveys: int, korkeus: int) -> tuple[int, int, int]:
    """Hakee yhdistelmän rajoittavan suorakulmion mitat.

    Palauttaa suurimmat arvot x+leveys ja y+korkeus yli kaikkien palikoiden,
    sekä suurimman z-arvon. Näitä käytetään rotaatioissa normalisointiin.

    Args:
        kombo: Yhdistelmä koodattuna merkkijonona.
        leveys: Palikan leveys nuppeina.
        korkeus: Palikan korkeus nuppeina.

    Returns:
        Tuple (mitta_z, mitta_x, mitta_y).
    """
    mitta_z = mitta_x = mitta_y = -100
    for pala in kombo:
        z, x, y, asento = dekoodaa(pala)
        lev = leveys if asento == 0 else korkeus
        kor = korkeus if asento == 0 else leveys
        if z > mitta_z:
            mitta_z = z
        if x + lev > mitta_x:
            mitta_x = x + lev
        if y + kor > mitta_y:
            mitta_y = y + kor
    return mitta_z, mitta_x, mitta_y


# ---------------------------------------------------------------------------
# Tietokanta
# ---------------------------------------------------------------------------


class KomboDB:
    """SQLite-tietokantarajapinta yhdistelmien tallentamiseen.

    Jokainen palikkamäärä tallennetaan omaan tauluunsa k1, k2, ... kN.
    PRIMARY KEY takaa, että vain uniikit yhdistelmät tallentuvat.
    """

    def __init__(self) -> None:
        """Alustaa tietokantaobjektin."""
        self._conn: sqlite3.Connection | None = None

    def alusta(self, tiedostonimi: str) -> None:
        """Avaa yhteyden tietokantaan.

        Args:
            tiedostonimi: Polku SQLite-tiedostoon.
        """
        self._conn = sqlite3.connect(tiedostonimi)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA synchronous=NORMAL")

    def luo_taulu(self, kierros: int) -> None:
        """Luo taulu kierroksen yhdistelmille, jos sitä ei vielä ole.

        Args:
            kierros: Palikkamäärä (taulunimi k<kierros>).
        """
        assert self._conn is not None
        self._conn.execute(
            f"CREATE TABLE IF NOT EXISTS k{kierros} (kombo TEXT PRIMARY KEY)"
        )
        self._conn.commit()

    def lisaa_kombo(self, kierros: int, kombo: str) -> None:
        """Lisää yksi yhdistelmä tietokantaan.

        Args:
            kierros: Palikkamäärä.
            kombo: Yhdistelmä koodattuna merkkijonona.
        """
        assert self._conn is not None
        self._conn.execute(
            f"INSERT OR IGNORE INTO k{kierros} (kombo) VALUES (?)",
            (kombo,),
        )
        self._conn.commit()

    def lisaa_kombot(self, kierros: int, kombot: list[str]) -> None:
        """Lisää useita yhdistelmiä tietokantaan kerralla.

        Args:
            kierros: Palikkamäärä.
            kombot: Lista yhdistelmistä koodattuina merkkijonoina.
        """
        assert self._conn is not None
        self._conn.executemany(
            f"INSERT OR IGNORE INTO k{kierros} (kombo) VALUES (?)",
            [(k,) for k in kombot],
        )
        self._conn.commit()

    def hae_kombot(self, kierros: int, alku: int, maara: int) -> list[str]:
        """Hakee sivutetun erän yhdistelmiä tietokannasta.

        Args:
            kierros: Palikkamäärä.
            alku: Ensimmäisen haettavan rivin indeksi.
            maara: Haettavien rivien enimmäismäärä.

        Returns:
            Lista yhdistelmistä.
        """
        assert self._conn is not None
        cur = self._conn.execute(
            f"SELECT kombo FROM k{kierros} LIMIT ? OFFSET ?",
            (maara, alku),
        )
        return [row[0] for row in cur.fetchall()]

    def lukumaara(self, kierros: int) -> int:
        """Palauttaa kierroksen yhdistelmien lukumäärän.

        Args:
            kierros: Palikkamäärä.

        Returns:
            Yhdistelmien lukumäärä.
        """
        assert self._conn is not None
        cur = self._conn.execute(f"SELECT COUNT(*) FROM k{kierros}")
        row = cur.fetchone()
        return row[0] if row else 0

    def poista_taulut(self, aloitus: int) -> None:
        """Poistaa taulut kierroksesta aloitus ylöspäin.

        Käytetään uudelleenlaskennan aloittamiseen tietystä kohdasta ilman
        että jo lasketut pienemmät yhdistelmät poistetaan.

        Args:
            aloitus: Ensimmäinen kierros, jonka taulu poistetaan.
        """
        assert self._conn is not None
        cur = self._conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'k%'"
        )
        tables = cur.fetchall()
        for (name,) in tables:
            try:
                n = int(name[1:])
                if n >= aloitus:
                    self._conn.execute(f"DROP TABLE IF EXISTS [{name}]")
            except ValueError:
                pass
        self._conn.commit()

    def sulje(self) -> None:
        """Sulkee tietokantayhteyden."""
        if self._conn is not None:
            self._conn.close()
            self._conn = None


# ---------------------------------------------------------------------------
# Yhdistelmälaskuri
# ---------------------------------------------------------------------------


class Laskuri:
    """LEGO-palikoiden yhdistelmälaskuri.

    Laskee kaikki uniikit tavat kiinnittää N samankokoista palikkaa yhteen.
    Kaksi yhdistelmää katsotaan samaksi, jos toinen saadaan toisesta
    kääntämällä 0, 90, 180 tai 270 astetta pystyakselin ympäri.

    Args:
        leveys: Palikan leveys nuppeina.
        korkeus: Palikan korkeus nuppeina.
    """

    def __init__(self, leveys: int, korkeus: int) -> None:
        """Alustaa laskurin palikan mitoilla.

        Args:
            leveys: Palikan leveys nuppeina.
            korkeus: Palikan korkeus nuppeina.
        """
        self.leveys = leveys
        self.korkeus = korkeus

    def normalisoi(self, kombo: str) -> str:
        """Siirtää yhdistelmää niin, että pienin x- ja y-koordinaatti on 0.

        Z-akselilla siirtoa ei tarvita, koska ensimmäinen palikka on aina
        kerroksessa 0.

        Args:
            kombo: Yhdistelmä koodattuna merkkijonona (ei välttämättä normalisoitu).

        Returns:
            Lajiteltu normalisoitu yhdistelmä.
        """
        _, min_x, min_y = hae_minimit(kombo)
        return "".join(
            sorted(
                koodaa(z, x - min_x, y - min_y, asento)
                for pala in kombo
                for z, x, y, asento in [dekoodaa(pala)]
            )
        )

    def paivita_versiot(self, kombo: str) -> list[str]:
        """Luo yhdistelmästä 0, 90, 180 ja 270 asteen rotaatioversiot.

        Ottaa syötteenä normalisoidun yhdistelmän ja tuottaa neljä versiota,
        joista kukin on myös normalisoitu ja lajiteltu. Kutsuja valitsee
        näistä pienimmän merkkijonon kaksoiskappaleiden välttämiseksi.

        Args:
            kombo: Normalisoitu ja lajiteltu yhdistelmä.

        Returns:
            Lista neljästä versiosta [0°, 90°, 180°, 270°].
        """
        leveys = self.leveys
        korkeus = self.korkeus
        _mitta_z, mitta_x, mitta_y = hae_mitat(kombo, leveys, korkeus)

        k90: list[str] = []
        k180: list[str] = []
        k270: list[str] = []

        for pala in kombo:
            z, x, y, asento = dekoodaa(pala)
            if leveys == korkeus:
                k90.append(koodaa(z, -y - korkeus + mitta_y, x, 0))
                k180.append(koodaa(z, -x - leveys + mitta_x, -y - korkeus + mitta_y, 0))
                k270.append(koodaa(z, y, -x - leveys + mitta_x, 0))
            else:
                lev = leveys if asento == 0 else korkeus
                kor = korkeus if asento == 0 else leveys
                k90.append(koodaa(z, -y - kor + mitta_y, x, 1 - asento))
                k180.append(koodaa(z, -x - lev + mitta_x, -y - kor + mitta_y, asento))
                k270.append(koodaa(z, y, -x - lev + mitta_x, 1 - asento))

        return [
            kombo,
            "".join(sorted(k90)),
            "".join(sorted(k180)),
            "".join(sorted(k270)),
        ]

    def paivita_sopivat(self, kombo: str, syvyys: int) -> set[str]:
        """Etsii kaikki palikat, jotka voivat kiinnittyä annettuun yhdistelmään.

        Käy läpi jokaisen yhdistelmän palikan ja kerää kaikki nuppien kautta
        kiinnittyvät palikat ylä- ja alapuolelta. Poistaa lopuksi palikat,
        jotka olisivat päällekkäisiä jonkin olemassa olevan palikan kanssa.

        Kaksoiskappaleiden syntymistä rajoitetaan syvyyden 1-2 tapauksissa
        xx-ehdolla: syvyys <= 2 sallii vain xx >= 0 (tai vastaavan rajan
        ei-neliömäisille palikoille), jolloin symmetriset yhdistelmät syntyvät
        ainoastaan kerran.

        Args:
            kombo: Normalisoitu yhdistelmä.
            syvyys: Nykyinen palikkamäärä + 1 (ts. lisättävä kierros).

        Returns:
            Joukko sopivista palikoista koodattuina merkkeinä.
        """
        leveys = self.leveys
        korkeus = self.korkeus
        sopivat: set[str] = set()
        paallekkaiset: set[str] = set()

        for pala in kombo:
            z, x, y, asento = dekoodaa(pala)
            lev = leveys if asento == 0 else korkeus
            kor = korkeus if asento == 0 else leveys

            # Kiinnittyvät palikat samalla asennolla
            for xx in range(-lev + 1, lev):
                for yy in range(-kor + 1, kor):
                    if syvyys > 2 or xx >= 0:
                        sopivat.add(koodaa(z + 1, x + xx, y + yy, asento))
                        if z > 0:
                            sopivat.add(koodaa(z - 1, x + xx, y + yy, asento))

            # Kiinnittyvät palikat eri asennolla (vain pitkulaisille palikoille)
            if leveys != korkeus:
                for xx in range(-kor + 1, lev):
                    for yy in range(-lev + 1, kor):
                        if syvyys > 2 or xx >= -(kor - 1) // 2:
                            sopivat.add(koodaa(z + 1, x + xx, y + yy, 1 - asento))
                            if z > 0:
                                sopivat.add(koodaa(z - 1, x + xx, y + yy, 1 - asento))

        # Kerätään kaikki olemassa olevien palikoiden kanssa päällekkäiset sijainnit
        for pala in kombo:
            z, x, y, asento = dekoodaa(pala)
            if asento == 0:
                for xx in range(-leveys + 1, leveys):
                    for yy in range(-korkeus + 1, korkeus):
                        paallekkaiset.add(koodaa(z, x + xx, y + yy, 0))
                if leveys != korkeus:
                    for xx in range(-korkeus + 1, leveys):
                        for yy in range(-leveys + 1, korkeus):
                            paallekkaiset.add(koodaa(z, x + xx, y + yy, 1))
            else:
                for xx in range(-korkeus + 1, korkeus):
                    for yy in range(-leveys + 1, leveys):
                        paallekkaiset.add(koodaa(z, x + xx, y + yy, 1))
                for xx in range(-leveys + 1, korkeus):
                    for yy in range(-korkeus + 1, leveys):
                        paallekkaiset.add(koodaa(z, x + xx, y + yy, 0))

        return sopivat - paallekkaiset

    def hae_ratkaisut(self, kierros: int, db: KomboDB) -> None:
        """Laskee kaikki kierros-palikan yhdistelmät ja tallentaa ne tietokantaan.

        Hakee (kierros-1)-palikan yhdistelmät tietokannasta 1000 kappaleen erissä,
        lisää niihin yksi kerrallaan kaikki sopivat palikat, normalisoi syntyneen
        yhdistelmän ja tallentaa sen pienimmän rotaatioversion tietokantaan.
        Tietokanta pitää huolen uniikkiudesta PRIMARY KEY -rajoitteella.

        Args:
            kierros: Palikkamäärä, jonka yhdistelmät lasketaan.
            db: Tietokantaobjekti tallennusta varten.
        """
        uudet_kombot: list[str] = []

        if kierros == 1:
            db.lisaa_kombo(kierros, koodaa(0, 0, 0, 0))
            return

        maara = db.lukumaara(kierros - 1)
        jaljella = maara
        laskuri = 0

        while jaljella > 0:
            era = min(jaljella, 1000)
            edelliset_kombot = db.hae_kombot(kierros - 1, maara - jaljella, era)
            jaljella -= era

            for kombo in edelliset_kombot:
                sopivat = self.paivita_sopivat(kombo, kierros)
                for palikka in sopivat:
                    normalisoitu = self.normalisoi(kombo + palikka)
                    versiot = self.paivita_versiot(normalisoitu)
                    uudet_kombot.append(min(versiot))

                laskuri += 1
                if laskuri % 5000 == 0 or laskuri == maara:
                    db.lisaa_kombot(kierros, uudet_kombot)
                    uudet_kombot.clear()
                    prosentti = laskuri * 100.0 / maara
                    print(
                        f"\r{kierros} palikkaa: {prosentti:.2f} %",
                        end="",
                        flush=True,
                    )


# ---------------------------------------------------------------------------
# Apufunktio yhdistelmän tulostamiseen
# ---------------------------------------------------------------------------


def tulosta_kombo(kombo: str) -> None:
    """Tulostaa yhdistelmän palikat luettavassa muodossa.

    Args:
        kombo: Yhdistelmä koodattuna merkkijonona.
    """
    for pala in kombo:
        z, x, y, asento = dekoodaa(pala)
        print(f"z = {z}, x = {x}, y = {y}, asento = {asento}")


# ---------------------------------------------------------------------------
# Pääohjelma
# ---------------------------------------------------------------------------


def main() -> None:
    """Lukee komentoriviargumentit, ajaa laskennan ja tulostaa tulokset.

    Numeeriset argumentit luetaan järjestyksessä (palikoita, korkeus, leveys,
    aloitus). Ei-numeerinen argumentti tulkitaan tiedostonimeksi.
    """
    numero_argumentit: list[int] = []
    tiedostonimi = "kombot.db"

    for a in sys.argv[1:]:
        try:
            numero_argumentit.append(int(a))
        except ValueError:
            tiedostonimi = a

    palikoita = numero_argumentit[0] if len(numero_argumentit) > 0 else 6
    korkeus = numero_argumentit[1] if len(numero_argumentit) > 1 else 4
    leveys = numero_argumentit[2] if len(numero_argumentit) > 2 else 2
    aloitus = numero_argumentit[3] if len(numero_argumentit) > 3 else 1

    print(f"Luodaan {palikoita} {korkeus}×{leveys} palikan yhdistelmät")

    aloitusaika = time.monotonic()
    db = KomboDB()
    db.alusta(tiedostonimi)

    laskuri = Laskuri(leveys, korkeus)
    db.poista_taulut(aloitus)

    for kierros in range(aloitus, palikoita + 1):
        db.luo_taulu(kierros)
        laskuri.hae_ratkaisut(kierros, db)
        maara = db.lukumaara(kierros)
        if kierros == 1:
            print(f"\r{kierros} palikka: {maara} ratkaisu                  ")
        else:
            print(f"\r{kierros} palikkaa: {maara} ratkaisua                  ")
        aika = time.monotonic() - aloitusaika
        print(f"  Kulunut aika {aika:.2f} sekuntia.")

    db.sulje()


if __name__ == "__main__":
    main()
