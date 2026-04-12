"""
kCPU16 virtuaalilaitteet.

Tama paketti sisaltaa kaikki emulaattorin virtuaalilaitteet:

- ScreenDevice: Tekstipohjainen naytto (80x24), lukee VRAM-muistia
- KeyboardDevice: Nappaimistopuskuri, generoi INT 6 -keskeytyksen
                  nappainpainalluksesta ja -vapautuksesta; luetaan
                  MMIO-osoitteista KBD_DATA ($0020) ja KBD_STATUS ($0021)
- BlockStorageDevice: Levylaite boot-latukseen ja tiedon tallennukseen

MUISTIKARTTAISET LAITTEET (MMIO):
---------------------------------
Video RAM (nayttomuisti) on muistikartattu osoitteisiin $F800-$FF7F.
Ohjelmat kirjoittavat suoraan naihin osoitteisiin nayton paivittamiseksi.

Nappaimisto on muistikartattu osoitteisiin $0020-$0021:
  KBD_DATA   ($0020) = lue seuraava nappaintapahtuma puskurista
  KBD_STATUS ($0021) = puskurissa olevien tapahtumien maara

IRRALLISENA OLEVAT LAITTEET:
-----------------------------
Tallennuslaite ei ole muistikarttattu, vaan sita kaytetaan
erityiskaskyilla (DREAD, DWRITE).
"""

from .keyboard import KeyboardDevice
from .screen import ScreenDevice
from .storage import BlockStorageDevice

# Julkinen rajapinta: nama luokat ovat saatavilla suoraan paketista
__all__ = ["KeyboardDevice", "ScreenDevice", "BlockStorageDevice"]
