"""
Virtuaalinen nappaimistolaite kCPU16-emulaattorille.

Nappaimisto on jonopohjainen laite, joka puskuroi nappainpainalluksia.
CPU voi lukea puskurin KGET-kaskylla.

TOIMINTAPERIAATE:
------------------
1. Ulkoinen syote (esim. REPL tai GUI) kutsuu push_key(ascii)
2. Napaimen arvo (0-255) lisataan jonoon
3. Kun ohjelma suorittaa KGET-kaskyn, pop_key() palauttaa
   vanhimman painalluksen (FIFO-jarjestys)

KESKEYTYSPOHJAINEN KAYTTO:
--------------------------
Arkkitehtuuridokumentin mukaan nappainpainallus laukaisee
INT 6 (nappaimistokeskeytys). Tama ei ole viela toteutettu
taydellisesti - CPU ei aktiivisesti tarkista jonoa.

Normaali kaytto:
1. Nappaimistokeskeytys (INT 6) tulee
2. Keskeytysrutiini kutsuu KGET lukemaan nappaimennaan

Note:
    Arkkitehtuuridokumentti ei maarita tarkkoja MMIO-osoitteita
    nappaimistolle, joten kaytamme jonopohjaista ratkaisua.
"""

from collections import deque

from ..constants import VRAM_CHAR_MASK


class KeyboardDevice:
    """
    Virtuaalinen nappaimistolaite.

    Kayttaa FIFO-jonoa nappainpainalluksille. Uudet painallukset
    menevat jonon loppuun, ja KGET hake jonon alusta.

    Example:
        >>> kbd = KeyboardDevice()
        >>> kbd.push_key(ord('A'))  # Simuloi A-nappaimen painamista
        >>> kbd.push_key(ord('B'))  # Simuloi B-nappaimen painamista
        >>> kbd.pop_key()  # KGET lukee ensimmaisen
        65  # 'A'
        >>> kbd.pop_key()
        66  # 'B'
        >>> kbd.pop_key()  # Jono on tyhja
        0
    """

    def __init__(self) -> None:
        """
        Alusta nappaimistolaite tyhjalla jonolla.
        """
        # Kayta dequea tehokkaaseen FIFO-toimintaan
        self._queue: deque[int] = deque()

    def push_key(self, ascii_code: int) -> None:
        """
        Lisaa nappainpainallus jonoon.

        Kutsutaan kun kayttaja painaa nappaintä (simuloitu tai oikea).
        Arvo maskataan 8-bittiseksi (0-255).

        Args:
            ascii_code: Napaimen ASCII-koodi (esim. ord('A') = 65)
        """
        self._queue.append(ascii_code & VRAM_CHAR_MASK)

    def pop_key(self) -> int:
        """
        Hae seuraava nappain jonosta (KGET-kasky).

        Palauttaa vanhimman painalluksen ja poistaa sen jonosta.
        Jos jono on tyhja, palauttaa 0.

        Returns:
            Napaimen ASCII-koodi (0-255), tai 0 jos ei painalluksia
        """
        if not self._queue:
            return 0  # Ei painalluksia
        return self._queue.popleft()
