"""
Kaskyjen metatiedot ja opcode-taulukko.

Tama tiedosto maarittaa kCPU16-prosessorin kaskykirjaston (Instruction Set).
Se sisaltaa:
1. DecodedInstruction - puretun kaskyn tietorakenne
2. Opcode-bittikenttatavakiot ja _op()-koodausapufunktio
3. OPCODE_TABLE - opcode-arvojen ja kaskymetatietojen kuvaus

OPCODE-BITTIKENTTAT (16 bittiä):
---------------------------------
 Bitti 15    14:12    11:8    7:6    5:0
        P     GRP      ID     OPS    ---

  P   (Bit 15):    Oikeusbitti
                    0 = User-moodi (kaikki ohjelmat)
                    1 = Kernel-moodi vaaditaan (etuoikeutettu kasky)

  GRP (Bit 14:12): Kaskyryhmä (3 bittiä, arvot 1-7)
                    0 = Varatttu — kaikki opcoodet 0x0000-0x0FFF ovat
                        virheellisia (nollamuisti ei ajaudu vahingossa)
                    1 = Tiedonsiirto    (Data Transfer)
                    2 = Aritmetiikka    (Arithmetic)
                    3 = Logiikka        (Logic & Bitwise)
                    4 = Pino            (Stack)
                    5 = Ohjausrakenne   (Control Flow)
                    6 = Keskeytykset    (Interrupts)
                    7 = Jarjestelma/IO  (System)

  ID  (Bit 11:8):  Kaskyindeksi ryhmassa (4 bittiä, arvot 0-15)

  OPS (Bit 7:6):   Operandien maara (2 bittiä)
                    00 = 0 operandia  (esim. HALT, RET, NOP)
                    01 = 1 operandi   (esim. PUSH reg, JUMP addr)
                    10 = 2 operandia  (esim. LOAD reg, imm)

  --- (Bit 5:0):   Varattu, pitaa olla 0

KOODAUSKAAVA:
  opcode = (P << 15) | (GRP << 12) | (ID << 8) | (OPS << 6)

ESIMERKKI: LOAD R0, 42  ->  P=0, GRP=1, ID=0, OPS=2
  0b 0_001_0000_10_000000 = 0x1080

OPCOODEALUEET RYHMITTAIN:
  0x0000-0x0FFF  Virheellinen (GRP=0, nollamuisti)
  0x1000-0x1FFF  Tiedonsiirto    GRP=1  P=0
  0x2000-0x2FFF  Aritmetiikka    GRP=2  P=0
  0x3000-0x3FFF  Logiikka        GRP=3  P=0
  0x4000-0x4FFF  Pino            GRP=4  P=0
  0x5000-0x5FFF  Ohjausrakenne   GRP=5  P=0
  0x6000-0x6FFF  Keskeytykset    GRP=6  P=0  (User)
  0x7000-0x7FFF  Jarjestelma     GRP=7  P=0  (User)
  0xE000-0xEFFF  Keskeytykset    GRP=6  P=1  (Kernel)
  0xF000-0xFFFF  Jarjestelma     GRP=7  P=1  (Kernel)
"""

from dataclasses import dataclass, field


@dataclass
class DecodedInstruction:
    """
    Purettu kasky (dekoodatun kaskyn tietorakenne).

    Kun CPU lukee muistista opcoden, se dekoodaa sen tahan rakenteeseen
    ennen suorittamista. Tama erottaa fetch/decode-vaiheen execute-vaiheesta.

    Attributes:
        mnemonic: Kaskyn nimi tekstina (esim. "LOAD", "ADD", "JUMP")
        operands: Lista operandiarvoista (rekisteri-indeksit, osoitteet, vakiot)
        size_words: Kaskyn kokonaiskoko sanoina (1-3)
        privileged: True jos kasky vaatii Kernel-tilan

    Example:
        LOAD R0, 42 dekoodautuu:
        DecodedInstruction(
            mnemonic="LOAD",
            operands=[0, 42],      # R0 = indeksi 0, arvo 42
            size_words=3,          # opcode + 2 operandia
            privileged=False       # sallittu User-tilassa
        )
    """

    mnemonic: str  # Kaskyn nimi (esim. "LOAD")
    operands: list[int] = field(default_factory=list)  # Operandit listana
    size_words: int = 1  # Kokonaiskoko sanoina
    privileged: bool = False  # Vaatiiko Kernel-tilan?


# =============================================================================
# =============================================================================
# OPCODE-BITTIKENTTATAVAKIOT
# =============================================================================

# Bittipositiot (shift-arvot)
OPCODE_PRIV_SHIFT: int = 15  # Bit 15: Oikeusbitti
OPCODE_GRP_SHIFT: int = 12  # Bit 14:12: Ryhmakoodi
OPCODE_ID_SHIFT: int = 8  # Bit 11:8:  Kaskyindeksi ryhmassa
OPCODE_NOPS_SHIFT: int = 6  # Bit 7:6:   Operandien maara

# Bittipeitteet (mask-arvot)
OPCODE_GRP_MASK: int = 0x7  # 3 bittiä, GRP 0-7
OPCODE_ID_MASK: int = 0xF  # 4 bittiä, ID 0-15
OPCODE_NOPS_MASK: int = 0x3  # 2 bittiä, OPS 0-3

# Ryhmakoodit (GRP-kentan arvot, bitit 14:12)
OPCODE_GRP_TRANSFER: int = 1  # Tiedonsiirtokaskyt
OPCODE_GRP_ARITH: int = 2  # Aritmeettiset kaskyt
OPCODE_GRP_LOGIC: int = 3  # Logiikka- ja bittikaskyt
OPCODE_GRP_STACK: int = 4  # Pinokaskyt
OPCODE_GRP_FLOW: int = 5  # Ohjausrakennekaskyt
OPCODE_GRP_INTERRUPT: int = 6  # Keskeytykset
OPCODE_GRP_SYSTEM: int = 7  # Jarjestelma- ja IO-kaskyt


def _op(p: int, grp: int, id_: int, nops: int) -> int:
    """Laske opcode-arvo bittikentista.

    Koodauskaava: (P << 15) | (GRP << 12) | (ID << 8) | (OPS << 6)

    Args:
        p:    Oikeusbitti: 0=User, 1=Kernel
        grp:  Ryhmakoodi: 1-7
        id_:  Kaskyindeksi ryhmassa: 0-15
        nops: Operandien maara: 0-2

    Returns:
        16-bittinen opcode-arvo
    """
    return (
        (p << OPCODE_PRIV_SHIFT)
        | (grp << OPCODE_GRP_SHIFT)
        | (id_ << OPCODE_ID_SHIFT)
        | (nops << OPCODE_NOPS_SHIFT)
    )


# 1-sanaisen STATE-kaskyn opcode-perhe.
#
# STATE-opcode on muotoa _op(0, 7, 14, 0), jolloin:
#   - bitit 15..6 ovat kiinteät (priv/grp/id/nops)
#   - nops-kentta (bitit 7..6) pidetään arvossa 00
#   - id-kentäksi voidaan käyttää turvallisesti alimmat 6 bittiä (5..0)
#
# Tama mahdollistaa 64 tilaa (0..63) yhden 16-bittisen sanan kaskyna.
STATE_OPCODE_BASE: int = _op(0, 7, 14, 0)
STATE_ID_MASK: int = 0x003F
STATE_ID_MAX: int = STATE_ID_MASK
STATE_ID_COUNT: int = STATE_ID_MAX + 1


# =============================================================================
# OPCODE-TAULUKKO
# =============================================================================
# Kuvaa jokaisen tuetun kaskyn: opcode -> (mnemonic, operandien_maara, privileged)
#
# Opcode-arvot on laskettu _op()-funktiolla strukturoidusta bittikentasta.
# Jokaisesta opcode-arvosta voidaan suoraan lukea:
#   - Oikeusbitti:    (opcode >> OPCODE_PRIV_SHIFT) & 1
#   - Ryhma:          (opcode >> OPCODE_GRP_SHIFT)  & OPCODE_GRP_MASK
#   - Kaskyindeksi:   (opcode >> OPCODE_ID_SHIFT)   & OPCODE_ID_MASK
#   - Operandien lkm: (opcode >> OPCODE_NOPS_SHIFT) & OPCODE_NOPS_MASK
# =============================================================================

OPCODE_TABLE: dict[int, tuple[str, int, bool]] = {
    # -------------------------------------------------------------------------
    # GRP 1: TIEDONSIIRTOKASKYT (Data Transfer)
    #   Opcoodet: 0x1080-0x1780  (P=0, GRP=1, OPS=2)
    # -------------------------------------------------------------------------
    _op(0, 1, 0, 2): ("LOAD", 2, False),  # LOAD reg, imm       Lataa vakio rekisteriin
    _op(0, 1, 1, 2): (
        "CPY",
        2,
        False,
    ),  # CPY  regD, regS     Kopioi rekisterista toiseen
    _op(0, 1, 2, 2): (
        "READ",
        2,
        False,
    ),  # READ reg, addr      Lue muistiosoite rekisteriin
    _op(0, 1, 3, 2): (
        "STORE",
        2,
        False,
    ),  # STORE reg, addr     Tallenna rekisteri muistiin
    _op(0, 1, 4, 2): ("READ_IND", 2, False),  # READ_IND  regD, regS  Lue [regS] -> regD
    _op(0, 1, 5, 2): (
        "STORE_IND",
        2,
        False,
    ),  # STORE_IND regD, regS  Kirjoita [regD] <- regS
    _op(0, 1, 6, 2): (
        "READ_REL",
        2,
        False,
    ),  # READ_REL  reg, imm  Lue [FP + imm] rekisteriin
    _op(0, 1, 7, 2): (
        "STORE_REL",
        2,
        False,
    ),  # STORE_REL reg, imm  Kirjoita rekisteri [FP + imm]
    _op(0, 1, 8, 2): (
        "STOREI",
        2,
        False,
    ),  # STOREI imm, addr    Kirjoita välitön arvo muistiosoitteeseen
    _op(0, 1, 9, 2): (
        "STOREI_IND",
        2,
        False,
    ),  # STOREI_IND regD, imm  Kirjoita välitön arvo [regD]:hen
    _op(0, 1, 10, 2): (
        "STOREI_REL",
        2,
        False,
    ),  # STOREI_REL imm, offset  Kirjoita välitön arvo [FP + offset]
    _op(0, 1, 11, 3): (
        "FILL",
        3,
        False,
    ),  # FILL regStart, regEnd, regVal  Täytä muistialue [regStart..regEnd] arvolla regVal
    _op(0, 1, 12, 3): (
        "COPY",
        3,
        False,
    ),  # COPY regStart, regEnd, regDst  Kopioi muistialue [regStart..regEnd] osoitteeseen regDst
    # -------------------------------------------------------------------------
    # GRP 2: ARITMEETTISET KASKYT (Arithmetic)
    #   Opcoodet: 0x2080-0x2580  (P=0, GRP=2, OPS=2)
    # -------------------------------------------------------------------------
    _op(0, 2, 0, 2): ("ADD", 2, False),  # ADD regD, regS   regD = regD + regS
    _op(0, 2, 1, 2): ("SUB", 2, False),  # SUB regD, regS   regD = regD - regS
    _op(0, 2, 2, 2): ("MUL", 2, False),  # MUL regD, regS   regD = regD * regS
    _op(0, 2, 3, 2): (
        "DIV",
        2,
        False,
    ),  # DIV regD, regS   regD = regD / regS  (INT 0 jos jakaja=0)
    _op(0, 2, 4, 2): ("CMP", 2, False),  # CMP regA, regB   Vertaa, asettaa liput
    _op(0, 2, 5, 2): ("ADC", 2, False),  # ADC regD, regS   regD = regD + regS + C
    # -------------------------------------------------------------------------
    # GRP 3: LOGIIKKA JA BITTIKASKYT (Logic & Bitwise)
    #   Opcoodet: 0x3080-0x3580  (P=0, GRP=3)  NOT: OPS=1, muut: OPS=2
    # -------------------------------------------------------------------------
    _op(0, 3, 0, 2): ("AND", 2, False),  # AND regD, regS   regD = regD & regS
    _op(0, 3, 1, 2): ("OR", 2, False),  # OR  regD, regS   regD = regD | regS
    _op(0, 3, 2, 2): ("XOR", 2, False),  # XOR regD, regS   regD = regD ^ regS
    _op(0, 3, 3, 1): ("NOT", 1, False),  # NOT reg          reg = ~reg
    _op(0, 3, 4, 2): ("SHL", 2, False),  # SHL regD, regS   regD = regD << regS
    _op(0, 3, 5, 2): ("SHR", 2, False),  # SHR regD, regS   regD = regD >> regS
    # -------------------------------------------------------------------------
    # GRP 4: PINOKASKYT (Stack)
    #   Opcoodet: 0x4040-0x4280  (P=0, GRP=4)  PUSH/POP: OPS=1, SWSP: OPS=2
    # -------------------------------------------------------------------------
    _op(0, 4, 0, 1): ("PUSH", 1, False),  # PUSH reg          Tallenna pinoon
    _op(0, 4, 1, 1): ("POP", 1, False),  # POP  reg          Hae pinosta
    _op(0, 4, 2, 2): ("SWSP", 2, False),  # SWSP regD, regS   regD = SP; SP = regS
    # -------------------------------------------------------------------------
    # GRP 5: OHJAUSRAKENNEKASKYT (Control Flow)
    #   Opcoodet: 0x5040-0x5840  (P=0, GRP=5)  RET: OPS=0, muut: OPS=1
    # -------------------------------------------------------------------------
    _op(0, 5, 0, 1): ("JUMP", 1, False),  # JUMP addr   Ehdoton hyppy
    _op(0, 5, 1, 1): (
        "CALL",
        1,
        False,
    ),  # CALL addr   Aliohjelmakutsu (PUSH PC, JUMP addr)
    _op(0, 5, 2, 0): ("RET", 0, False),  # RET         Paluu aliohjelmasta (POP PC)
    _op(0, 5, 3, 1): ("JZ", 1, False),  # JZ   addr   Hyppa jos Z=1
    _op(0, 5, 4, 1): ("JNZ", 1, False),  # JNZ  addr   Hyppa jos Z=0
    _op(0, 5, 5, 1): ("JLT", 1, False),  # JLT  addr   Hyppa jos N!=V
    _op(0, 5, 6, 1): ("JGT", 1, False),  # JGT  addr   Hyppa jos Z=0 ja N=V
    _op(0, 5, 7, 1): ("JLE", 1, False),  # JLE  addr   Hyppa jos Z=1 tai N!=V
    _op(0, 5, 8, 1): ("JGE", 1, False),  # JGE  addr   Hyppa jos N=V
    _op(0, 5, 9, 0): ("JMPI", 0, False),  # JMPI reg, addr...  Indeksoitu epäsuora hyppy
    _op(0, 5, 10, 0): (
        "CALLI",
        0,
        False,
    ),  # CALLI reg, addr... Indeksoitu epäsuora kutsu
    # -------------------------------------------------------------------------
    # GRP 6: KESKEYTYKSET (Interrupts)
    #   User-kaskyt:   INT  0x6040  (P=0, GRP=6)
    #   Kernel-kaskyt: IRET/STI/CLI 0xE100-0xE300  (P=1, GRP=6)
    # -------------------------------------------------------------------------
    _op(0, 6, 0, 1): ("INT", 1, False),  # INT  imm    Ohjelmallinen keskeytys  [USER]
    _op(1, 6, 1, 0): ("IRET", 0, True),  # IRET        Paluu keskeytyksesta     [KERNEL]
    _op(1, 6, 2, 0): ("STI", 0, True),  # STI         Salli keskeytykset       [KERNEL]
    _op(1, 6, 3, 0): ("CLI", 0, True),  # CLI         Esta keskeytykset        [KERNEL]
    # -------------------------------------------------------------------------
    # GRP 7: JARJESTELMA JA IO (System)
    #   User-kaskyt:   EXIT/TSL/NOP  0x7500-0x7F00  (P=0, GRP=7)
    #   Kernel-kaskyt: HALT/DREAD/...     0xF000-0xF440  (P=1, GRP=7)
    # -------------------------------------------------------------------------
    _op(1, 7, 0, 0): (
        "HALT",
        0,
        True,
    ),  # HALT             Pysayta CPU               [KERNEL]
    _op(1, 7, 1, 2): (
        "DREAD",
        2,
        True,
    ),  # DREAD  regD, regS  Lue tallennuslaitteelta  [KERNEL]
    _op(1, 7, 2, 2): (
        "DWRITE",
        2,
        True,
    ),  # DWRITE regS, regD  Kirj. tallennuslaitteelle[KERNEL]
    _op(1, 7, 3, 1): (
        "SMPR",
        1,
        True,
    ),  # SMPR   reg         Aseta MPR                [KERNEL]
    _op(1, 7, 4, 1): (
        "STMR",
        1,
        True,
    ),  # STMR   reg         Aseta TMR                [KERNEL]
    _op(1, 7, 5, 1): (
        "SCTMR",
        1,
        True,
    ),  # SCTMR  reg         Aseta CTMR (ms-kellokeskeytys) [KERNEL]
    _op(0, 7, 5, 0): (
        "EXIT",
        0,
        False,
    ),  # EXIT               Hallittu lopetus         [USER]
    _op(0, 7, 7, 2): (
        "TSL",
        2,
        False,
    ),  # TSL    reg, addr   Test and Set Lock        [USER]
    **{
        (STATE_OPCODE_BASE | sid): ("STATE", 0, False)
        for sid in range(STATE_ID_COUNT)
    },  # STATE id(0..63)  1-sanaisen tilasignaalin lahetys [USER]
    _op(0, 7, 15, 0): (
        "NOP",
        0,
        False,
    ),  # NOP                Ei tee mitaan            [USER]
}

# =============================================================================
# SUORITUSSYKLIT: Käskyjen simuloidut suoritusajat
# =============================================================================
# Yksikkö: yksi sykli = yksi mikrosekuntia (µs) simuloidulla 1 MHz kellolla.
# Arvo kuvaa käskyn perussuoritusaikaa; FILL-käskyllä lisätään dynaamisesti
# täytettävien sanojen lukumäärä (cpu.py:n _get_exec_cycles).
#
# Periaatteet:
#   - Yksinkertaiset rekisterioperaatiot: 1 sykli
#   - Muistioperaatiot: 1 sykli (yksinkertaistettu malli)
#   - Monikertaiset laskuoperaatiot (MUL, DIV): korotettu sykli
#   - I/O-käskyt (DREAD, DWRITE): merkittävästi korotettu sykli
#   - Keskeytys- ja kontekstioperaatiot (INT, IRET, EXIT): korotettu sykli
#   - FILL: 1 (perussykli) + täytettävien sanojen lukumäärä (dynaaminen)
# =============================================================================

EXEC_CYCLES: dict[str, int] = {
    # -------------------------------------------------------------------------
    # GRP 1: TIEDONSIIRTOKASKYT
    # -------------------------------------------------------------------------
    "LOAD": 1,  # Vakion lataus rekisteriin
    "CPY": 1,  # Rekisteri -> rekisteri
    "READ": 1,  # Muistiosoiteluku
    "STORE": 1,  # Muistiosoitekirjoitus
    "READ_IND": 1,  # Epäsuora luku [reg]
    "STORE_IND": 1,  # Epäsuora kirjoitus [reg]
    "READ_REL": 1,  # Suhteellinen luku [FP+imm]
    "STORE_REL": 1,  # Suhteellinen kirjoitus [FP+imm]
    "STOREI": 1,  # Välitön kirjoitus muistiin
    "STOREI_IND": 1,  # Välitön kirjoitus [reg]
    "STOREI_REL": 1,  # Välitön kirjoitus [FP+imm]
    "FILL": 1,  # Perussykli; cpu.py lisää täytettävät sanat dynaamisesti
    "COPY": 1,  # Perussykli; cpu.py lisää kopioitavien sanojen määrän dynaamisesti
    # -------------------------------------------------------------------------
    # GRP 2: ARITMEETTISET KASKYT
    # -------------------------------------------------------------------------
    "ADD": 1,  # Yhteenlasku
    "SUB": 1,  # Vähennyslasku
    "MUL": 4,  # Kertolasku (monimutkaisempi)
    "DIV": 8,  # Jakolasku (monimutkaisin)
    "CMP": 1,  # Vertailu
    "ADC": 1,  # Yhteenlasku Carry-lipulla
    # -------------------------------------------------------------------------
    # GRP 3: LOGIIKKA JA BITTIKASKYT
    # -------------------------------------------------------------------------
    "AND": 1,
    "OR": 1,
    "XOR": 1,
    "NOT": 1,
    "SHL": 1,  # Looginen siirto vasemmalle
    "SHR": 1,  # Looginen siirto oikealle
    # -------------------------------------------------------------------------
    # GRP 4: PINOKASKYT
    # -------------------------------------------------------------------------
    "PUSH": 1,
    "POP": 1,
    "SWSP": 1,  # Pino-osoittimen vaihto
    # -------------------------------------------------------------------------
    # GRP 5: OHJAUSRAKENNEKASKYT
    # -------------------------------------------------------------------------
    "JUMP": 1,
    "CALL": 2,  # Push + hyppy
    "RET": 2,  # Pop
    "JZ": 1,
    "JNZ": 1,
    "JLT": 1,
    "JGT": 1,
    "JLE": 1,
    "JGE": 1,
    "JMPI": 2,  # Indeksoitu hyppy (perussykli; taulukon koko ignoroitu)
    "CALLI": 2,  # Indeksoitu kutsu (perussykli)
    # -------------------------------------------------------------------------
    # GRP 6: KESKEYTYKSET
    # -------------------------------------------------------------------------
    "INT": 4,  # Ohjelmallinen keskeytys (tallentaa tilan)
    "IRET": 4,  # Paluu keskeytyksestä (palauttaa tilan)
    "STI": 1,
    "CLI": 1,
    # -------------------------------------------------------------------------
    # GRP 7: JARJESTELMA JA IO
    # -------------------------------------------------------------------------
    "HALT": 1,
    "DREAD": 10,  # I/O-operaatio (hidas)
    "DWRITE": 10,  # I/O-operaatio (hidas)
    "SMPR": 1,
    "STMR": 1,
    "SCTMR": 1,
    "EXIT": 4,  # Prosessin lopetus (tallentaa tilan)
    "TSL": 2,  # Lue-muokkaa-kirjoita (atomi)
    "STATE": 1,  # 1-sanan tilasignaali emulaattorin UI:lle
    "NOP": 1,
}


# =============================================================================
# YHTENAINEN INSTRUCTION METADATA -KERROS
# =============================================================================

# Operandityyppien sanasto (lyhyet avaimet):
#   reg      = rekisteri-indeksi
#   imm      = valiton arvo
#   addr     = absoluuttinen osoite
#   offset   = FP-suhteinen offset
#   int_no   = keskeytysnumero
#   target   = hyppyosoite
#   reg_list = JMPI/CALLI-indeksirekisteri
#   target_list = JMPI/CALLI-kohdeosoitteet (muuttuva pituus)
OPERAND_TYPE_TABLE: dict[str, tuple[str, ...]] = {
    # Transfer
    "LOAD": ("reg", "imm"),
    "CPY": ("reg", "reg"),
    "READ": ("reg", "addr"),
    "STORE": ("reg", "addr"),
    "READ_IND": ("reg", "reg"),
    "STORE_IND": ("reg", "reg"),
    "READ_REL": ("reg", "offset"),
    "STORE_REL": ("reg", "offset"),
    "STOREI": ("imm", "addr"),
    "STOREI_IND": ("reg", "imm"),
    "STOREI_REL": ("imm", "offset"),
    "FILL": ("reg", "reg", "reg"),
    "COPY": ("reg", "reg", "reg"),
    # Arithmetic
    "ADD": ("reg", "reg"),
    "SUB": ("reg", "reg"),
    "MUL": ("reg", "reg"),
    "DIV": ("reg", "reg"),
    "CMP": ("reg", "reg"),
    "ADC": ("reg", "reg"),
    # Logic
    "AND": ("reg", "reg"),
    "OR": ("reg", "reg"),
    "XOR": ("reg", "reg"),
    "NOT": ("reg",),
    "SHL": ("reg", "reg"),
    "SHR": ("reg", "reg"),
    # Stack
    "PUSH": ("reg",),
    "POP": ("reg",),
    "SWSP": ("reg", "reg"),
    # Flow
    "JUMP": ("target",),
    "CALL": ("target",),
    "RET": (),
    "JZ": ("target",),
    "JNZ": ("target",),
    "JLT": ("target",),
    "JGT": ("target",),
    "JLE": ("target",),
    "JGE": ("target",),
    "JMPI": ("reg_list", "target_list"),
    "CALLI": ("reg_list", "target_list"),
    # Interrupt
    "INT": ("int_no",),
    "IRET": (),
    "STI": (),
    "CLI": (),
    # System
    "HALT": (),
    "DREAD": ("reg", "reg"),
    "DWRITE": ("reg", "reg"),
    "SMPR": ("reg",),
    "STMR": ("reg",),
    "SCTMR": ("reg",),
    "EXIT": (),
    "TSL": ("reg", "addr"),
    "STATE": ("imm6",),
    "NOP": (),
}

VARIABLE_LENGTH_MNEMONICS: frozenset[str] = frozenset({"JMPI", "CALLI"})

DEPRECATED_ASSEMBLER_MNEMONICS: frozenset[str] = frozenset(
    {
        "READ_IND",
        "READ_REL",
        "STORE_IND",
        "STORE_REL",
        "STOREI",
        "STOREI_IND",
        "STOREI_REL",
    }
)


def get_operand_types(mnemonic: str) -> tuple[str, ...]:
    """Palauta mnemoniikan operandityypit tyhjana tuplena jos tuntematon."""
    return OPERAND_TYPE_TABLE.get(mnemonic.upper(), ())


def is_variable_length_mnemonic(mnemonic: str) -> bool:
    """Palauta True jos mnemoniikka on muuttuvan mittainen (esim. JMPI/CALLI)."""
    return mnemonic.upper() in VARIABLE_LENGTH_MNEMONICS


def is_deprecated_assembler_mnemonic(mnemonic: str) -> bool:
    """Palauta True jos mnemoniikka kuuluu [..]-syntaksin korvaamiin vanhoihin muotoihin."""
    return mnemonic.upper() in DEPRECATED_ASSEMBLER_MNEMONICS


def format_disasm_memory_syntax(
    mnemonic: str,
    operands: list[int],
    reg_name_lookup: dict[int, str],
) -> str | None:
    """Muotoile muistioperaatiot [..]-syntaksilla disassemblerin kayttoon."""

    def r(idx: int) -> str:
        """Return readable register name for operand index."""
        return reg_name_lookup.get(idx, f"?{idx}")

    key = mnemonic.upper()
    if key == "READ" and len(operands) >= 2:
        return f"LOAD {r(operands[0])}, [0x{operands[1]:04X}]"
    if key == "READ_IND" and len(operands) >= 2:
        return f"LOAD {r(operands[0])}, [{r(operands[1])}]"
    if key == "READ_REL" and len(operands) >= 2:
        return f"LOAD {r(operands[0])}, [FP+{operands[1]}]"
    if key == "STORE" and len(operands) >= 2:
        return f"STORE [0x{operands[1]:04X}], {r(operands[0])}"
    if key == "STOREI" and len(operands) >= 2:
        return f"STORE [0x{operands[1]:04X}], {operands[0]}"
    if key == "STORE_IND" and len(operands) >= 2:
        return f"STORE [{r(operands[0])}], {r(operands[1])}"
    if key == "STOREI_IND" and len(operands) >= 2:
        return f"STORE [{r(operands[0])}], {operands[1]}"
    if key == "STORE_REL" and len(operands) >= 2:
        return f"STORE [FP+{operands[1]}], {r(operands[0])}"
    if key == "STOREI_REL" and len(operands) >= 2:
        return f"STORE [FP+{operands[1]}], {operands[0]}"
    return None
