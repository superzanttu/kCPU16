# pyright: reportMissingImports=false
"""Debug-tila kCPU16-emulaattorille.

Sisältää breakpoint-hallinnan ja rekisterimuutosten seurannan.

Tämä moduuli on tarkoituksella erillinen TUI:sta (``tui.py``), koska
Textualin ``App``-luokalla on oma ``debug``-property, joka menisi
ristiin, jos debug-tila pidettäisiin suoraan App-instanssissa.
Erillinen ``DebugState``-dataluokka ratkaisee tämän: TUI luo yhden
``DebugState``-instanssin (``self.dbg``) ja kutsuu sen metodeja
suorituksen aikana.

Käyttökonteksti
---------------
- TUI kutsuu ``toggle_breakpoint()``-metodia, kun käyttäjä painaa F2
  tai kirjoittaa ``bp <addr>``-komennon.
- ``snapshot_registers()``-metodia kutsutaan jokaisen step/run-askeleen
  jälkeen, jotta TUI voi korostaa muuttuneet rekisterit punaisella.
- ``has_breakpoint()``-metodia kutsutaan run-silmukassa, jotta
  suoritus pysähtyy breakpointiin.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class DebugState:
    """Debuggerin tila: breakpointit ja rekisterimuutosten seuranta.

    Dataclass, joka kapseloi kaiken debug-session-aikana tarvittavan
    tilan. TUI luo tästä yhden instanssin (``self.dbg``) ja käyttää
    sitä koko session ajan.

    Attributes
    ----------
    breakpoints : set[int]
        Joukko muistiosoitteita (0x0000 - 0xFFFF), joihin suoritus
        pysähtyy run-tilassa. Osoitteet vastaavat PC-arvoja, eli
        konekielisen käskyn ensimmäisen sanan osoitetta muistissa.
    prev_registers : dict[str, int]
        Edellisen ``snapshot_registers()``-kutsun tallentamat
        rekisteriarvot. Käytetään vertailupohjana seuraavassa
        kutsussa, jotta voidaan tunnistaa mitkä rekisterit muuttuivat
        viimeisimmän käskyn suorituksen aikana. Avaimet ovat
        rekisterinimiä (esim. ``"R0"``, ``"SP"``, ``"PC"``).
    """

    breakpoints: set[int] = field(default_factory=set)
    prev_registers: dict[str, int] = field(default_factory=dict)

    def toggle_breakpoint(self, addr: int) -> bool:
        """Lisää tai poista breakpoint annettuun osoitteeseen.

        Jos osoitteessa on jo breakpoint, se poistetaan. Muuten
        lisätään uusi.

        Parameters
        ----------
        addr : int
            Muistiosoite (tyypillisesti 0x0000 - 0xFFFF), johon
            breakpoint asetetaan tai josta se poistetaan.

        Returns
        -------
        bool
            ``True`` jos breakpoint lisättiin, ``False`` jos poistettiin.
        """
        if addr in self.breakpoints:
            self.breakpoints.discard(addr)
            return False
        self.breakpoints.add(addr)
        return True

    def has_breakpoint(self, addr: int) -> bool:
        """Tarkista onko annetussa osoitteessa breakpoint.

        Kutsutaan TUI:n run-silmukassa jokaisen käskyn jälkeen.
        Jos palauttaa ``True``, suoritus pysäytetään ja kontrolli
        palautetaan käyttäjälle.

        Parameters
        ----------
        addr : int
            Tarkistettava muistiosoite (tyypillisesti CPU:n PC-arvo).

        Returns
        -------
        bool
            ``True`` jos osoitteessa on breakpoint.
        """
        return addr in self.breakpoints

    def snapshot_registers(self, regs: dict[str, int]) -> dict[str, bool]:
        """Vertaa nykyisiä rekistereitä edellisiin ja tallenna uusi tilanne.

        Metodi tekee kaksi asiaa:

        1. **Vertailu**: Jokaisen rekisterin nykyistä arvoa verrataan
           edellisen kutsun tallentamaan arvoon (``self.prev_registers``).
           Tuloksena palautetaan sanakirja, jossa avain on rekisterin
           nimi ja arvo on ``True``, jos kyseinen rekisteri muuttui.
        2. **Tallennus**: Nykyiset rekisteriarvot kopioidaan talteen
           seuraavaa vertailua varten. Kopio tehdään ``dict(regs)``-
           kutsulla, jotta alkuperäisen sanakirjan myöhemmät muutokset
           eivät vaikuta tallennettuun tilaan.

        TUI käyttää palautettua sanakirjaa rekisteripaneelin
        renderöinnissä: muuttuneet rekisterit näytetään punaisella
        ja muuttumattomat normaalilla värillä.

        Parameters
        ----------
        regs : dict[str, int]
            CPU:n nykyiset rekisteriarvot. Avaimet ovat rekisterinimiä
            (esim. ``"R0"``, ``"SP"``, ``"PC"``), arvot 16-bittisiä
            kokonaislukuja.

        Returns
        -------
        dict[str, bool]
            Sanakirja, jossa jokaiselle rekisterille ``True`` tarkoittaa,
            että arvo muuttui edellisen kutsun jälkeen. Ensimmäisellä
            kutsukerralla kaikki rekisterit merkitään muuttuneiksi,
            koska ``prev_registers`` on tyhjä.
        """
        changed = {}
        for name, value in regs.items():
            changed[name] = self.prev_registers.get(name) != value
        self.prev_registers = dict(regs)
        return changed

    def clear_breakpoints(self) -> None:
        """Poista kaikki breakpointit.

        Kutsutaan kun käyttäjä antaa ``bp clear``-komennon tai kun
        session nollataan.
        """
        self.breakpoints.clear()
