"""
kCPU16 Emulaattoripaketti.

Tama on paketin juuritiedosto, joka maarittaa julkisen rajapinnan.
Kayttajat voivat importata paaluokan suoraan:

    from kcpu16 import KCPU16Machine

    machine = KCPU16Machine()
    machine.cold_reset()
    machine.load_program([0x0001, 0x0000, 0x002A, 0x0044])  # LOAD R0, 42; HALT
    machine.run()
    print(machine.dump_registers())

PAKETIN SISALTO:
----------------
- hardware/machine.py: KCPU16Machine - korkeantason wrapper
- hardware/cpu.py: CPU-ydin (Fetch-Decode-Execute)
- hardware/memory.py: Muistimalli
- hardware/registers.py: Rekisteritiedosto
- instruction.py: Kaskyjen metatiedot
- assembler.py: Assembly -> konekieli
- disassembler.py: Konekieli -> assembly
- cli.py: Komentoriviliittyma
- hardware/devices/: Virtuaalilaitteet (naytto, nappaimisto, levy)
- examples/: Esimerkkiohjelmat
"""

from .hardware.machine import KCPU16Machine

__version__ = "1.4.1"  # Semanttinen versio, kaytettavissa esim. pip-pakettina

# __all__ maarittaa mita "from kcpu16 import *" tuo
__all__ = ["KCPU16Machine", "__version__"]
