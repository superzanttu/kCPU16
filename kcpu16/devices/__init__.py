"""
kCPU16 virtuaalilaitteet.

Tama paketti sisaltaa kaikki emulaattorin virtuaalilaitteet:

- ScreenDevice: Tekstipohjainen naytto (80x24), lukee VRAM-muistia
- KeyboardDevice: Nappaimistopuskuri, tarjoaa nappaimet KGET-kaskylle
- BlockStorageDevice: Levylaite boot-latukseen ja tiedon tallennukseen

MUISTIKARTTAISET LAITTEET (MMIO):
---------------------------------
Video RAM (nayttomuisti) on muistikartattu osoitteisiin $F800-$FF7F.
Ohjelmat kirjoittavat suoraan naihin osoitteisiin nayton paivittamiseksi.

IRRALLISENA OLEVAT LAITTEET:
-----------------------------
Nappaimisto ja tallennuslaite eivat ole muistikartattuja, vaan niita
kaytetaan erityiskaskyilla (KGET, DREAD, DWRITE).
"""

from .keyboard import KeyboardDevice
from .screen import ScreenDevice
from .storage import BlockStorageDevice

# Julkinen rajapinta: nama luokat ovat saatavilla suoraan paketista
__all__ = ["KeyboardDevice", "ScreenDevice", "BlockStorageDevice"]
