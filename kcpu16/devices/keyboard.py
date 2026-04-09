"""
Virtuaalinen nappaimistolaite kCPU16-emulaattorille.

Nappaimisto on erillinen laite, joka puskuroi nappaintapahtumia (painallukset
ja vapautukset) FIFO-jonoon. Laite on muistikarttattu (MMIO) osoitteisiin
KBD_DATA ($0020) ja KBD_STATUS ($0021). Erillista KGET-kaskya ei ole.

TOIMINTAPERIAATE:
------------------
1. Ulkoinen syote (esim. REPL tai GUI) kutsuu push_key(key_code) tai
   push_key_release(key_code)
2. Tapahtuma (8-bittinen skannikoodi) lisataan jonoon
3. _pending_interrupt-lippu asetetaan trueksi
4. CPU:n step()-metodi havaitsee keskeytyksen tarpeen ja laukaisee INT 6
   (INT_KEYBOARD) jos I=1 (keskeytykset sallittu)
5. Keskeytysrutiini lukee tapahtuman muistista osoitteesta KBD_DATA ($0020)

SKANNIKOODI-RAKENNE:
---------------------
   Bitti 7 (KBD_RELEASE_BIT = 0x80): 0 = painallus, 1 = vapautus
   Bitit 6-0: nappainkoodi (ASCII-arvo tai muu koodi, 0-127)

   Esimerkki:
     'A' painetaan -> 0x41  (65, KBD_RELEASE_BIT = 0)
     'A' vapautetaan -> 0xC1 (193, KBD_RELEASE_BIT = 1)

MMIO-OSOITTEET:
---------------
   KBD_DATA   = $0020  Lue: pops seuraava tapahtuma puskurista (0 jos tyhja)
   KBD_STATUS = $0021  Lue: tapahtumien maara puskurissa (0 = tyhja)

TODELLISTEN LAITTEIDEN VERTAILU:
----------------------------------
   PC (XT/AT): Generoi make-koodin painettaessa, break-koodi = make | 0x80
     vapautettaessa. Molemmat laukaisevat IRQ 1. Tama toteutus seuraa
     tata periaatetta.
   Commodore 64: CIA-piiri hoitaa skannauksen; keypress/release via NMI/IRQ.
   BBC Micro: System VIA (6522) hoitaa keskeytykset nappaimistolta.

Note:
    Nappaimet koodataan ASCII-arvoina (0-127). Tama vastaa yksinkertaistettua
    PC-mallia. Vapautusbitti (bit 7) erottaa painalluksen vapautuksesta.
"""

from collections import deque

from ..constants import KBD_RELEASE_BIT, VRAM_CHAR_MASK


class KeyboardDevice:
    """
    Virtuaalinen nappaimistolaite.

    Kayttaa FIFO-jonoa nappaintapahtumille. Uudet tapahtumat menevat
    jonon loppuun. CPU lukee tapahtuman KBD_DATA MMIO -osoitteesta
    keskeytysrutiinissa (INT 6).

    Skannikoodi-rakenne:
        Bitti 7 = KBD_RELEASE_BIT: 0 = painallus, 1 = vapautus
        Bitit 6-0: nappainkoodi (ASCII, 0-127)

    Example:
        >>> kbd = KeyboardDevice()
        >>> kbd.push_key(ord('A'))         # 'A' painetaan
        >>> kbd.push_key_release(ord('A')) # 'A' vapautetaan
        >>> kbd.read_data()
        65   # 0x41 = 'A' painallus
        >>> kbd.read_data()
        193  # 0xC1 = 'A' vapautus (65 | 0x80)
        >>> kbd.read_data()
        0    # Jono tyhja
    """

    def __init__(self) -> None:
        """
        Alusta nappaimistolaite tyhjalla jonolla.
        """
        self._queue: deque[int] = deque()
        self._pending_interrupts: int = 0  # Odottavien keskeytysten laskuri

    def push_key(self, key_code: int) -> None:
        """
        Lisaa nappainpainallus jonoon ja aseta keskeytyslippu.

        Kutsutaan kun kayttaja painaa nappainta. Arvo tallennetaan
        7-bittisena (bit 7 = 0 = painallus).

        Args:
            key_code: Nappainkoodi (ASCII-arvo tms., 0-127)
        """
        code = key_code & (VRAM_CHAR_MASK >> 1)  # Maski 7 bittiin (0-127)
        self._queue.append(code)
        self._pending_interrupts += 1

    def push_key_release(self, key_code: int) -> None:
        """
        Lisaa nappainvapautus jonoon ja aseta keskeytyslippu.

        Kutsutaan kun kayttaja vapauttaa nappaimen. Vapautustapahtuma
        koodataan asettamalla bitti 7 (KBD_RELEASE_BIT = 0x80).

        Args:
            key_code: Nappainkoodi (sama kuin push_key():ssa kaytettiin)
        """
        code = (key_code & (VRAM_CHAR_MASK >> 1)) | KBD_RELEASE_BIT
        self._queue.append(code)
        self._pending_interrupts += 1

    def read_data(self) -> int:
        """
        Lue ja poista seuraava nappaintapahtuma jonosta (MMIO KBD_DATA -luku).

        Palauttaa vanhimman tapahtuman ja poistaa sen jonosta.
        Jos jono on tyhja, palauttaa 0.

        Skannikoodi-rakenne:
            Bitti 7 = 0: painallus
            Bitti 7 = 1: vapautus (KBD_RELEASE_BIT = 0x80)
            Bitit 6-0:   nappainkoodi

        Returns:
            Nappaintapahtuman koodi (0-255), tai 0 jos ei tapahtumia
        """
        if not self._queue:
            return 0
        return self._queue.popleft()

    def read_status(self) -> int:
        """
        Palauta jonossa olevien tapahtumien maara (MMIO KBD_STATUS -luku).

        Returns:
            Jonon pituus (0 = tyhja)
        """
        return len(self._queue)

    def take_interrupt(self) -> bool:
        """
        Tarkista ja vahenna odottavan keskeytyksen laskuria.

        Kutsutaan CPU:n step()-metodissa jokaisen kaskyn jalkeen.
        Jos laskuri on > 0, palautetaan True ja laskuria vahennetaan.
        Nain jokainen nappaintapahtuma laukaisee tarkalleen yhden INT 6.

        Returns:
            True jos keskeytys odottaa (ja laskuria vahennetaan), muuten False
        """
        if self._pending_interrupts > 0:
            self._pending_interrupts -= 1
            return True
        return False
