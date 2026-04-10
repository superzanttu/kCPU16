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
| Interpreter/varaus | `0x000–0x1FF` | Tulkin oma alue, fontit ja varatut tiedot |
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
- [ ] Miten 60 Hz ajastintikki sidotaan kCPU16:n ajastusmekanismiin?

## 8. Seuraavat askeleet

1. Lukitaan yllä olevat avoimet määrittelypäätökset.
2. Toteutetaan init/reset-rakenne muistille ja rekistereille.
3. Toteutetaan fetch/decode-runko (`PC`, opcode, nibble-kentät).
4. Lisätään vaiheittain käskyryhmät ja testit.
