"""
Kaskyjen metatiedot ja opcode-taulukko.

Tama tiedosto maarittaa kCPU16-prosessorin kaskykirjaston (Instruction Set).
Se sisaltaa:
1. DecodedInstruction - puretun kaskyn tietorakenne
2. OPCODE_TABLE - opcode-arvojen ja kaskymetatietojen kuvaus

OPCODE-KOODAUS:
---------------
Kaskyt koostuvat 1-3 sanasta:
- Sana 1: Opcode (maarittelee kaskyn tyypin)
- Sana 2-3: Operandit (rekisteri-indekseja, muistiosoitteita tai vakioita)

Esimerkki: LOAD R0, 42
- Sana 1: 0x0001 (LOAD-opcode)
- Sana 2: 0x0000 (R0:n indeksi)
- Sana 3: 0x002A (arvo 42)

KASKYJEN LUOKITTELU:
--------------------
1. TIEDONSIIRTO: LOAD, CPY, READ, STORE, READ_IND, STORE_IND
2. ARITMETIIKKA: ADD, SUB, MUL, DIV, CMP
3. PINO: PUSH, POP
4. HYPPYKASKYT: JUMP, JZ, JNZ, JLT, CALL, RET
5. KESKEYTYKSET: INT, IRET
6. JARJESTELMA: STI, CLI, HALT, EXIT, DREAD, DWRITE, SMPR, STMR
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
# OPCODE-TAULUKKO
# Kuvaa jokaisen tuetun kaskyn: opcode -> (mnemonic, operandien_maara, privileged)
#
# Formaatti:
#   opcode: (kaskyn_nimi, operandien_lukumaara, vaatiiko_kernel_tilan)
#
# Operandimaarat:
#   0 = ei operandeja (esim. RET, HALT)
#   1 = yksi operandi (esim. PUSH reg, JUMP addr)
#   2 = kaksi operandia (esim. LOAD reg, imm  tai  ADD regD, regS)
# =============================================================================

OPCODE_TABLE: dict[int, tuple[str, int, bool]] = {
    # -------------------------------------------------------------------------
    # TIEDONSIIRTOKASKYT (Data Transfer)
    # -------------------------------------------------------------------------
    0x0001: ("LOAD", 2, False),  # LOAD reg, imm  - Lataa vakio rekisteriin
    0x0002: ("CPY", 2, False),  # CPY regD, regS - Kopioi rekisterista toiseen
    0x0003: ("READ", 2, False),  # READ reg, addr - Lue muistiosoite rekisteriin
    0x0004: ("STORE", 2, False),  # STORE reg, addr - Tallenna rekisteri muistiin
    0x0005: (
        "READ_IND",
        2,
        False,
    ),  # READ_IND regD, regS - Lue epäsuorasti [regS] -> regD
    0x0006: ("STORE_IND", 2, False),  # STORE_IND regD, regS - Kirjoita [regD] <- regS
    # -------------------------------------------------------------------------
    # ARITMEETTISET KASKYT (Arithmetic & Logic)
    # -------------------------------------------------------------------------
    0x0010: ("ADD", 2, False),  # ADD regD, regS - regD = regD + regS
    0x0011: ("SUB", 2, False),  # SUB regD, regS - regD = regD - regS
    0x0012: ("MUL", 2, False),  # MUL regD, regS - regD = regD * regS
    0x0013: (
        "DIV",
        2,
        False,
    ),  # DIV regD, regS - regD = regD / regS (INT 0 jos jakaja=0)
    0x0014: (
        "CMP",
        2,
        False,
    ),  # CMP regA, regB - Vertaa (laskee regA-regB, asettaa liput)
    # -------------------------------------------------------------------------
    # PINOKASKYT (Stack Operations)
    # -------------------------------------------------------------------------
    0x0020: ("PUSH", 1, False),  # PUSH reg - Tallenna rekisteri pinoon
    0x0021: ("POP", 1, False),  # POP reg - Hae pinosta rekisteriin
    # -------------------------------------------------------------------------
    # HYPPYKASKYT (Control Flow)
    # -------------------------------------------------------------------------
    0x0030: ("JUMP", 1, False),  # JUMP addr - Ehdoton hyppy
    0x0031: ("CALL", 1, False),  # CALL addr - Aliohjelmakutsu (PUSH PC, JUMP addr)
    0x0032: ("RET", 0, False),  # RET - Paluu aliohjelmasta (POP PC)
    0x0033: ("JZ", 1, False),  # JZ addr - Hyppa jos Z=1 (tulos oli nolla)
    0x0034: ("JNZ", 1, False),  # JNZ addr - Hyppa jos Z=0 (tulos ei ollut nolla)
    0x0035: ("JLT", 1, False),  # JLT addr - Hyppa jos N!=V (pienempi kuin)
    # -------------------------------------------------------------------------
    # KESKEYTYSKASKYT (Interrupt Handling)
    # -------------------------------------------------------------------------
    0x0040: ("INT", 1, False),  # INT imm - Ohjelmallinen keskeytys (syscall)
    0x0041: ("IRET", 0, True),  # IRET - Paluu keskeytyksesta (POP SR, POP PC) [KERNEL]
    0x0042: ("STI", 0, True),  # STI - Salli keskeytykset (I=1) [KERNEL]
    0x0043: ("CLI", 0, True),  # CLI - Esta keskeytykset (I=0) [KERNEL]
    0x0044: ("HALT", 0, True),  # HALT - Pysayta prosessori [KERNEL]
    # -------------------------------------------------------------------------
    # JARJESTELMAKASKYT (System Operations)
    # -------------------------------------------------------------------------
    0x0045: ("DREAD", 2, True),  # DREAD regD, regS - Lue tallennuslaitteelta [KERNEL]
    0x0046: (
        "DWRITE",
        2,
        True,
    ),  # DWRITE regS, regD - Kirjoita tallennuslaitteelle [KERNEL]
    0x0047: ("SMPR", 1, True),  # SMPR reg - Aseta MPR (muistisuojaraja) [KERNEL]
    0x0048: ("STMR", 1, True),  # STMR reg - Aseta TMR (ajastinvali) [KERNEL]
    0x0049: ("EXIT", 0, False),  # EXIT - Prosessin hallittu lopetus (INT 8)
}
