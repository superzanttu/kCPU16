# kCPU16-oppikirja, osa 1: Assembler perusteista 3D-laskentaan

Tämä on kCPU16-kirjasarjan **1. osa**.  
Tavoite: opit kirjoittamaan kCPU16-assembleria alkeista, ymmärrät käskytyypit, käyt läpi koko käskykannan ja päätät osuuden yksinkertaiseen 3D-laskentaan.

---

## 1) Mistä assemblerissa on kyse?

kCPU16 on 16-bittinen, sanakohtaisesti osoitettu arkkitehtuuri.  
Assembler-ohjelma kääntää mnemoniikat (kuten `ADD R0, R1`) konekieleksi.

Lyhyt perusrakenne:

```asm
.origin 0x0100

START:
    READ R0, 10
    READ R1, 32
    ADD R0, R1
    HALT
```

- `label:` = nimi osoitteelle
- `;` = kommentti
- rekisterit: `R0..R15`, `FP`, `SP`

---

## 2) Ensiaskeleet: numerot, rekisterit, osoitteet

### Numeromuodot
- desimaali: `42`
- heksa: `0x2A`
- binääri: `0b101010`
- oktaali: `0o52`

### Osoitusmuodot
- suora arvo: `READ R0, 123`
- absoluuttinen muistiosoite: `READ R0, [0x3000]`
- epäsuora rekisterin kautta: `READ R0, [R1]`
- FP-suhteinen: `READ R0, [FP+2]`

### Tärkeä käytäntö
kCPU16-assemblerissa käytetään **READ/STORE + hakasulkuosoitusta**.  
Esimerkiksi `READ_IND`/`STORE_REL` ovat opcode-tasolla olemassa, mutta käytännön lähdekoodissa kirjoitat muodot:
- `READ Rn, [..]`
- `STORE [..], lähde`

---

## 3) Direktiivit, joita käytät koko ajan

- `.origin` / `.org` — aloitusosoite
- `.at` — uusi segmentti
- `.dw` — 16-bittinen data
- `.db` — 8-bittinen data (tallentuu sanoina)
- `.dstr "teksti"` — null-terminoitu merkkijono
- `.const NIMI, ARVO` — oma vakio
- `.macro` / `.endmacro` — makrot
- `.include "file.asm"` — sisällytä toinen tiedosto

Testaukseen:
- `.expect_reg`, `.expect_flag`, `.expect_mem`, `.expect_storage`
- `.inject_key`, `.inject_key_release`

---

## 4) Käskytyypit (isoa kuvaa)

1. **Tiedonsiirto**: lue/kirjoita rekistereitä ja muistia  
2. **Aritmetiikka**: laskenta ja vertailu  
3. **Logiikka/bitit**: maskit, bitinsiirrot  
4. **Pino**: aliohjelmat, kehykset, kontekstinvaihto  
5. **Ohjaus**: hypyt, kutsut, ehtologiikka  
6. **Keskeytykset**: `INT`, `IRET`, keskeytysbitin hallinta  
7. **Järjestelmä/I/O**: ajastin, suojaus, levy, atominen lukko

---

## 5) Kaikki käskyt (koko ISA)

Alla on koko käskykanta ryhmittäin.

### 5.1 Tiedonsiirto

- `LOAD reg, imm` — lataa välitön arvo rekisteriin
- `CPY regD, regS` — kopioi rekisteristä toiseen
- `READ reg, addr` — lue absoluuttisesta muistiosoitteesta
- `STORE reg, addr` — kirjoita rekisteriarvo absoluuttiseen osoitteeseen
- `READ_IND regD, regPtr` — lue muistista osoitteesta `[regPtr]`
- `STORE_IND regPtr, regS` — kirjoita muistiosoitteeseen `[regPtr]`
- `READ_REL reg, offset` — lue osoitteesta `[FP+offset]`
- `STORE_REL reg, offset` — kirjoita osoitteeseen `[FP+offset]`
- `STOREI imm, addr` — kirjoita välitön arvo osoitteeseen
- `STOREI_IND regPtr, imm` — kirjoita välitön arvo osoitteeseen `[regPtr]`
- `STOREI_REL imm, offset` — kirjoita välitön arvo osoitteeseen `[FP+offset]`
- `FILL regStart, regEnd, regVal` — täytä muistialue
- `COPY regStart, regEnd, regDst` — kopioi muistialue

> Käytännön lähdekoodissa käytä mieluiten:
> - `READ Rn, [..]`
> - `STORE [..], src`  
> Assembler valitsee oikean opcode-muodon.

### 5.2 Aritmetiikka

- `ADD regD, regS`
- `SUB regD, regS`
- `MUL regD, regS`
- `DIV regD, regS` (nollalla jako -> keskeytys)
- `CMP regA, regB` (päivittää liput, ei talleta tulosta)
- `ADC regD, regS` (carry mukana)

### 5.3 Logiikka ja bitit

- `AND regD, regS`
- `OR regD, regS`
- `XOR regD, regS`
- `NOT reg`
- `SHL regD, regS`
- `SHR regD, regS`

### 5.4 Pino

- `PUSH reg`
- `POP reg`
- `SWSP regD, regS` (atominen SP-vaihto)

### 5.5 Ohjaus

- `JUMP addr`
- `CALL addr`
- `RET`
- `JZ addr`
- `JNZ addr`
- `JLT addr`
- `JGT addr`
- `JLE addr`
- `JGE addr`
- `JMPI regIndex, target0, target1, ...`
- `CALLI regIndex, target0, target1, ...`

### 5.6 Keskeytykset

- `INT imm`
- `IRET` (Kernel)
- `STI` (Kernel)
- `CLI` (Kernel)

### 5.7 Järjestelmä ja I/O

- `HALT` (Kernel)
- `DREAD regD, regAddr` (Kernel)
- `DWRITE regS, regAddr` (Kernel)
- `SMPR reg` (Kernel)
- `STMR reg` (Kernel)
- `SCTMR reg` (Kernel)
- `EXIT`
- `TSL reg, addr`
- `NOP`

---

## 6) Käytännön perusmallit

### Laskenta
```asm
READ R0, 6
READ R1, 7
MUL R0, R1
```

### Muistitaulukon käsittely
```asm
READ R2, [R1]      ; lue osoittimen kautta
STORE [R1], R0     ; kirjoita osoittimen kautta
```

### Aliohjelma
```asm
CALL FUNC
...
FUNC:
    ; tee työ
    RET
```

---

## 7) Yksinkertainen 3D-laskenta kCPU16:lla

Koska kCPU16 on 16-bittinen eikä sisällä liukulukuja, käytetään **kiintopiste-esitystä** (fixed-point).

### 7.1 Idea
1. Ota 3D-piste `(x,y,z)`  
2. Kierrä Y-akselin ympäri:
   - `x' = x*cos(a) + z*sin(a)`
   - `z' = -x*sin(a) + z*cos(a)`
3. Perspektiiviprojektio:
   - `screen_x = cx + (x' * f) / (z' + d)`
   - `screen_y = cy + (y  * f) / (z' + d)`

Missä:
- `f` = polttoväli
- `d` = kameran etäisyyssiirto (pitää jakajan positiivisena)
- `cx, cy` = ruudun keskipiste

### 7.2 Miniesimerkki (yksi piste, yksi kulma)

```asm
.origin 0x0100

.const SCALE, 256
.const COS_A, 181      ; ~cos(45°)*256
.const SIN_A, 181      ; ~sin(45°)*256
.const FOCAL, 64
.const CAM_D, 128
.const CX, 40
.const CY, 12

; piste (x,y,z) fixed-point skaalassa 256
.const PX, 256         ; 1.0
.const PY, 128         ; 0.5
.const PZ, 512         ; 2.0

START:
    ; x' = (x*cos + z*sin)/SCALE
    READ R0, PX
    READ R1, COS_A
    MUL R0, R1
    READ R2, PZ
    READ R3, SIN_A
    MUL R2, R3
    ADD R0, R2
    READ R4, SCALE
    DIV R0, R4          ; R0 = x'

    ; z' = (-x*sin + z*cos)/SCALE
    READ R1, PX
    READ R2, SIN_A
    MUL R1, R2
    READ R2, 0
    SUB R2, R1          ; R2 = -x*sin
    READ R3, PZ
    READ R5, COS_A
    MUL R3, R5
    ADD R2, R3
    DIV R2, R4          ; R2 = z'

    ; denom = z' + CAM_D
    READ R3, CAM_D
    ADD R3, R2

    ; screen_x = CX + (x' * FOCAL) / denom
    READ R5, FOCAL
    MUL R0, R5
    DIV R0, R3
    READ R6, CX
    ADD R0, R6          ; R0 = screen_x

    ; screen_y = CY + (y * FOCAL) / denom
    READ R1, PY
    MUL R1, R5
    DIV R1, R3
    READ R6, CY
    ADD R1, R6          ; R1 = screen_y

    ; tässä R0,R1 ovat 2D-koordinaatit
    ; seuraava askel olisi piirtää merkki VRAMiin
    HALT
```

Tämä on tarkoituksella yksinkertainen: yksi piste, kiinteä kulma, integer/fixed-point-laskenta.  
Se on kuitenkin täysi silta 2D:stä 3D-ajatteluun kCPU16-assemblerissa.

---

## 8) Mihin tästä jatketaan (osa 2+)

Seuraavissa osissa luonteva jatko on:
- VRAM-piirto kunnolla (pikseli-/merkkiabstraktio)
- usean pisteen muunnokset
- kulmataulukot ja animaatiosilmukka
- keskeytyspohjainen ajastus
- yksinkertainen wireframe-kappale

---

## Yhteenveto

Osassa 1 opit:
- assemblyn perussyntaksin
- direktiivit ja osoitusmuodot
- kaikki kCPU16-käskyt kategorioittain
- miten 3D-laskenta tehdään ilman liukulukuja fixed-pointilla

Tämä riittää jo omien pienten laskenta-, peli- ja grafiikkakokeilujen rakentamiseen kCPU16:lla.
