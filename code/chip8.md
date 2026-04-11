# CHIP-8 alustava runko

## 1. Tavoite

Tämän dokumentin tarkoitus on määritellä CHIP-8-emulaattorin perusrakenne kCPU16-projektiin.
Ensimmäisessä vaiheessa keskitytään muistimalliin, muistialueisiin ja keskeisiin määrittelyihin.

## 2. Perusmäärittelyt

- **CHIP-8 muistin koko:** 4096 tavua (`0x000`–`0xFFF`)
- **Opcode-koko:** 2 tavua
- **Ohjelman aloitusosoite:** `0x200`
- **Fonttidatan oletusalue:** `0x050`–`0x09F`
- **Näyttöresoluutio:** 64 × 32 (1 bpp)
- **Pino:** enintään 16 palautusosoitetta

## 3. Muistimalli kCPU16:ssa

Suositus: **1 CHIP-8 tavu = 1 kCPU16 sana**.

Perustelut:
- osoitelaskenta pysyy yksinkertaisena
- debuggauksessa sisältö on helposti luettavissa
- bittipakkausta ei tarvita
- kCPU16-muisti riittää hyvin 4 KB CHIP-8-mallille

## 4. CHIP-8 muistialueet

| Alue | Osoitteet | Käyttö |
| --- | --- | --- |
| Interpreter/varaus | `0x000–0x1FF` | Tulkin varattu alue; fonttidata oletuksena `0x050–0x09F` |
| ROM-ohjelma | `0x200–0xFFF` | Ladattu CHIP-8-ohjelma |

## 5. Emulaattorin tilamuuttujat (määrittelyrunko)

### 5.1 Rekisterit
- `V0..VF` (16 × 8-bit)
- `I` (12/16-bit osoitin)
- `PC` (program counter)
- `SP` (stack pointer)

### 5.2 Ajastimet
- `DT` (delay timer)
- `ST` (sound timer)

### 5.3 Pino
- `stack[16]` palautusosoitteille

### 5.4 Näppäimistötila
- 16 näppäimen tila (bitmaski tai taulukko)

### 5.5 Framebuffer
- 64×32 yksibittinen kuvapuskuri

## 6. Muistiin liittyvät toiminnalliset säännöt

- ROM ladataan aina osoitteesta `0x200` alkaen.
- `PC` alustetaan arvoon `0x200` resetissä.
- Käskyhaku lukee aina kaksi peräkkäistä tavua (`hi`, `lo`).
- Muistikäskyissä (`FX55`, `FX65`, `FX33`) määritellään selkeästi I-rekisterin päivityssääntö.
- Kaikki kirjoitukset rajataan CHIP-8 muistin sisälle (`0x000–0xFFF`).

## 7. Avoimet määrittelypäätökset

- [ ] Päivitetäänkö `I` käskyjen `FX55/FX65` jälkeen (legacy vs modern)?
- [ ] Käytetäänkö piirrossa wrapping- vai clipping-käytöstä ruudun reunoilla?
- [ ] Miten `8XY6` ja `8XYE` shift-opcodejen yhteensopivuuslinjaus valitaan?
- [ ] Miten 60 Hz ajastintahdistus sidotaan kCPU16:n ajastusmekanismiin?

## 8. Seuraavat askeleet

1. Lukitaan yllä olevat avoimet määrittelypäätökset.
2. Toteutetaan init/reset-rakenne muistille ja rekistereille.
3. Toteutetaan fetch/decode-runko (`PC`, opcode, nibble-kentät).
4. Lisätään vaiheittain käskyryhmät ja testit.

## 9. Ohjelman rakennehahmotelma

Suositus: emulaattori jaetaan pieniin, selkeärajaisiin osiin.

### 9.1 Moduulit ja vastuut

- **chip8_state.py**
  - Pitää emulaattorin kaiken ajonaikaisen tilan:
    - rekisterit `V0..VF`, `I`, `PC`, `SP`
    - ajastimet `DT`, `ST`
    - `memory[4096]`, `stack[16]`, `keys[16]`, `framebuffer[64*32]`
- **chip8_loader.py**
  - Vastaa ROM-latauksesta muistialueelle `0x200..`.
  - Tarkistaa, ettei ROM ylitä muistia.
- **chip8_cpu.py**
  - `fetch()` lukee opcode:n kahdesta tavusta
  - `decode_execute(opcode)` ohjaa opcode-ryhmittäin oikeaan toteutukseen
  - sisäiset toteutukset esimerkiksi:
    - ohjauskäskyt (`1NNN`, `2NNN`, `00EE`)
    - rekisteri-/ALU-käskyt (`6XNN`, `7XNN`, `8XY*`)
    - muistikäskyt (`ANNN`, `FX55`, `FX65`, `FX33`)
    - piirto ja syöte (`DXYN`, `EX9E`, `EXA1`, `FX0A`)
- **chip8_timers.py**
  - Päivittää `DT` ja `ST` taajuudella 60 Hz.
- **chip8_platform.py** (adapteri)
  - Kytkee CHIP-8:n kCPU16-projektin olemassa oleviin laitteisiin:
    - näppäimistösyötteet
    - näytön piirto (framebuffer → näkyvä ulostulo)
    - ääni (kun `ST > 0`)
- **chip8_emulator.py**
  - Korkean tason ohjaus:
    - `reset()`
    - `load_rom(path)`
    - `step()` (yksi opcode)
    - `run_frame()` (N opcodea + ajastinpäivitys)

### 9.2 Pääsilmukan runko

1. Käsittele syöte (`keys`-tila).
2. Aja haluttu määrä CHIP-8-opcodeja.
3. Päivitä 60 Hz ajastimet.
4. Piirrä framebuffer ulostuloon.
5. Toista kunnes ohjelma lopetetaan.

## 10. Toteutushahmotelma vaiheittain

### Vaihe 1: Perusta
- Tee `State`-rakenne ja reset-logiikka.
- Lisää fonttidatan lataus varatulle alueelle (`0x050..0x09F`).
- Lisää ROM-loader osoitteesta `0x200`.

### Vaihe 2: CPU-runko
- Toteuta fetch/decode/execute-rakenne.
- Lisää opcode-apukentät (`nnn`, `nn`, `n`, `x`, `y`).
- Lisää tuntemattoman opcode:n virheenkäsittely.

### Vaihe 3: Minimikäskyt (ohjelmat käyntiin)
- `00E0`, `00EE`
- `1NNN`, `2NNN`, `3XNN`, `4XNN`
- `6XNN`, `7XNN`
- `ANNN`, `DXYN`

### Vaihe 4: Täysi käskyjoukko
- Lisää loput 8XY*, EX**, FX**-käskyt.
- Lukitse yhteensopivuuslinjaukset (legacy/modern) avoimista kohdista.

### Vaihe 5: Ajastus, syöte, renderöinti
- Toteuta `DT/ST` 60 Hz.
- Toteuta `FX0A` odottava näppäinluku.
- Toteuta ruudun päivitysrajapinta kCPU16-ympäristöön.

### Vaihe 6: Testaus ja validointi
- Lisää opcode-yksikkötestit (normal + edge case).
- Lisää ROM-tason testit tunnetuilla CHIP-8 testiohjelmilla.
- Varmista resetin, pinon, rajojen ja collision-lipun (`VF`) oikea toiminta.
