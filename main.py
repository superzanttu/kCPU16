"""
kCPU16 Emulaattori - Ohjelman aloituspiste.

Tama tiedosto toimii entry pointina komentorivilla ajettaessa:
    python main.py <komento>

Kaikki varsinainen logiikka on kcpu16.cli-moduulissa.

KAYTTOESIMERKKEJA:
------------------
    # Kaynnista TUI
    python main.py

    # Lataa .asm-tiedosto TUI:iin
    python main.py ohjelma.asm

    # Lataa .dsk-tiedosto storageen
    python main.py --dsk levykuva.dsk

    # Molemmat yhdessa
    python main.py ohjelma.asm --dsk levykuva.dsk

    # Tarkista .asm-tiedoston syntaksi
    python main.py --check ohjelma.asm
"""

from kcpu16.cli import main


# Suorita vain jos tama tiedosto ajetaan suoraan (ei importata)
if __name__ == "__main__":
    # Kutsu CLI:n main-funktiota ja valita paluuarvo
    # SystemExit mahdollistaa return coden valityksen shellille
    raise SystemExit(main())
