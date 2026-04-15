# kCPU16-oppikirja, osa 2: Laitteisto

Tämä on kCPU16-oppikirjasarjan toinen osa. Tässä osassa tutustut kCPU16-laitteeseen alkeista alkaen ja käyt läpi kaikki keskeiset laitteisto-ominaisuudet.

---

## 1. Mikä kCPU16 on?

kCPU16 on 16-bittinen, sana-osoitettu von Neumann -arkkitehtuuri. Sama muisti sisältää sekä ohjelmakoodin että datan.

**Perusfaktat:**
- Sanan koko: 16 bittiä
- Muistiavaruus: 65 536 sanaa (`0x0000–0xFFFF`)
- Käskyn koko: 1–3 sanaa
- Suojaustilat: **Kernel** ja **User**

---

## 2. Rekisterit: prosessorin työpöytä

### 2.1 Yleiskäyttöiset rekisterit

kCPU16:ssa on 16 yleiskäyttörekisteriä: **R0–R15**.

Näillä pidetään arvoja, laskennan välituloksia, osoitteita ja parametreja.

### 2.2 Erikoisrekisterit

- **FP** (Frame Pointer): pinokehyksen ankkuri aliohjelmille
- **SP** (Stack Pointer): pinon huippu (pino kasvaa alaspäin)
- **PC** (Program Counter): seuraavan käskyn osoite
- **SR** (Status Register): lippubittejä ja suoritustila

### 2.3 Järjestelmärekisterit

Vain kernel-tilassa asetettavia:
- **MPR**: User-tilan muistiraja (Memory Protection Register)
- **TMR**: ajastinkeskeytyksen väli (µs)
- **CTMR**: kellokeskeytyksen väli (ms)

### 2.4 SR-liput (Status Register)

Käytössä bitit 0–5:
- **Z**: tulos nolla
- **N**: tulos negatiivinen (bit 15 = 1)
- **C**: carry/borrow
- **V**: signed overflow
- **I**: laitteistokeskeytykset sallittu
- **P**: suojaustila (1=Kernel, 0=User)

---

## 3. Suojaustilat ja turvallisuusmalli

### Kernel Mode (P=1)
- Täydet oikeudet muistiin ja käskyihin
- Käytössä käynnistyksessä ja keskeytysrutiineissa

### User Mode (P=0)
- Muistipääsy: user-tila saa käyttää osoitteita `>= MPR`, ja osoitteet `< MPR` ovat kernel-suojattuja (MPR on suora 16-bittinen alarajaosoite)
- Etuoikeutetut käskyt aiheuttavat **INT 4**
- Kielletty muistipääsy aiheuttaa **INT 5**
- Poikkeus: **VRAM-alue** on aina käytettävissä myös user-tilassa

---

## 4. Muistikartta

| Alue | Tarkoitus |
|---|---|
| `0x0000–0x000F` | Keskeytysvektorit |
| `0x0010–0x001F` | Kellon MMIO + uptime + CTMR-väli |
| `0x0020–0x0021` | Näppäimistö MMIO |
| `0x0022` | Satunnaisluku MMIO |
| `0x0023–0x00FF` | OS-varattu alue |
| `0x0100–0x01FF` | Bootloader RAM-alue |
| `0x0200–0xF7FF` | Yleinen RAM |
| `0xF800–0xFF7F` | Video RAM (80×24 = 1920 sanaa) |
| `0xFF80–0xFFFF` | Kernel-pino |

---

## 5. MMIO-laitteet

### 5.1 Kello ja uptime (`0x0010–0x001F`)

Lukuosoitteet sisältävät ajan osia:
- `CLOCK_YEAR` ... `CLOCK_MILLIS` (`0x0010–0x0016`)
- `UPTIME_W3..W0` (`0x0017–0x001A`) = 64-bittinen sekuntilaskuri
- `CLOCK_INT_INTERVAL` (`0x001B`) = CTMR-väli (luku/kirjoitus)

### 5.2 Näppäimistö (`0x0020–0x0021`)

- `KBD_DATA` (`0x0020`): palauttaa seuraavan tapahtuman FIFO-jonosta
- `KBD_STATUS` (`0x0021`): jonon tapahtumamäärä

Näppäintapahtuma:
- Bitit 0–6: näppäinkoodi
- Bitti 7: 0 = painallus, 1 = vapautus

Jokainen painallus/vapautus voi laukaista **INT 6** (jos I=1).

### 5.3 Satunnaisluku (`0x0022`)

- `RAND_MMIO`:
  - luku: seuraava 16-bittinen pseudosatunnaisluku
  - kirjoitus: aseta siemen
- Toteutus: 16-bittinen Galois LFSR (maski `0xB400`); nollasiemen vältetään, koska nollatila ei kuulu jaksoon (käytännössä 0 korvataan arvolla 1)

### 5.4 Video RAM (`0xF800–0xFF7F`)

80 saraketta × 24 riviä, yksi sana per merkki:
- bitit 0–7: ASCII-merkki
- bitit 8–10: etuväri (FG)
- bitit 11–13: taustaväri (BG)
- bitti 14: bold
- bitti 15: varattu

VRAM on kirjoitettavissa myös user-tilassa.

---

## 6. Keskeytykset

### 6.1 Vektoritaulukko

Vektorit `0–15` löytyvät muistista `0x0000–0x000F`.

Käytetyt:
- **0**: Division by zero
- **1**: Invalid opcode
- **2**: Stack overflow
- **3**: Breakpoint/debug
- **4**: Privilege violation
- **5**: Memory access fault
- **6**: Keyboard
- **7**: Timer (TMR)
- **8**: Process exit
- **9**: Clock (CTMR)
- **10–15**: Varattu tulevaa käyttöä varten

### 6.2 Keskeytyksen käsittelyn perusprotokolla

Keskeytyksessä CPU tekee atomisesti:
1. PUSH PC
2. PUSH SR
3. P = 1 (kernel)
4. I = 0 (keskeytykset pois)
5. PC = vektorin osoite

Paluu tapahtuu `IRET`:llä:
1. POP SR
2. POP PC

---

## 7. Suoritussykli (CPU:n työrytmi)

Yksi `step()` sisältää:
1. Käskyn nouto (FETCH)
2. Käskyoikeuksien tarkistus (PRIVILEGE)
3. Muistioikeuksien tarkistus (MEMORY)
4. Käskyn suoritus (EXECUTE)
5. PC-päivitys
6. TMR-tarkistus
7. Uptime-päivitys
8. CTMR-tarkistus

Jos suojaustarkistus epäonnistuu, vastaava keskeytys laukeaa.

---

## 8. Käskykanta kokonaisuutena

kCPU16:n ISA sisältää käytännössä seuraavat luokat:

### 8.1 Tiedonsiirto
`LOAD, CPY, READ, STORE, READ_IND, STORE_IND, READ_REL, STORE_REL, STOREI, STOREI_IND, STOREI_REL, FILL`

### 8.2 Aritmetiikka
`ADD, SUB, MUL, DIV, CMP, ADC`

### 8.3 Logiikka ja bitit
`AND, OR, XOR, NOT, SHL, SHR`

### 8.4 Pino
`PUSH, POP, SWSP`

### 8.5 Ohjaus
`JUMP, CALL, RET, JZ/JE, JNZ/JNE, JLT, JGT, JLE, JGE, JMPI, CALLI`

### 8.6 Keskeytykset ja järjestelmä
`INT, IRET, STI, CLI, HALT, EXIT`

### 8.7 Järjestelmä/I-O
`DREAD, DWRITE, SMPR, STMR, SCTMR, TSL, NOP`

Huomioita:
- `DREAD/DWRITE`, `SMPR/STMR/SCTMR`, `IRET/STI/CLI/HALT` ovat kernel-painotteisia.
- Näppäimistöä ei lueta erillisellä käskyllä, vaan MMIO-muistin kautta (`READ` + `KBD_DATA`).

---

## 9. Oheislaitteet yksityiskohtaisesti

### 9.1 Näppäimistölaite
- FIFO-tapahtumajono
- painallus + vapautus tapahtumina
- keskeytys INT 6

### 9.2 Tallennuslaite
- kapasiteetti: 65 536 sanaa
- lohkopohjainen malli (256 blokkia × 256 sanaa)
- käyttö vain kernelissä (`DREAD`, `DWRITE`)
- tukee bootloaderin latausta sektorilta 0

### 9.3 Satunnaislukugeneraattori
- MMIO-rajapinta
- deterministinen LFSR
- hyvä kevyeen peli- ja simulaatiokäyttöön

---

## 10. Käynnistys (boot) askel askeleelta

Kylmäkäynnistys:
1. CPU aloittaa kernel-tilassa (P=1, I=0)
2. Yleisrekisterit nollataan
3. SP asetetaan arvoon `0xFFFF`
4. PC asetetaan arvoon `0x0100`
5. Tallennuslaitteen `0x0000–0x00FF` luetaan
6. Data kopioidaan RAMiin `0x0100–0x01FF` ja suoritus jatkuu osoitteesta `0x0100`

Tämä tekee sektorista 0 boot-sektorin.

---

## 11. Aika, syklit ja suoritusmalli

kCPU16 käyttää **simuloitua aikaa**:
- jokainen käsky kuluttaa määritellyn syklimäärän
- TMR/CTMR perustuvat tähän kertymään
- uptime johdetaan simuloiduista mikrosekunneista

Tyypillisiä syklejä:
- perusoperaatiot usein 1
- `MUL` 4
- `DIV` 8
- `DREAD/DWRITE` 10
- `INT/IRET/EXIT` 4
- `FILL` 1 + N sykliä, missä N on täyttöalueen kirjoitettujen sanojen määrä (myös wrap-tilassa: `rS..0xFFFF` ja `0x0000..rE`)

---

## 12. Mitä “kaikki ominaisuudet” käytännössä tarkoittaa kCPU16:ssa?

Tässä osassa käytiin läpi koko laitepinta:
- arkkitehtuurimalli (16-bit, von Neumann)
- rekisterit ja liput
- suojaustilat (kernel/user)
- muistikartta
- MMIO (kello, uptime, näppäimistö, RNG, VRAM)
- keskeytysmekanismi ja vektorointi
- suoritussykli
- koko käskykannan luokat
- tallennuslaite ja boot
- simuloitu aika ja suoritussyklit

Näiden avulla ymmärrät, miten kCPU16-laitteisto toimii sisältäpäin.

---

## 13. Jatko tähän sarjaan

Seuraavassa osassa on luontevaa siirtyä ohjelmointimalliin:
- aliohjelmat, pino ja calling convention
- keskeytysrutiinit käytännössä
- MMIO-ajurit (näppäimistö/näyttö)
- yksinkertainen “mini-OS” kCPU16:lle
