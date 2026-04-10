"""
Emulaattorin poikkeusluokat.

Nama poikkeukset heitetaan kun CPU kohtaa virhetilanteen. CPU:n step()-metodi
nappaa nama poikkeukset ja muuntaa ne vastaaviksi keskeytyksiksi (INT).

Poikkeushierarkia:
    KCPU16Error (kantaluokka)
    |-- InvalidOpcodeError      -> INT 1
    |-- PrivilegeViolationError -> INT 4
    |-- MemoryAccessFaultError  -> INT 5
    |-- ReadOnlyMemoryError     -> INT 5
    |-- StackOverflowError      -> INT 2

Ei-virhepohjaiset keskeytykset (eivat kayta poikkeusluokkia):
    ZeroDivisionError (Python)  -> INT 0  (DIV-kaskyn jakaja = 0)
    INT 3 (Breakpoint)          -- ohjelmallinen, INT-kaskylla
    INT 6 (Keyboard)            -- laitteistokeskeytys
    INT 7 (Timer)               -- ajastinkeskeytys
    INT 8 (Process Exit)        -- EXIT-kasky
"""


class KCPU16Error(Exception):
    """
    Kaikkien emulaattoripoikkeusten kantaluokka.

    Perimalla tasta voidaan napata kaikki kCPU16-virheet
    yhdella except-lauseella.
    """


class InvalidOpcodeError(KCPU16Error):
    """
    Heitetaan kun dekooderi kohtaa tuntemattoman opcoden.

    Tama tapahtuu kun:
    - Muistissa on arvo, joka ei vastaa mitaan tunnettua kaskya
    - Yritettiin suorittaa dataa koodina

    Johtaa keskeytykseen INT 1 (Invalid Opcode).
    """


class PrivilegeViolationError(KCPU16Error):
    """
    Heitetaan kun User-tila yrittaa suorittaa etuoikeutetun kaskyn.

    Etuoikeutetut (Kernel-only) kaskyt:
    - IRET (paluu keskeytyksesta)
    - STI/CLI (keskeytykset paalle/pois)
    - HALT (pysayta kone)
    - DREAD/DWRITE (levyoperaatiot)
    - SMPR/STMR (jarjestelmarekisterien asetus)

    Johtaa keskeytykseen INT 4 (Privilege Violation).
    """


class MemoryAccessFaultError(KCPU16Error):
    """
    Heitetaan kun User-tila yrittaa kayttaa suojattua muistia.

    User-tilassa muistikaytto on rajoitettu:
    - Ei saa lukea/kirjoittaa osoitteisiin < MPR (Memory Protection Register)
    - POIKKEUS: VRAM ($F800-$FF7F) on aina sallittu nayton paivitysta varten

    Johtaa keskeytykseen INT 5 (Memory Access Fault).
    """


class StackOverflowError(KCPU16Error):
    """
    Heitetaan kun pinon osoitin (SP) menee sallitun rajan alle.

    User-tilassa pino ei saa kasvaa MPR:n alle, jotta kayttajan
    koodi ei voi ylikirjoittaa jarjestelman muistia.

    Johtaa keskeytykseen INT 2 (Stack Overflow).
    """


class ReadOnlyMemoryError(KCPU16Error):
    """
    Heitetaan kun yritetaan kirjoittaa kirjoitussuojattuun muistiosoitteeseen.

    Kirjoitussuojattuja alueita ovat:
    - Kello-MMIO ($0010-$001A, $001C-$001F): lue-vain reaaliaikakellorekisterit
    - Nappaimisto-MMIO ($0020-$0021): KBD_DATA ja KBD_STATUS ovat lue-vain
    - Tulevaisuudessa: ROM-alueet (lisataan Memory.read_only_regions-listalle)

    Kirjoittaminen KBD_DATA:han ($0020) tai KBD_STATUS:een ($0021) ei saa
    mitaan aikaan - ne ovat laitteen tilaa heijastavia "ikkunoita", ei
    rekistereja joihin kirjoitetaan. Kirjoitusyritys aiheuttaa taman virheen.

    Johtaa keskeytykseen INT 5 (Memory Access Fault).
    """
