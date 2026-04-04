# kCPU16 Emulator Skeleton (Python)

Tama projekti on runko kCPU16-arkkitehtuurin emulointiin dokumentin `kCPU16-architecture.md` pohjalta.

## Sisalto

- CPU-suoritussilmukka: Fetch -> Privilege Check -> Memory Check -> Execute -> PC Update
- Perusmuisti ja kayttooikeustarkistus (MPR + VRAM-poikkeus)
- Keskeytysmekanismi (vektorit 0-7) rungon tasolla
- Assembler-runkoversio
- Disassembler-runkoversio
- Virtuaalinen tekstinaytto (80x24 dokumentin mukaan)
- Komentoriviliittyma (`run`, `disasm`, `repl`)

## Kaynnistys

1. Aja:

   python main.py repl

2. Tai suorita asm-lahdekoodi:

   python main.py run ohjelma.asm --cycles 10000

3. Dissanalyysi sanoista:

   python main.py disasm 0x0001 0x0000 0x002A

## Huomioita

- Tamanhetkinen opcode-koodaus on runkomallinen, ei viela lopullinen ISA-binaariformaatti.
- Kaikkia kaskyja ei ole toteutettu, mutta rakenne on valmis laajennukselle.
- Naimistolaitteen MMIO-osoitteet puuttuvat alkuperaisesta speksista, joten laite on jonopohjainen runko.
