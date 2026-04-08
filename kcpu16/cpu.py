"""
CPU-ydin kCPU16-prosessorille.

Toteuttaa prosessorin Fetch-Decode-Execute -syklin ja kaikkien
kaskyjen suorituslogiikan.

SUORITUSSYKLI:
--------------
1. FETCH: Lue kasky muistista PC:n osoitteesta
2. PRIVILEGE CHECK: Tarkista kaskyoikeudet (Kernel vs. User)
3. MEMORY CHECK: Tarkista muistiviittausten laillisuus
4. EXECUTE: Suorita kasky
5. PC UPDATE: Siirra PC seuraavaan kaskyyn

KESKEYTUSTEN KASITTELY:
-----------------------
Kun virhe tapahtuu (esim. InvalidOpcode), CPU:
1. Tallentaa PC:n ja SR:n pinoon (PUSH PC, PUSH SR)
2. Siirtyy Kernel-tilaan (P=1)
3. Estaa keskeytykset (I=0)
4. Hakee kasittelijan osoitteen vektorista ja hyppaa sinne

REKISTERIEN KOODAUS:
--------------------
Operandeissa rekisterit koodataan indekseilla 0-5:
    0 = R0, 1 = R1, 2 = R2, 3 = R3, 4 = FP, 5 = SP
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from .constants import (
    BOOT_RAM_END,
    BOOT_RAM_START,
    INT_DIV_ZERO,
    INT_INVALID_OPCODE,
    INT_MEMORY_ACCESS_FAULT,
    INT_PROCESS_EXIT,
    INT_PRIVILEGE_VIOLATION,
    INT_STACK_OVERFLOW,
    INT_TIMER,
    INT_VECTOR_COUNT,
    INT_VECTOR_BASE,
    REG_IDX_MASK,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    MODE_KERNEL,
    WORD_BITS,
    WORD_MASK,
    WORD_SIGN_BIT,
)
from .exceptions import (
    InvalidOpcodeError,
    MemoryAccessFaultError,
    PrivilegeViolationError,
    StackOverflowError,
)
from .instruction import (
    DecodedInstruction,
    OPCODE_TABLE,
    OPCODE_PRIV_SHIFT,
    OPCODE_NOPS_SHIFT,
    OPCODE_NOPS_MASK,
)
from .memory import Memory
from .registers import RegisterFile

# TYPE_CHECKING-lohko estaa syklisen importin ajonaikana
if TYPE_CHECKING:
    from .devices.storage import BlockStorageDevice
    from .devices.keyboard import KeyboardDevice


@dataclass
class CPU:
    """
    kCPU16-prosessorin ydin.

    Toteuttaa suoritussyklin ja kaikkien kaskyjen logiikan.

    Attributes:
        memory: Muistiolio (65536 sanaa)
        regs: Rekisteritiedosto (R0-R3, FP, SP, PC, SR, MPR, TMR)
        storage: Tallennuslaite DREAD/DWRITE-kaskyjä varten (valinnainen)
        halted: True jos HALT-kasky suoritettu
        instruction_counter: Suoritettujen kaskyjen laskuri
        process_exit_requested: True jos EXIT-kasky suoritettu
    """

    memory: Memory  # Paamuisti
    regs: RegisterFile  # Rekisterit
    storage: "BlockStorageDevice | None" = None  # Tallennuslaite (valinnainen)
    keyboard: "KeyboardDevice | None" = None  # Nappaimistolaite (valinnainen)

    halted: bool = False  # Onko kone pysahtynyt (HALT)?
    instruction_counter: int = 0  # Suoritettujen kaskyjen maara
    process_exit_requested: bool = False  # Onko EXIT kutsuttu?

    def reset(self) -> None:
        """
        Nollaa CPU alkutilaan.

        Kaytetaan koneen uudelleenkaynnistyksessa:
        - Poistaa halted- ja exit-tilat
        - Nollaa kaskylaskurin
        - Nollaa rekisterit (kutsu regs.reset())
        """
        self.halted = False
        self.instruction_counter = 0
        self.process_exit_requested = False
        self.regs.reset()

    def step(self) -> None:
        """
        Suorita yksi Fetch-Decode-Execute -sykli.

        Tama on prosessorin "sydamenlyonti". Jokainen kutsu:
        1. Hakee kaskyn muistista (fetch)
        2. Tarkistaa oikeudet (privilege check)
        3. Tarkistaa muistikayton (memory check)
        4. Suorittaa kaskyn (execute)
        5. Paivittaa PC:n (pc update)

        Virhetilanteissa (poikkeukset) aktivoidaan keskeytys eika
        PC:ta paiviteta normaalisti.
        """
        # Jos kone on pysahtynyt, alä tee mitaan
        if self.halted:
            return

        try:
            # ------------------------------------------------------------------
            # VAIHE 1: FETCH & DECODE
            # Lue opcode ja operandit muistista PC:n osoitteesta
            # ------------------------------------------------------------------
            decoded = self._fetch_decode(self.regs.pc)

            # ------------------------------------------------------------------
            # VAIHE 2: PRIVILEGE CHECK
            # Tarkista onko User-tilalla oikeus suorittaa tata kaskya
            # ------------------------------------------------------------------
            self._check_privilege(decoded)

            # ------------------------------------------------------------------
            # VAIHE 3: MEMORY CHECK
            # Tarkista etta kaikki muistiviittaukset ovat sallittuja
            # ------------------------------------------------------------------
            self._check_memory_access(decoded)

            # ------------------------------------------------------------------
            # VAIHE 4: EXECUTE
            # Suorita kaskyn varsinainen toiminto
            # ------------------------------------------------------------------
            self._execute(decoded)

            # ------------------------------------------------------------------
            # VAIHE 5: PC UPDATE
            # Siirra ohjealaskuri seuraavaan kaskyyn (paitsi jos hypattiin)
            # ------------------------------------------------------------------
            self.regs.pc = (self.regs.pc + decoded.size_words) & WORD_MASK

            # Paivita laskuri ja tarkista ajastinkeskeytys
            self.instruction_counter += 1
            self._handle_timer_interrupt_if_needed()

        # ----------------------------------------------------------------------
        # VIRHEENKASITTELY: Muunna poikkeukset keskeytyksiksi
        # ----------------------------------------------------------------------
        except PrivilegeViolationError:
            # User yritti ajaa Kernel-kaskya -> INT 4
            self._trigger_interrupt(INT_PRIVILEGE_VIOLATION)
        except MemoryAccessFaultError:
            # User yritti lukea/kirjoittaa suojattua muistia -> INT 5
            self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
        except InvalidOpcodeError:
            # Tuntematon opcode -> INT 1
            self._trigger_interrupt(INT_INVALID_OPCODE)
        except ZeroDivisionError:
            # DIV-kaskyn jakaja oli 0 -> INT 0
            self._trigger_interrupt(INT_DIV_ZERO)
        except StackOverflowError:
            # Pino meni MPR:n alle -> INT 2
            self._trigger_interrupt(INT_STACK_OVERFLOW)

    def run(self, max_cycles: int = 1_000_000) -> None:
        """
        Suorita kaskyjä kunnes pysaytysehto tayttyy.

        Pysaytysehdot:
        1. HALT-kasky suoritettu (halted = True)
        2. EXIT-kasky suoritettu (process_exit_requested = True)
        3. max_cycles-raja saavutettu (ikuisen silmukan esto)

        Args:
            max_cycles: Maksimi suoritettavien kaskyjen maara
        """
        cycles = 0
        while (
            not self.halted and not self.process_exit_requested and cycles < max_cycles
        ):
            self.step()
            cycles += 1

    # ==========================================================================
    # SISAISET METODIT: FETCH, DECODE, CHECK, EXECUTE
    # ==========================================================================

    def _fetch_decode(self, pc: int) -> DecodedInstruction:
        """
        Hae kasky muistista ja dekoodaa se.

        Lukee opcoden PC:n osoitteesta ja mahdolliset lisaoperandit
        seuraavista osoitteista. Palauttaa puretun kaskyn.

        Args:
            pc: Ohjelmalaskurin osoite (mista kasky luetaan)

        Returns:
            DecodedInstruction-olio kaskymetatietoineen

        Raises:
            InvalidOpcodeError: Jos opcode ei ole taulukossa
        """
        # Lue opcode-sana
        opcode = self.memory.read(pc)

        # Etsi mnemonic taulukosta (taulukko on opcode -> (mnemonic, nops, priv))
        if opcode not in OPCODE_TABLE:
            raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")

        mnemonic, operand_count, _ = OPCODE_TABLE[opcode]

        # Johda operandien maara ja privilege suoraan opcode-biteista
        # (OPS-kentta bits 7:6, P-bitti bit 15)
        operand_count = (opcode >> OPCODE_NOPS_SHIFT) & OPCODE_NOPS_MASK
        privileged = bool((opcode >> OPCODE_PRIV_SHIFT) & 1)

        # Lue operandit perakkaisista muistiosoitteista
        operands: list[int] = []
        for i in range(operand_count):
            operands.append(self.memory.read(pc + 1 + i))

        return DecodedInstruction(
            mnemonic=mnemonic,
            operands=operands,
            size_words=1 + operand_count,  # opcode + operandien maara
            privileged=privileged,
        )

    def _check_privilege(self, ins: DecodedInstruction) -> None:
        """
        Tarkista onko kaskylle oikeutta suorittaa.

        Kernel-kaskyt (privileged=True) ovat sallittuja vain
        Kernel-tilassa (P=1).

        Args:
            ins: Dekoodattu kasky

        Raises:
            PrivilegeViolationError: Jos User yrittaa ajaa Kernel-kaskya
        """
        if ins.privileged and not self.regs.in_kernel_mode:
            raise PrivilegeViolationError(ins.mnemonic)

    def _check_memory_access(self, ins: DecodedInstruction) -> None:
        """
        Tarkista etta muistiviittaukset ovat sallittuja.

        User-tilassa ei saa lukea/kirjoittaa osoitteisiin alle MPR:n
        (paitsi VRAM joka on aina sallittu).

        Args:
            ins: Dekoodattu kasky

        Raises:
            MemoryAccessFaultError: Jos User viittaa suojattuun muistiin
        """
        # Kernel-tilassa kaikki on sallittua
        if self.regs.in_kernel_mode:
            return

        # Tarkista suora muistiviittaus (READ/STORE/STOREI osoite operandissa)
        if ins.mnemonic in {"READ", "STORE"} and len(ins.operands) >= 2:
            addr = ins.operands[1]  # toinen operandi on osoite
            self.memory.check_user_access(addr, self.regs.mpr)

        elif ins.mnemonic == "STOREI" and len(ins.operands) >= 2:
            addr = ins.operands[1]  # toinen operandi on osoite
            self.memory.check_user_access(addr, self.regs.mpr)

        # Tarkista epasuora lukuviittaus (READ_IND: osoite rekisterissa)
        elif ins.mnemonic == "READ_IND" and len(ins.operands) >= 2:
            addr = self._get_reg(ins.operands[1])  # regS sisaltaa osoitteen
            self.memory.check_user_access(addr, self.regs.mpr)

        # Tarkista epasuora kirjoitusviittaus (STORE_IND/STOREI_IND: osoite rekisterissa)
        elif ins.mnemonic == "STORE_IND" and len(ins.operands) >= 2:
            addr = self._get_reg(ins.operands[0])  # regD sisaltaa kohdeosoitteen
            self.memory.check_user_access(addr, self.regs.mpr)

        elif ins.mnemonic == "STOREI_IND" and len(ins.operands) >= 2:
            addr = self._get_reg(ins.operands[0])  # regD sisaltaa kohdeosoitteen
            self.memory.check_user_access(addr, self.regs.mpr)

        # Tarkista FP-suhteellinen lukuviittaus (READ_REL: [FP + imm])
        elif ins.mnemonic == "READ_REL" and len(ins.operands) >= 2:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

        # Tarkista FP-suhteellinen kirjoitusviittaus (STORE_REL/STOREI_REL: [FP + imm])
        elif ins.mnemonic == "STORE_REL" and len(ins.operands) >= 2:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

        elif ins.mnemonic == "STOREI_REL" and len(ins.operands) >= 2:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

        # Tarkista TSL-muistiviittaus (TSL: lukee ja kirjoittaa addr)
        elif ins.mnemonic == "TSL" and len(ins.operands) >= 2:
            addr = ins.operands[1]
            self.memory.check_user_access(addr, self.regs.mpr)

    def _execute(self, ins: DecodedInstruction) -> None:
        """
        Suorita dekoodattu kasky.

        Tama on prosessorin "lihas" - tassa tapahtuu varsinainen
        laskenta, muistinkaytto ja tilamuutokset.

        Args:
            ins: Dekoodattu kasky mnemonic- ja operandi-tietoineen

        Raises:
            ZeroDivisionError: Jos DIV-kaskyn jakaja on 0
            InvalidOpcodeError: Jos kaskya ei tunnisteta
        """
        # ======================================================================
        # TIEDONSIIRTOKASKYT
        # ======================================================================

        if ins.mnemonic == "JARI":
            # JARI reg, imm - Lataa vakioarvo rekisteriin
            reg_idx, imm = ins.operands
            self._set_reg(reg_idx, imm)

        elif ins.mnemonic == "CPY":
            # CPY regD, regS - Kopioi lahderekisterista kohteeseen
            dst, src = ins.operands
            self._set_reg(dst, self._get_reg(src))

        elif ins.mnemonic == "READ":
            # READ reg, addr - Lue muistiosoitteen arvo rekisteriin
            reg_idx, addr = ins.operands
            self._set_reg(reg_idx, self.memory.read(addr))

        elif ins.mnemonic == "STORE":
            # STORE reg, addr - Tallenna rekisterin arvo muistiin
            reg_idx, addr = ins.operands
            self.memory.write(addr, self._get_reg(reg_idx))

        elif ins.mnemonic == "READ_IND":
            # READ_IND regD, regS - Lue muistista regS:n osoittamasta paikasta
            # regD = [regS]
            reg_dst, reg_addr = ins.operands
            self._set_reg(reg_dst, self.memory.read(self._get_reg(reg_addr)))

        elif ins.mnemonic == "STORE_IND":
            # STORE_IND regD, regS - Kirjoita regS regD:n osoittamaan paikkaan
            # [regD] = regS
            reg_addr, reg_src = ins.operands
            self.memory.write(self._get_reg(reg_addr), self._get_reg(reg_src))

        elif ins.mnemonic == "READ_REL":
            # READ_REL reg, imm - Lue muistista FP + imm rekisteriin
            # reg = [FP + imm]
            reg_idx, offset = ins.operands
            addr = (self.regs.fp + offset) & WORD_MASK
            self._set_reg(reg_idx, self.memory.read(addr))

        elif ins.mnemonic == "STORE_REL":
            # STORE_REL reg, imm - Kirjoita rekisteri muistiin FP + imm
            # [FP + imm] = reg
            reg_idx, offset = ins.operands
            addr = (self.regs.fp + offset) & WORD_MASK
            self.memory.write(addr, self._get_reg(reg_idx))

        elif ins.mnemonic == "STOREI":
            # STOREI imm, addr - Kirjoita välitön arvo muistiosoitteeseen
            # [addr] = imm
            imm, addr = ins.operands
            self.memory.write(addr, imm & WORD_MASK)

        elif ins.mnemonic == "STOREI_IND":
            # STOREI_IND regD, imm - Kirjoita välitön arvo regD:n osoittamaan paikkaan
            # [regD] = imm
            reg_addr, imm = ins.operands
            self.memory.write(self._get_reg(reg_addr), imm & WORD_MASK)

        elif ins.mnemonic == "STOREI_REL":
            # STOREI_REL imm, offset - Kirjoita välitön arvo [FP + offset]:een
            # [FP + offset] = imm
            imm, offset = ins.operands
            addr = (self.regs.fp + offset) & WORD_MASK
            self.memory.write(addr, imm & WORD_MASK)

        # ======================================================================
        # ARITMEETTISET KASKYT
        # ======================================================================

        elif ins.mnemonic == "ADD":
            # ADD regD, regS - Yhteenlasku: regD = regD + regS
            dst, src = ins.operands
            a = self._get_reg(dst)
            b = self._get_reg(src)
            result = a + b
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            # Carry jos tulos ylitti 16 bittia
            # Overflow jos molemmat samanmerkkiset ja tulos erimerkkinen
            masked = result & WORD_MASK
            overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
            self.regs.set_carry_overflow(result > WORD_MASK, overflow)

        elif ins.mnemonic == "MUL":
            # MUL regD, regS - Kertolasku: regD = regD * regS
            dst, src = ins.operands
            a = self._get_reg(dst)
            b = self._get_reg(src)
            result = a * b
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            masked = result & WORD_MASK
            overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
            self.regs.set_carry_overflow(result > WORD_MASK, overflow)

        elif ins.mnemonic == "SUB":
            # SUB regD, regS - Vahennyslasku: regD = regD - regS
            dst, src = ins.operands
            a = self._get_reg(dst)
            b = self._get_reg(src)
            result = (a - b) & WORD_MASK  # Varmista positiivinen tulos
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            # Carry (borrow) jos a < b
            # Overflow jos operandit erimerkkiset ja tulos erimerkkinen kuin a
            overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
            self.regs.set_carry_overflow(a < b, overflow)

        elif ins.mnemonic == "DIV":
            # DIV regD, regS - Jakolasku: regD = regD / regS
            dst, src = ins.operands
            divisor = self._get_reg(src)
            if divisor == 0:
                # Jako nollalla -> keskeytys (kasitellaan step()-metodissa)
                raise ZeroDivisionError()
            result = self._get_reg(dst) // divisor  # Kokonaislukujakoa
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)

        # ======================================================================
        # LOGIIKKAKASKYT
        # ======================================================================

        elif ins.mnemonic == "AND":
            # AND regD, regS - Bittitason JA: regD = regD & regS
            dst, src = ins.operands
            result = self._get_reg(dst) & self._get_reg(src)
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(False, False)

        elif ins.mnemonic == "OR":
            # OR regD, regS - Bittitason TAI: regD = regD | regS
            dst, src = ins.operands
            result = self._get_reg(dst) | self._get_reg(src)
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(False, False)

        elif ins.mnemonic == "XOR":
            # XOR regD, regS - Bittitason XOR: regD = regD ^ regS
            dst, src = ins.operands
            result = self._get_reg(dst) ^ self._get_reg(src)
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(False, False)

        elif ins.mnemonic == "NOT":
            # NOT reg - Bittitason komplementti: reg = ~reg
            (reg_idx,) = ins.operands
            result = (~self._get_reg(reg_idx)) & WORD_MASK
            self._set_reg(reg_idx, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(False, False)

        elif ins.mnemonic == "SHL":
            # SHL regD, regS - Siirto vasemmalle: regD = regD << regS
            # Carry = viimeisin ulos siirtynyt bitti
            dst, src = ins.operands
            a = self._get_reg(dst)
            shift = self._get_reg(src) & WORD_MASK
            if shift == 0:
                result = a
                carry = False
            elif shift > WORD_BITS:
                result = 0
                carry = False
            else:
                carry = bool((a >> (WORD_BITS - shift)) & 1)
                result = (a << shift) & WORD_MASK
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(carry, False)

        elif ins.mnemonic == "SHR":
            # SHR regD, regS - Looginen siirto oikealle: regD = regD >> regS
            # Carry = viimeisin ulos siirtynyt bitti
            dst, src = ins.operands
            a = self._get_reg(dst)
            shift = self._get_reg(src) & WORD_MASK
            if shift == 0:
                result = a
                carry = False
            elif shift > WORD_BITS:
                result = 0
                carry = False
            else:
                carry = bool((a >> (shift - 1)) & 1)
                result = (a >> shift) & WORD_MASK
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(carry, False)

        elif ins.mnemonic == "ADC":
            # ADC regD, regS - Yhteenlasku Carry-lipun kanssa
            # regD = regD + regS + C
            dst, src = ins.operands
            a = self._get_reg(dst)
            b = self._get_reg(src)
            c = self.regs.get_flag(SR_FLAG_C)
            result = a + b + c
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            masked = result & WORD_MASK
            overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
            self.regs.set_carry_overflow(result > WORD_MASK, overflow)

        # ======================================================================
        # PINOKASKYT
        # ======================================================================

        elif ins.mnemonic == "PUSH":
            # PUSH reg - Tallenna rekisterin arvo pinoon
            # [SP] = reg; SP = SP - 1
            (reg_idx,) = ins.operands
            self._push(self._get_reg(reg_idx))

        elif ins.mnemonic == "POP":
            # POP reg - Hae arvo pinosta rekisteriin
            # SP = SP + 1; reg = [SP]
            (reg_idx,) = ins.operands
            self._set_reg(reg_idx, self._pop())

        elif ins.mnemonic == "SWSP":
            # SWSP regD, regS - Vaihda pinon osoitinta
            # regD = SP; SP = regS (atominen kontekstin vaihto)
            dst, src = ins.operands
            old_sp = self.regs.sp
            self.regs.sp = self._get_reg(src) & WORD_MASK
            self._set_reg(dst, old_sp)

        # ======================================================================
        # HYPPYKASKYT
        # ======================================================================

        elif ins.mnemonic == "JUMP":
            # JUMP addr - Ehdoton hyppy osoitteeseen
            # Huom: PC-paivitys step()-metodissa lisaa size_words,
            # joten vahennamme sen etukateeen
            (addr,) = ins.operands
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "CALL":
            # CALL addr - Aliohjelmakutsu
            # PUSH (paluuosoite), JUMP addr
            (addr,) = ins.operands
            # Paluuosoite = seuraava kasky = PC + size_words
            self._push((self.regs.pc + ins.size_words) & WORD_MASK)
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "RET":
            # RET - Paluu aliohjelmasta
            # POP PC (paluuosoite)
            self.regs.pc = (self._pop() - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "INT":
            # INT imm - Ohjelmallinen keskeytys (syscall)
            # Ensin paivita PC paluuosoitteeksi (seuraava kasky INT:n jalkeen)
            # jotta _trigger_interrupt tallentaa oikean paluuosoitteen pinoon.
            (int_no,) = ins.operands
            self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
            self._trigger_interrupt(int_no)
            # Kompensoi step():n PC-paivitys
            self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "IRET":
            # IRET - Paluu keskeytyksesta
            # POP SR (palauta tilaliput), POP PC (palauta ohjelmalaskuri)
            old_sr = self._pop()
            old_pc = self._pop()
            self.regs.sr = old_sr & WORD_MASK
            # Kompensoi PC-paivitys
            self.regs.pc = (old_pc - ins.size_words) & WORD_MASK

        # ======================================================================
        # KESKEYTYSTEN HALLINTA
        # ======================================================================

        elif ins.mnemonic == "STI":
            # STI - Set Interrupt flag (salli laitteistokeskeytykset)
            self.regs.set_flag(SR_FLAG_I, 1)

        elif ins.mnemonic == "CLI":
            # CLI - Clear Interrupt flag (esta laitteistokeskeytykset)
            self.regs.set_flag(SR_FLAG_I, 0)

        elif ins.mnemonic == "HALT":
            # HALT - Pysayta prosessori
            self.halted = True

        elif ins.mnemonic == "EXIT":
            # EXIT - Prosessin hallittu lopetus
            # Aseta lippu ja laukaise keskeytys OS:lle
            self.process_exit_requested = True
            self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
            self._trigger_interrupt(INT_PROCESS_EXIT)
            self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

        # ======================================================================
        # JARJESTELMAKASKYT
        # ======================================================================

        elif ins.mnemonic == "SMPR":
            # SMPR reg - Set Memory Protection Register
            # Asettaa User-tilan muistirajan
            (reg_idx,) = ins.operands
            self.regs.mpr = self._get_reg(reg_idx)

        elif ins.mnemonic == "CMP":
            # CMP regA, regB - Vertaa rekistereita
            # Laskee regA - regB ja asettaa liput, mutta ei tallenna tulosta
            reg_a, reg_b = ins.operands
            a = self._get_reg(reg_a)
            b = self._get_reg(reg_b)
            result = (a - b) & WORD_MASK
            self.regs.set_zn_flags(result)
            overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
            self.regs.set_carry_overflow(a < b, overflow)

        elif ins.mnemonic == "JZ":
            # JZ addr - Jump if Zero (hyppa jos Z=1)
            # Kaytetaan CMP:n jalkeen tarkistamaan yhtasuuruus
            (addr,) = ins.operands
            if self.regs.get_flag(SR_FLAG_Z):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "JNZ":
            # JNZ addr - Jump if Not Zero (hyppa jos Z=0)
            (addr,) = ins.operands
            if not self.regs.get_flag(SR_FLAG_Z):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "JLT":
            # JLT addr - Jump if Less Than (hyppa jos N != V)
            # Toimii oikein myös etumerkillisilla luvuilla
            (addr,) = ins.operands
            if self.regs.get_flag(SR_FLAG_N) != self.regs.get_flag(SR_FLAG_V):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "JGT":
            # JGT addr - Jump if Greater Than (hyppa jos Z=0 ja N=V)
            # Suurempi kuin: ei yhtasuuri ja ei pienempi kuin
            (addr,) = ins.operands
            z = self.regs.get_flag(SR_FLAG_Z)
            n = self.regs.get_flag(SR_FLAG_N)
            v = self.regs.get_flag(SR_FLAG_V)
            if z == 0 and n == v:
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "JLE":
            # JLE addr - Jump if Less or Equal (hyppa jos Z=1 tai N!=V)
            # Pienempi tai yhtasuuri: yhtasuuri tai pienempi kuin
            (addr,) = ins.operands
            z = self.regs.get_flag(SR_FLAG_Z)
            n = self.regs.get_flag(SR_FLAG_N)
            v = self.regs.get_flag(SR_FLAG_V)
            if z == 1 or n != v:
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "JGE":
            # JGE addr - Jump if Greater or Equal (hyppa jos N=V)
            # Suurempi tai yhtasuuri: ei pienempi kuin
            (addr,) = ins.operands
            if self.regs.get_flag(SR_FLAG_N) == self.regs.get_flag(SR_FLAG_V):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK

        elif ins.mnemonic == "STMR":
            # STMR reg - Set Timer Register
            # Asettaa ajastinkeskeytyksen valin (0 = pois paalta)
            (reg_idx,) = ins.operands
            self.regs.tmr = self._get_reg(reg_idx)

        elif ins.mnemonic == "DREAD":
            # DREAD regD, regS - Lue tallennuslaitteelta
            # regD = storage[regS]
            reg_dst, reg_addr = ins.operands
            if self.storage is None:
                raise InvalidOpcodeError("Storage device not connected")
            storage_addr = self._get_reg(reg_addr)
            self._set_reg(reg_dst, self.storage.read_word(storage_addr))

        elif ins.mnemonic == "DWRITE":
            # DWRITE regS, regD - Kirjoita tallennuslaitteelle
            # storage[regD] = regS
            reg_src, reg_addr = ins.operands
            if self.storage is None:
                raise InvalidOpcodeError("Storage device not connected")
            storage_addr = self._get_reg(reg_addr)
            self.storage.write_word(storage_addr, self._get_reg(reg_src))

        elif ins.mnemonic == "KGET":
            # KGET reg - Lue viimeisin nappainpainallus rekisteriin
            (reg_idx,) = ins.operands
            if self.keyboard is None:
                self._set_reg(reg_idx, 0)
            else:
                self._set_reg(reg_idx, self.keyboard.pop_key())

        elif ins.mnemonic == "TSL":
            # TSL reg, addr - Test and Set Lock (atominen)
            # reg = [addr]; [addr] = 1
            reg_idx, addr = ins.operands
            old_value = self.memory.read(addr)
            self._set_reg(reg_idx, old_value)
            self.memory.write(addr, 1)
            self.regs.set_zn_flags(old_value)

        elif ins.mnemonic == "NOP":
            # NOP - Ei tee mitaan; kayttaa yhden syklin
            pass

        else:
            # Tuntematon kasky
            raise InvalidOpcodeError(ins.mnemonic)

    # ==========================================================================
    # KESKEYTYSTEN KASITTELY
    # ==========================================================================

    def _trigger_interrupt(self, int_no: int) -> None:
        """
        Aktivoi keskeytys.

        Keskeytyksen aktivointi (atominen operaatio):
        1. PUSH PC (nykyinen ohjelmalaskuri)
        2. PUSH SR (nykyiset tilaliput)
        3. P = 1 (siirry Kernel-tilaan)
        4. I = 0 (esta lisäkeskeytykset)
        5. PC = [vektori] (hae kasittelijan osoite)

        Args:
            int_no: Keskeytyksen numero (0-8)
        """
        int_no &= WORD_MASK

        # Laske vektoriosoite (kierrattamalla jos numero liian iso)
        vector_addr = (INT_VECTOR_BASE + (int_no % INT_VECTOR_COUNT)) & WORD_MASK

        # Tallenna nykyinen tila pinoon
        self._push(self.regs.pc)
        self._push(self.regs.sr)

        # Siirry Kernel-tilaan ja esta keskeytykset
        self.regs.set_flag(SR_FLAG_P, MODE_KERNEL)  # P = 1 (Kernel Mode)
        self.regs.set_flag(SR_FLAG_I, 0)  # I = 0 (keskeytykset pois)

        # Hae kasittelijan osoite vektorista ja aseta PC
        self.regs.pc = self.memory.read(vector_addr)

    def _handle_timer_interrupt_if_needed(self) -> None:
        """
        Tarkista ja laukaise ajastinkeskeytys tarvittaessa.

        Ajastinkeskeytys (INT 7) laukeaa kun:
        - TMR > 0 (ajastin on paalla)
        - I = 1 (keskeytykset ovat sallitut)
        - instruction_counter on TMR:n monikerta
        """
        # TMR = 0 tarkoittaa etta ajastin on pois paalta
        if self.regs.tmr == 0:
            return

        # Keskeytykset on estettava ->  ei laukaista
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return

        # Laukaise kun counter % TMR == 0
        if (
            self.instruction_counter > 0
            and (self.instruction_counter % self.regs.tmr) == 0
        ):
            self._trigger_interrupt(INT_TIMER)

    # ==========================================================================
    # PINOOPERAATIOT
    # ==========================================================================

    def _push(self, value: int) -> None:
        """
        Tallenna arvo pinoon.

        Pino kasvaa alaspain (push vahentaa SP:ta):
        1. [SP] = value (kirjoita nykyinen arvo)
        2. SP = SP - 1 (siirra osoitinta alas)

        Args:
            value: Tallennettava 16-bittinen arvo

        Raises:
            StackOverflowError: Jos SP menee MPR:n alle User-tilassa
        """
        self.memory.write(self.regs.sp, value)
        self.regs.sp = (self.regs.sp - 1) & WORD_MASK

        # Tarkista pinon ylivuoto User-tilassa
        if not self.regs.in_kernel_mode and self.regs.sp < self.regs.mpr:
            raise StackOverflowError("User stack overflow")

    def _pop(self) -> int:
        """
        Hae arvo pinosta.

        Pino pienenee ylospain (pop kasvattaa SP:ta):
        1. SP = SP + 1 (siirra osoitinta ylos)
        2. Palauta [SP] (lue arvo)

        Returns:
            16-bittinen arvo pinon huipulta
        """
        self.regs.sp = (self.regs.sp + 1) & WORD_MASK
        return self.memory.read(self.regs.sp)

    # ==========================================================================
    # REKISTERIEN KASITTELY
    # ==========================================================================

    def _get_reg(self, encoded: int) -> int:
        """
        Lue rekisterin arvo koodatun indeksin perusteella.

        Rekisterikoodaus (3 alinta bittia):
            0 = R0, 1 = R1, 2 = R2, 3 = R3, 4 = FP, 5 = SP

        Args:
            encoded: Koodattu rekisteri-indeksi

        Returns:
            Rekisterin 16-bittinen arvo

        Raises:
            InvalidOpcodeError: Jos indeksi on 6 tai 7 (varattu)
        """
        idx = encoded & REG_IDX_MASK  # Vain 3 alinta bittia
        if idx == 0:
            return self.regs.r0
        if idx == 1:
            return self.regs.r1
        if idx == 2:
            return self.regs.r2
        if idx == 3:
            return self.regs.r3
        if idx == 4:
            return self.regs.fp
        if idx == 5:
            return self.regs.sp
        raise InvalidOpcodeError(f"Invalid register index: {idx}")

    def _set_reg(self, encoded: int, value: int) -> None:
        """
        Aseta rekisterin arvo koodatun indeksin perusteella.

        Args:
            encoded: Koodattu rekisteri-indeksi (0-5)
            value: Asetettava arvo (maskataan 16-bittiseksi)

        Raises:
            InvalidOpcodeError: Jos indeksi on 6 tai 7 (varattu)
        """
        value &= WORD_MASK  # Varmista 16-bittisyys
        idx = encoded & REG_IDX_MASK
        if idx == 0:
            self.regs.r0 = value
        elif idx == 1:
            self.regs.r1 = value
        elif idx == 2:
            self.regs.r2 = value
        elif idx == 3:
            self.regs.r3 = value
        elif idx == 4:
            self.regs.fp = value
        elif idx == 5:
            self.regs.sp = value
        else:
            raise InvalidOpcodeError(f"Invalid register index: {idx}")
