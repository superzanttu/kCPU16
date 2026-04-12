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

from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING

from ..constants import (
    BOOT_RAM_END,
    BOOT_RAM_START,
    CLOCK_DAY,
    CLOCK_HOUR,
    CLOCK_INT_INTERVAL,
    CLOCK_MILLIS,
    CLOCK_MINUTE,
    CLOCK_MMIO_END,
    CLOCK_MMIO_START,
    CLOCK_MONTH,
    CLOCK_SECOND,
    CLOCK_YEAR,
    GFX_FLIP_REG,
    INT_CLOCK,
    INT_DIV_ZERO,
    INT_INVALID_OPCODE,
    INT_KEYBOARD,
    INT_MEMORY_ACCESS_FAULT,
    INT_PROCESS_EXIT,
    INT_PRIVILEGE_VIOLATION,
    INT_STACK_OVERFLOW,
    INT_TIMER,
    INT_VECTOR_COUNT,
    INT_VECTOR_BASE,
    KBD_DATA,
    KBD_MMIO_END,
    KBD_MMIO_START,
    KBD_STATUS,
    MEMORY_WORDS,
    RAND_MMIO,
    VRAM_END,
    VRAM_START,
    RAND_LFSR_MASK,
    RAND_LFSR_SEED,
    REG_IDX_MASK,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    MODE_KERNEL,
    UPTIME_W0,
    UPTIME_W1,
    UPTIME_W2,
    UPTIME_W3,
    WORD_BITS,
    WORD_MASK,
    WORD_SIGN_BIT,
)
from ..exceptions import (
    InvalidOpcodeError,
    MemoryAccessFaultError,
    PrivilegeViolationError,
    ReadOnlyMemoryError,
    StackOverflowError,
)
from ..instruction import (
    OPCODE_TABLE,
    OPCODE_NOPS_SHIFT,
    OPCODE_NOPS_MASK,
    EXEC_CYCLES,
    _op,
)
from .memory import Memory


# ---------------------------------------------------------------------------
# Kevyt käskyn sisäinen esitysrakenne — korvaa DecodedInstruction-dataclass.
# __slots__ poistaa __dict__-allokaation per käsky hot loopissa.
# ---------------------------------------------------------------------------


class _Ins:
    """Dekoodattu käsky — __slots__-rakenne käskyjen esittämiseen suorituspolulla."""

    __slots__ = ("opcode", "operands", "size_words")

    def __init__(self, opcode: int, operands: list, size_words: int) -> None:
        self.opcode = opcode
        self.operands = operands
        self.size_words = size_words


# Vakio-opcodet erityislogiikkaa varten (lasketaan kerran moduulin latautuessa)
_OPCODE_JMPI: int = _op(0, 5, 9, 0)  # Indeksoitu hyppy (muuttuvanmittainen)
_OPCODE_CALLI: int = _op(0, 5, 10, 0)  # Indeksoitu kutsu (muuttuvanmittainen)
_OPCODE_FILL: int = _op(0, 1, 11, 3)  # Täyttökäsky (dynaaminen syklilasku)

# Sentinel-arvo: disabled ajastimelle niin suuri, että se ei koskaan laukea
_TMR_DISABLED: int = 0x7FFF_FFFF_FFFF_FFFF
from .registers import RegisterFile

# TYPE_CHECKING-lohko estaa syklisen importin ajonaikana
if TYPE_CHECKING:
    from .devices.storage import BlockStorageDevice
    from .devices.keyboard import KeyboardDevice
    from .devices.screen import ScreenDevice


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
    screen: "ScreenDevice | None" = None  # Nayttolaite (valinnainen)

    halted: bool = False  # Onko kone pysahtynyt (HALT)?
    instruction_counter: int = 0  # Suoritettujen kaskyjen maara
    process_exit_requested: bool = False  # Onko EXIT kutsuttu?

    # Valinnainen hook: kutsutaan atomisesti kun CPU kirjoittaa GFX_FLIP_REG:iin
    # (arvo != 0). Machine asettaa tämän renderoimaan VRAMin etupuskuriin
    # juuri sillä hetkellä kun kehys on valmis — ennen kuin gfx_clear tyhjentää sen.
    flip_callback: object = field(default=None, init=False, repr=False)

    _uptime_counter: int = field(default=0, init=False)

    # Simuloitu suoritusaika mikrosekunteina (kertyy käskyjen suoritussykleistä)
    _simulated_time_us: int = field(default=0, init=False)
    # Seuraava simuloitu aika (µs) jolloin TMR-keskeytys laukeaa
    # (_TMR_DISABLED = ajastin poissa päältä, ei koskaan laukea)
    _next_tmr_time_us: int = field(default=_TMR_DISABLED, init=False)
    # Seuraava simuloitu aika (µs) jolloin CTMR-keskeytys laukeaa
    _next_ctmr_time_us: int = field(default=_TMR_DISABLED, init=False)

    # 16-bittinen Galois LFSR satunnaislukugeneraattorille ($0022)
    _lfsr: int = field(default=RAND_LFSR_SEED, init=False)

    def __post_init__(self) -> None:
        """Rakenna opcode-pohjaiset käsittelytaulukot CPU:n alustuksen jälkeen."""
        # Suoritustaulukko: opcode → handler-metodi
        self._exec_table: dict[int, object] = {}
        # Muistitarkistustaulukko: opcode → check-metodi (tai None)
        self._mem_check_table: dict[int, object] = {}
        # Sykliarvotaulukko: opcode → perus-exec-cycles
        self._cycles_table: dict[int, int] = {}
        # Suora viite RegisterFile:n sisäiseen rekisterilistaan (r0-r15, fp, sp)
        # Sama lista kuin regs._regs — ei kopiota, ei synkronointia tarvita.
        self._reg_array: list[int] = self.regs._regs
        self._build_dispatch_table()

    def _build_dispatch_table(self) -> None:
        """Täytä _exec_table, _mem_check_table ja _cycles_table OPCODE_TABLE:sta."""
        handler_map = {
            "LOAD": self._exec_load,
            "CPY": self._exec_cpy,
            "READ": self._exec_read,
            "STORE": self._exec_store,
            "READ_IND": self._exec_read_ind,
            "STORE_IND": self._exec_store_ind,
            "READ_REL": self._exec_read_rel,
            "STORE_REL": self._exec_store_rel,
            "STOREI": self._exec_storei,
            "STOREI_IND": self._exec_storei_ind,
            "STOREI_REL": self._exec_storei_rel,
            "FILL": self._exec_fill,
            "ADD": self._exec_add,
            "SUB": self._exec_sub,
            "MUL": self._exec_mul,
            "DIV": self._exec_div,
            "CMP": self._exec_cmp,
            "ADC": self._exec_adc,
            "AND": self._exec_and,
            "OR": self._exec_or,
            "XOR": self._exec_xor,
            "NOT": self._exec_not,
            "SHL": self._exec_shl,
            "SHR": self._exec_shr,
            "PUSH": self._exec_push,
            "POP": self._exec_pop,
            "SWSP": self._exec_swsp,
            "JUMP": self._exec_jump,
            "CALL": self._exec_call,
            "RET": self._exec_ret,
            "JZ": self._exec_jz,
            "JNZ": self._exec_jnz,
            "JLT": self._exec_jlt,
            "JGT": self._exec_jgt,
            "JLE": self._exec_jle,
            "JGE": self._exec_jge,
            "JMPI": self._exec_jmpi,
            "CALLI": self._exec_calli,
            "INT": self._exec_int,
            "IRET": self._exec_iret,
            "STI": self._exec_sti,
            "CLI": self._exec_cli,
            "HALT": self._exec_halt,
            "EXIT": self._exec_exit,
            "SMPR": self._exec_smpr,
            "STMR": self._exec_stmr,
            "SCTMR": self._exec_sctmr,
            "DREAD": self._exec_dread,
            "DWRITE": self._exec_dwrite,
            "TSL": self._exec_tsl,
            "NOP": self._exec_nop,
        }
        # Muistitarkistustaulukko: opcode → check-metodi
        mem_check_map = {
            "READ": self._mcheck_direct,
            "STORE": self._mcheck_direct,
            "STOREI": self._mcheck_direct,
            "TSL": self._mcheck_direct,
            "READ_IND": self._mcheck_ind_src,
            "STORE_IND": self._mcheck_ind_dst,
            "STOREI_IND": self._mcheck_ind_dst,
            "READ_REL": self._mcheck_rel_src,
            "STORE_REL": self._mcheck_rel_dst,
            "STOREI_REL": self._mcheck_rel_dst,
            "FILL": self._mcheck_fill,
        }
        for opcode, (mnemonic, _, _) in OPCODE_TABLE.items():
            if mnemonic in handler_map:
                self._exec_table[opcode] = handler_map[mnemonic]
            if mnemonic in mem_check_map:
                self._mem_check_table[opcode] = mem_check_map[mnemonic]
            self._cycles_table[opcode] = EXEC_CYCLES.get(mnemonic, 1)

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
        self._uptime_counter = 0
        self._lfsr = RAND_LFSR_SEED
        self._simulated_time_us = 0
        self._next_tmr_time_us = _TMR_DISABLED
        self._next_ctmr_time_us = _TMR_DISABLED
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
            ins = self._fetch_decode(self.regs.pc)

            # ------------------------------------------------------------------
            # VAIHE 2: PRIVILEGE CHECK
            # Tarkista opcode-bitin 15 perusteella onko käsky privileged
            # ------------------------------------------------------------------
            if ins.opcode & 0x8000 and not self.regs.in_kernel_mode:
                mnemonic = OPCODE_TABLE.get(ins.opcode, ("?", 0, True))[0]
                raise PrivilegeViolationError(mnemonic)

            # ------------------------------------------------------------------
            # VAIHE 3: MEMORY CHECK
            # Tarkista muistiviittaukset taulukosta haetulla tarkistajalla
            # ------------------------------------------------------------------
            check_fn = self._mem_check_table.get(ins.opcode)
            if check_fn is not None:
                check_fn(ins)  # type: ignore[operator]

            # ------------------------------------------------------------------
            # VAIHE 4: EXECUTE
            # Suorita käsky opcode-taulukosta haetulla käsittelijällä
            # ------------------------------------------------------------------
            exec_cycles = self._cycles_table.get(ins.opcode, 1)
            if ins.opcode == _OPCODE_FILL and len(ins.operands) >= 2:
                start = self._get_reg(ins.operands[0]) & WORD_MASK
                end = self._get_reg(ins.operands[1]) & WORD_MASK
                exec_cycles += ((end - start) & WORD_MASK) + 1

            handler = self._exec_table.get(ins.opcode)
            if handler is None:
                raise InvalidOpcodeError(f"Unknown opcode: 0x{ins.opcode:04X}")
            handler(ins)  # type: ignore[operator]

            # ------------------------------------------------------------------
            # VAIHE 5: PC UPDATE
            # Siirra ohjealaskuri seuraavaan kaskyyn (paitsi jos hypattiin)
            # ------------------------------------------------------------------
            self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK

            # Paivita laskurit ja tarkista keskeytykset
            self.instruction_counter += 1
            self._simulated_time_us += exec_cycles
            self._handle_keyboard_interrupt_if_needed()
            if self._simulated_time_us >= self._next_tmr_time_us:
                self._handle_timer_interrupt_if_needed()
            if self._simulated_time_us >= self._next_ctmr_time_us:
                self._handle_clock_interrupt_if_needed()

        # ----------------------------------------------------------------------
        # VIRHEENKASITTELY: Muunna poikkeukset keskeytyksiksi
        # Jos keskeytyksen laukaisu epäonnistuu (esim. pino törmäsi MMIO:hon),
        # pysäytä CPU ja anna poikkeuksen nousta TUI:lle kaatumisraporttia varten.
        # ----------------------------------------------------------------------
        except PrivilegeViolationError:
            # User yritti ajaa Kernel-kaskya -> INT 4
            try:
                self._trigger_interrupt(INT_PRIVILEGE_VIOLATION)
            except Exception:
                self.halted = True
                raise
        except MemoryAccessFaultError:
            # User yritti lukea/kirjoittaa suojattua muistia -> INT 5
            try:
                self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
            except Exception:
                self.halted = True
                raise
        except ReadOnlyMemoryError:
            # Kirjoitus kirjoitussuojattuun osoitteeseen (MMIO/ROM) -> INT 5
            try:
                self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
            except Exception:
                self.halted = True
                raise
        except InvalidOpcodeError:
            # Tuntematon opcode -> INT 1
            try:
                self._trigger_interrupt(INT_INVALID_OPCODE)
            except Exception:
                self.halted = True
                raise
        except ZeroDivisionError:
            # DIV-kaskyn jakaja oli 0 -> INT 0
            try:
                self._trigger_interrupt(INT_DIV_ZERO)
            except Exception:
                self.halted = True
                raise
        except StackOverflowError:
            # Pino meni MPR:n alle (tai kirjoitussuojattuun alueeseen) -> INT 2
            try:
                self._trigger_interrupt(INT_STACK_OVERFLOW)
            except Exception:
                self.halted = True
                raise

    def run(self, max_cycles: int | None = None) -> None:
        """
        Suorita kaskyjä kunnes pysaytysehto tayttyy.

        Optimoitu fast-path: paikalliset viittaukset usein kaytettyihin
        tietorakenteisiin, inlinattu fetch/decode yleiselle tapaukselle ja
        poikkeuspolku erotettuna normaalista suorituspolusta. Tallentaminen
        paikallisiin muuttujiin vahentaa Python LOAD_ATTR -kutsujen maaraa
        hot loopissa (LOAD_FAST on nopeampi kuin LOAD_ATTR).

        Pysaytysehdot:
        1. HALT-kasky suoritettu (halted = True)
        2. EXIT-kasky suoritettu (process_exit_requested = True)
        3. max_cycles-raja saavutettu (jos annettu)

        Args:
            max_cycles: Maksimi suoritettavien kaskyjen maara.
                        None (oletus) = ei rajaa, aja kunnes HALT tai EXIT.

        Note:
            step()-metodi sailytetaan debuggausta ja yksittaista askellusta varten.
        """
        # --- Paikalliset viittaukset hot-loop-muuttujiin ---
        # Python LOAD_FAST (lokaalit) on nopeampi kuin LOAD_ATTR (self.xxx).
        regs = self.regs
        mem_words = self.memory.words  # Suora lista — ei method call per muistiluku
        exec_table = self._exec_table
        mem_check_table = self._mem_check_table
        cycles_table = self._cycles_table
        reg_array = self._reg_array
        word_mask = WORD_MASK  # Vakio lokaalina (ei module-tason lookup)
        nops_shift = OPCODE_NOPS_SHIFT
        nops_mask_val = OPCODE_NOPS_MASK
        opcode_jmpi = _OPCODE_JMPI
        opcode_calli = _OPCODE_CALLI
        opcode_fill = _OPCODE_FILL
        opcode_table = OPCODE_TABLE

        cycles = 0
        while not self.halted and not self.process_exit_requested:
            if max_cycles is not None and cycles >= max_cycles:
                break

            # ---- NORMAALI SUORITUSPOLKU (fast path) ----
            try:
                # FETCH: suora lista-indeksointi, ei method call
                pc = regs.pc
                opcode = mem_words[pc & word_mask]

                # PRIVILEGE CHECK
                if opcode & 0x8000 and not regs.in_kernel_mode:
                    raise PrivilegeViolationError(
                        opcode_table.get(opcode, ("?", 0, True))[0]
                    )

                # DECODE: inlinattu fast path yleisille kaskyille;
                # JMPI/CALLI ovat muuttuvamittaisia ja kaytetaan hidasta polkua.
                if opcode == opcode_jmpi or opcode == opcode_calli:
                    ins = self._fetch_decode(pc)
                else:
                    if opcode not in opcode_table:
                        raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")
                    nops = (opcode >> nops_shift) & nops_mask_val
                    if nops == 0:
                        operands: list[int] = []
                    elif nops == 1:
                        operands = [mem_words[(pc + 1) & word_mask]]
                    elif nops == 2:
                        operands = [
                            mem_words[(pc + 1) & word_mask],
                            mem_words[(pc + 2) & word_mask],
                        ]
                    else:  # nops == 3
                        operands = [
                            mem_words[(pc + 1) & word_mask],
                            mem_words[(pc + 2) & word_mask],
                            mem_words[(pc + 3) & word_mask],
                        ]
                    ins = _Ins(opcode, operands, 1 + nops)

                # MEMORY CHECK
                check_fn = mem_check_table.get(opcode)
                if check_fn is not None:
                    check_fn(ins)

                # EXECUTE
                exec_cycles = cycles_table.get(opcode, 1)
                if opcode == opcode_fill and len(ins.operands) >= 2:
                    start = reg_array[ins.operands[0]] & word_mask
                    end = reg_array[ins.operands[1]] & word_mask
                    exec_cycles += ((end - start) & word_mask) + 1

                handler = exec_table.get(opcode)
                if handler is None:
                    raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")
                handler(ins)

                # PC UPDATE
                regs.pc = (regs.pc + ins.size_words) & word_mask

                # LASKURIT JA KESKEYTYKSET
                self.instruction_counter += 1
                self._simulated_time_us += exec_cycles
                self._handle_keyboard_interrupt_if_needed()
                sim_time = self._simulated_time_us
                if sim_time >= self._next_tmr_time_us:
                    self._handle_timer_interrupt_if_needed()
                if sim_time >= self._next_ctmr_time_us:
                    self._handle_clock_interrupt_if_needed()

            # ---- POIKKEUSPOLKU (erotettu normaalista suorituksesta) ----
            except PrivilegeViolationError:
                try:
                    self._trigger_interrupt(INT_PRIVILEGE_VIOLATION)
                except Exception:
                    self.halted = True
                    raise
            except MemoryAccessFaultError:
                try:
                    self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
                except Exception:
                    self.halted = True
                    raise
            except ReadOnlyMemoryError:
                try:
                    self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
                except Exception:
                    self.halted = True
                    raise
            except InvalidOpcodeError:
                try:
                    self._trigger_interrupt(INT_INVALID_OPCODE)
                except Exception:
                    self.halted = True
                    raise
            except ZeroDivisionError:
                try:
                    self._trigger_interrupt(INT_DIV_ZERO)
                except Exception:
                    self.halted = True
                    raise
            except StackOverflowError:
                try:
                    self._trigger_interrupt(INT_STACK_OVERFLOW)
                except Exception:
                    self.halted = True
                    raise

            cycles += 1

    # ==========================================================================
    # SISAISET METODIT: FETCH, DECODE, MUISTITARKISTUKSET, KÄSITTELIJÄT
    # ==========================================================================

    def _fetch_decode(self, pc: int) -> _Ins:
        """
        Hae kasky muistista ja dekoodaa se kevyeksi _Ins-olioksi.

        Lukee opcoden PC:n osoitteesta ja mahdolliset lisaoperandit
        seuraavista osoitteista.

        Args:
            pc: Ohjelmalaskurin osoite (mista kasky luetaan)

        Returns:
            _Ins-olio kaskymetatietoineen

        Raises:
            InvalidOpcodeError: Jos opcode ei ole taulukossa
        """
        # Lue opcode-sana
        opcode = self.memory.read(pc)

        # Validoi opcode
        if opcode not in OPCODE_TABLE:
            raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")

        mnemonic = OPCODE_TABLE[opcode][0]

        # Erityistapaus: JMPI/CALLI — muuttuvanmittainen indeksoitu hyppy/kutsu
        # Rakenne muistissa: opcode | reg_id | count | addr[0] | ... | addr[count-1]
        if opcode == _OPCODE_JMPI or opcode == _OPCODE_CALLI:
            reg_id = self.memory.read(pc + 1)
            count = self.memory.read(pc + 2)
            targets = [self.memory.read(pc + 3 + i) for i in range(count)]
            return _Ins(
                opcode=opcode,
                operands=[reg_id, count] + targets,
                size_words=3 + count,
            )

        # Johda operandien maara suoraan opcode-biteista (OPS-kentta bits 7:6)
        operand_count = (opcode >> OPCODE_NOPS_SHIFT) & OPCODE_NOPS_MASK

        # Lue operandit perakkaisista muistiosoitteista
        operands: list[int] = [
            self.memory.read(pc + 1 + i) for i in range(operand_count)
        ]

        return _Ins(
            opcode=opcode,
            operands=operands,
            size_words=1 + operand_count,
        )

    # ==========================================================================
    # MUISTITARKISTUSMETODIT (yhdistetty handler-metadataan, Task 3)
    # Kukin metodi tarkistaa yhden käskytyypin muistiviittauksen.
    # Privilege-tarkistus tehdään step():ssä opcode-bitin perusteella.
    # ==========================================================================

    def _mcheck_direct(self, ins: _Ins) -> None:
        """READ, STORE, STOREI, TSL — operands[1] on muistiosoite."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(ins.operands[1], self.regs.mpr)

    def _mcheck_ind_src(self, ins: _Ins) -> None:
        """READ_IND — osoite tulee _get_reg(operands[1]):stä."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(self._get_reg(ins.operands[1]), self.regs.mpr)

    def _mcheck_ind_dst(self, ins: _Ins) -> None:
        """STORE_IND, STOREI_IND — osoite tulee _get_reg(operands[0]):sta."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(self._get_reg(ins.operands[0]), self.regs.mpr)

    def _mcheck_rel_src(self, ins: _Ins) -> None:
        """READ_REL — osoite = FP + operands[1]."""
        if not self.regs.in_kernel_mode:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

    def _mcheck_rel_dst(self, ins: _Ins) -> None:
        """STORE_REL, STOREI_REL — osoite = FP + operands[1]."""
        if not self.regs.in_kernel_mode:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

    @staticmethod
    def _iter_fill_ranges(start: int, end: int) -> tuple[tuple[int, int], ...]:
        """Palauta FILL-alue 1-2 lineaarisena [start,end]-jaksona (sis. rajat)."""
        if start <= end:
            return ((start, end),)
        return ((start, WORD_MASK), (0, end))

    def _mcheck_fill(self, ins: _Ins) -> None:
        """FILL — kirjoitussuojaustarkistus aina; käyttäjäalueen tarkistus user-tilassa."""
        start = self._get_reg(ins.operands[0]) & WORD_MASK
        end = self._get_reg(ins.operands[1]) & WORD_MASK
        ranges = self._iter_fill_ranges(start, end)

        # Fast path: tarkista koko alue bytearray-maskista. Jos osuma löytyy,
        # palaa tarkkaan tarkistukseen virheviestin oikeaa osoitetta varten.
        write_mask = self.memory._write_mask
        for seg_start, seg_end in ranges:
            if any(write_mask[seg_start : seg_end + 1]):
                addr = seg_start
                while True:
                    self.memory.check_write_protected(addr)
                    if addr == seg_end:
                        break
                    addr = (addr + 1) & WORD_MASK

        if not self.regs.in_kernel_mode:
            mpr = self.regs.mpr & WORD_MASK
            for seg_start, seg_end in ranges:
                # Koko segmentti VRAMissa -> aina sallittu.
                if VRAM_START <= seg_start and seg_end <= VRAM_END:
                    continue
                # Koko segmentti MPR-rajan yläpuolella -> sallittu.
                if seg_start >= mpr:
                    continue
                # Segmentissä on ainakin yksi osoite MPR:n alapuolella.
                self.memory.check_user_access(seg_start, mpr)

    # ==========================================================================
    # KÄSITTELYMETODIT: yksi metodi per käsky (opcode-handler-taulukko)
    # Kukin metodi suorittaa tasan yhden käskyn logiikan.
    # Kutsutaan step():stä self._exec_table[opcode](ins)-taulukolla.
    # ==========================================================================

    # --- Tiedonsiirtokäskyt ---

    def _exec_load(self, ins: _Ins) -> None:
        reg_idx, imm = ins.operands
        self._set_reg(reg_idx, imm)

    def _exec_cpy(self, ins: _Ins) -> None:
        dst, src = ins.operands
        self._set_reg(dst, self._get_reg(src))

    def _exec_read(self, ins: _Ins) -> None:
        reg_idx, addr = ins.operands
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store(self, ins: _Ins) -> None:
        reg_idx, addr = ins.operands
        self._write_word(addr, self._get_reg(reg_idx))

    def _exec_read_ind(self, ins: _Ins) -> None:
        # regD = [regS]
        reg_dst, reg_addr = ins.operands
        self._set_reg(reg_dst, self._read_word(self._get_reg(reg_addr)))

    def _exec_store_ind(self, ins: _Ins) -> None:
        # [regD] = regS
        reg_addr, reg_src = ins.operands
        self._write_word(self._get_reg(reg_addr), self._get_reg(reg_src))

    def _exec_read_rel(self, ins: _Ins) -> None:
        # reg = [FP + imm]
        reg_idx, offset = ins.operands
        self._set_reg(reg_idx, self._read_word((self.regs.fp + offset) & WORD_MASK))

    def _exec_store_rel(self, ins: _Ins) -> None:
        # [FP + imm] = reg
        reg_idx, offset = ins.operands
        self._write_word((self.regs.fp + offset) & WORD_MASK, self._get_reg(reg_idx))

    def _exec_storei(self, ins: _Ins) -> None:
        # [addr] = imm
        imm, addr = ins.operands
        self._write_word(addr, imm & WORD_MASK)

    def _exec_storei_ind(self, ins: _Ins) -> None:
        # [regD] = imm
        reg_addr, imm = ins.operands
        self._write_word(self._get_reg(reg_addr), imm & WORD_MASK)

    def _exec_storei_rel(self, ins: _Ins) -> None:
        # [FP + offset] = imm
        imm, offset = ins.operands
        self._write_word((self.regs.fp + offset) & WORD_MASK, imm & WORD_MASK)

    def _exec_fill(self, ins: _Ins) -> None:
        # Täytä muistialue [regStart..regEnd] arvolla regVal
        start_reg, end_reg, val_reg = ins.operands
        start = self._get_reg(start_reg) & WORD_MASK
        end = self._get_reg(end_reg) & WORD_MASK
        val = self._get_reg(val_reg) & WORD_MASK
        ranges = self._iter_fill_ranges(start, end)

        # Nopea aluekirjoituspolku: käytä suoraa listaviipaletta kun alue ei
        # sisällä kirjoitettavia MMIO-erikoisosoitteita, joilla on sivuvaikutuksia.
        has_mmio_side_effect = False
        for seg_start, seg_end in ranges:
            if seg_start <= CLOCK_INT_INTERVAL <= seg_end:
                has_mmio_side_effect = True
                break
            if seg_start <= RAND_MMIO <= seg_end:
                has_mmio_side_effect = True
                break
            if seg_start <= GFX_FLIP_REG <= seg_end:
                has_mmio_side_effect = True
                break

        if not has_mmio_side_effect:
            words = self.memory.words
            for seg_start, seg_end in ranges:
                words[seg_start : seg_end + 1] = [val] * (seg_end - seg_start + 1)
            return

        write_word = self._write_word
        for seg_start, seg_end in ranges:
            addr = seg_start
            while True:
                write_word(addr, val)
                if addr == seg_end:
                    break
                addr = (addr + 1) & WORD_MASK

    # --- Aritmeettiset käskyt ---

    def _exec_add(self, ins: _Ins) -> None:
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = a + b
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        masked = result & WORD_MASK
        overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(result > WORD_MASK, overflow)

    def _exec_sub(self, ins: _Ins) -> None:
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = (a - b) & WORD_MASK
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_mul(self, ins: _Ins) -> None:
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = a * b
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        masked = result & WORD_MASK
        overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(result > WORD_MASK, overflow)

    def _exec_div(self, ins: _Ins) -> None:
        dst, src = ins.operands
        divisor = self._get_reg(src)
        if divisor == 0:
            raise ZeroDivisionError()
        result = self._get_reg(dst) // divisor
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)

    def _exec_cmp(self, ins: _Ins) -> None:
        reg_a, reg_b = ins.operands
        a = self._get_reg(reg_a)
        b = self._get_reg(reg_b)
        result = (a - b) & WORD_MASK
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_adc(self, ins: _Ins) -> None:
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

    # --- Logiikkakäskyt ---

    def _exec_and(self, ins: _Ins) -> None:
        dst, src = ins.operands
        result = self._get_reg(dst) & self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_or(self, ins: _Ins) -> None:
        dst, src = ins.operands
        result = self._get_reg(dst) | self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_xor(self, ins: _Ins) -> None:
        dst, src = ins.operands
        result = self._get_reg(dst) ^ self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_not(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        result = (~self._get_reg(reg_idx)) & WORD_MASK
        self._set_reg(reg_idx, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_shl(self, ins: _Ins) -> None:
        dst, src = ins.operands
        a = self._get_reg(dst)
        shift = self._get_reg(src) & WORD_MASK
        if shift == 0:
            result, carry = a, False
        elif shift > WORD_BITS:
            result, carry = 0, False
        else:
            carry = bool((a >> (WORD_BITS - shift)) & 1)
            result = (a << shift) & WORD_MASK
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(carry, False)

    def _exec_shr(self, ins: _Ins) -> None:
        dst, src = ins.operands
        a = self._get_reg(dst)
        shift = self._get_reg(src) & WORD_MASK
        if shift == 0:
            result, carry = a, False
        elif shift > WORD_BITS:
            result, carry = 0, False
        else:
            carry = bool((a >> (shift - 1)) & 1)
            result = (a >> shift) & WORD_MASK
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(carry, False)

    # --- Pinokäskyt ---

    def _exec_push(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        self._push(self._get_reg(reg_idx))

    def _exec_pop(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        self._set_reg(reg_idx, self._pop())

    def _exec_swsp(self, ins: _Ins) -> None:
        dst, src = ins.operands
        old_sp = self.regs.sp
        self.regs.sp = self._get_reg(src) & WORD_MASK
        self._set_reg(dst, old_sp)

    # --- Hyppykäskyt ---

    def _exec_jump(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_call(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        self._push((self.regs.pc + ins.size_words) & WORD_MASK)
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_ret(self, ins: _Ins) -> None:
        self.regs.pc = (self._pop() - ins.size_words) & WORD_MASK

    def _exec_jz(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jnz(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        if not self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jlt(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) != self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jgt(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 0 and n == v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jle(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 1 or n != v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jge(self, ins: _Ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) == self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jmpi(self, ins: _Ins) -> None:
        reg_id, count, *targets = ins.operands
        index = self._get_reg(reg_id)
        if index >= count:
            raise InvalidOpcodeError(
                f"JMPI: indeksi {index} sallitun alueen ulkopuolella (määrä={count})"
            )
        self.regs.pc = (targets[index] - ins.size_words) & WORD_MASK

    def _exec_calli(self, ins: _Ins) -> None:
        reg_id, count, *targets = ins.operands
        index = self._get_reg(reg_id)
        if index >= count:
            raise InvalidOpcodeError(
                f"CALLI: indeksi {index} sallitun alueen ulkopuolella (määrä={count})"
            )
        self._push((self.regs.pc + ins.size_words) & WORD_MASK)
        self.regs.pc = (targets[index] - ins.size_words) & WORD_MASK

    # --- Keskeytykset ---

    def _exec_int(self, ins: _Ins) -> None:
        (int_no,) = ins.operands
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(int_no)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_iret(self, ins: _Ins) -> None:
        old_sr = self._pop()
        old_pc = self._pop()
        self.regs.sr = old_sr & WORD_MASK
        self.regs.pc = (old_pc - ins.size_words) & WORD_MASK

    def _exec_sti(self, ins: _Ins) -> None:
        self.regs.set_flag(SR_FLAG_I, 1)

    def _exec_cli(self, ins: _Ins) -> None:
        self.regs.set_flag(SR_FLAG_I, 0)

    # --- Järjestelmäkäskyt ---

    def _exec_halt(self, ins: _Ins) -> None:
        self.halted = True

    def _exec_exit(self, ins: _Ins) -> None:
        self.process_exit_requested = True
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(INT_PROCESS_EXIT)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_smpr(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        self.regs.mpr = self._get_reg(reg_idx)

    def _exec_stmr(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        new_tmr = self._get_reg(reg_idx)
        self.regs.tmr = new_tmr
        self._next_tmr_time_us = (
            _TMR_DISABLED if new_tmr == 0 else self._simulated_time_us + new_tmr
        )

    def _exec_sctmr(self, ins: _Ins) -> None:
        (reg_idx,) = ins.operands
        new_ctmr = self._get_reg(reg_idx)
        self.regs.ctmr = new_ctmr
        self._next_ctmr_time_us = (
            _TMR_DISABLED
            if new_ctmr == 0
            else self._simulated_time_us + new_ctmr * 1000
        )

    def _exec_dread(self, ins: _Ins) -> None:
        reg_dst, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self._set_reg(reg_dst, self.storage.read_word(self._get_reg(reg_addr)))

    def _exec_dwrite(self, ins: _Ins) -> None:
        reg_src, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self.storage.write_word(self._get_reg(reg_addr), self._get_reg(reg_src))

    def _exec_tsl(self, ins: _Ins) -> None:
        reg_idx, addr = ins.operands
        old_value = self.memory.read(addr)
        self._set_reg(reg_idx, old_value)
        self.memory.write(addr, 1)
        self.regs.set_zn_flags(old_value)

    def _exec_nop(self, ins: _Ins) -> None:
        pass

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
        - Simuloitu aika on saavuttanut seuraavan laukaisuhetken
        """
        # TMR = 0 tarkoittaa etta ajastin on pois paalta
        if self.regs.tmr == 0:
            return

        # Keskeytykset on estettava ->  ei laukaista
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return

        # Laukaise kun simuloitu aika on ylittanyt seuraavan laukaisuhetken
        if self._simulated_time_us >= self._next_tmr_time_us:
            # Etene tarkasti TMR µs eteenpain (ei ajaudu hyvalla)
            self._next_tmr_time_us += self.regs.tmr
            self._trigger_interrupt(INT_TIMER)

    def _update_uptime_if_needed(self) -> None:
        """Paivita 32-bittinen sekuntilaskuri simuloidun ajan perusteella."""
        self._uptime_counter = (self._simulated_time_us // 1_000_000) & 0xFFFFFFFF

    def _handle_keyboard_interrupt_if_needed(self) -> None:
        """
        Tarkista ja laukaise nappaimistokeskeytys tarvittaessa.

        Nappaimistokeskeytys (INT 6) laukeaa kun:
        - Nappaimistolaitteella on odottava keskeytys (take_interrupt() == True)
        - I = 1 (keskeytykset ovat sallitut)

        Keskeytysrutiini lukee tapahtuman KBD_DATA ($0020) MMIO-osoitteesta.
        """
        if self.keyboard is None:
            return
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return
        if self.keyboard.take_interrupt():
            self._trigger_interrupt(INT_KEYBOARD)

    def _handle_clock_interrupt_if_needed(self) -> None:
        """Laukaise kellokeskeytys (INT 9) jos CTMR > 0 ja simuloitu aika on saavutettu.

        Kellokeskeytys laukeaa kun:
        - CTMR > 0 (ms-ajastin paalla)
        - I = 1 (keskeytykset sallittu)
        - Simuloitu aika on saavuttanut seuraavan laukaisuhetken
        """
        if self.regs.ctmr == 0:
            return
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return
        if self._simulated_time_us >= self._next_ctmr_time_us:
            # Etene tarkasti CTMR ms eteenpain (ei ajaudu hyvan)
            self._next_ctmr_time_us += self.regs.ctmr * 1000
            self._trigger_interrupt(INT_CLOCK)

    # ==========================================================================
    # MMIO-APUMETODIT: lue/kirjoita sana joka osaa hakea kellorekisterit
    # ==========================================================================

    def _read_word(self, addr: int) -> int:
        """Lue sana muistista; palauttaa MMIO-arvon jos osoite on kellolohkossa tai nappaimistolohkossa."""
        addr &= WORD_MASK
        if CLOCK_MMIO_START <= addr <= CLOCK_MMIO_END:
            return self._read_clock_mmio(addr)
        if KBD_MMIO_START <= addr <= KBD_MMIO_END:
            return self._read_kbd_mmio(addr)
        if addr == RAND_MMIO:
            # Galois LFSR: jos alin bitti on 1, shift right ja XOR maskilla
            lsb = self._lfsr & 1
            self._lfsr = (self._lfsr >> 1) ^ ((-lsb) & RAND_LFSR_MASK)
            return self._lfsr
        return self.memory.read(addr)

    def _write_word(self, addr: int, value: int) -> None:
        """Kirjoita sana muistiin; CLOCK_INT_INTERVAL-kirjoitus asettaa CTMR:n."""
        addr &= WORD_MASK
        value &= WORD_MASK
        if addr == CLOCK_INT_INTERVAL:
            self.regs.ctmr = value
            self._next_ctmr_time_us = (
                _TMR_DISABLED if value == 0 else self._simulated_time_us + value * 1000
            )
            return
        # Muut kellolohkon osoitteet ovat vain luettavia — ohita hiljainen kirjoitus
        if CLOCK_MMIO_START <= addr <= CLOCK_MMIO_END:
            return
        # Nappaimisto-MMIO on vain luettava — ohita hiljainen kirjoitus
        if KBD_MMIO_START <= addr <= KBD_MMIO_END:
            return
        # Satunnaislukugeneraattori: kirjoitus asettaa LFSR-siemenen (0 -> 1)
        if addr == RAND_MMIO:
            self._lfsr = value if value != 0 else 1
            return
        # GFX_FLIP_REG (0xFF81): kirjoitus value!=0 laukaisee kaksoisbufferoinnin flipin.
        # Kutsuu flip_callback:in välittömästi (ennen kuin CPU jatkaa ja tyhjentää VRAMin),
        # jolloin callback renderoi täysin piirretyn kehyksen etupuskuriin atomisesti.
        # Rekisteria ei kirjoiteta muistiin — se on puhdas MMIO-osoite.
        if addr == GFX_FLIP_REG:
            if value != 0 and self.flip_callback is not None:
                self.flip_callback()  # type: ignore[operator]
            return
        self.memory.write(addr, value)
        # Merkitse VRAM muuttuneeksi dirty-flag-optimointia varten (TUI:n näyttöpäivitys)
        if VRAM_START <= addr <= VRAM_END and self.screen is not None:
            self.screen.mark_vram_dirty()

    def _read_clock_mmio(self, addr: int) -> int:
        """Palauttaa reaaliaikaisen kellonarvon MMIO-osoitteen mukaan."""
        now = datetime.now()
        if addr == CLOCK_YEAR:
            return now.year & WORD_MASK
        if addr == CLOCK_MONTH:
            return now.month
        if addr == CLOCK_DAY:
            return now.day
        if addr == CLOCK_HOUR:
            return now.hour
        if addr == CLOCK_MINUTE:
            return now.minute
        if addr == CLOCK_SECOND:
            return now.second
        if addr == CLOCK_MILLIS:
            return now.microsecond // 1000
        # Uptime-laskuri: paivita ensin
        self._update_uptime_if_needed()
        if addr == UPTIME_W3:
            return 0  # 32-bit uptime: upper 32 bits always 0
        if addr == UPTIME_W2:
            return 0  # 32-bit uptime: upper 32 bits always 0
        if addr == UPTIME_W1:
            return (self._uptime_counter >> 16) & WORD_MASK
        if addr == UPTIME_W0:
            return self._uptime_counter & WORD_MASK
        if addr == CLOCK_INT_INTERVAL:
            return self.regs.ctmr & WORD_MASK
        return 0  # varattu osoite

    def _read_kbd_mmio(self, addr: int) -> int:
        """
        Lue nappaimisto-MMIO-rekisteri.

        KBD_DATA ($0020):   Pops ja palauttaa seuraavan nappaintapahtuman puskurista.
                            Bitti 7 = 0: painallus, bitti 7 = 1: vapautus.
                            Bitit 6-0: nappainkoodi.
                            Palauttaa 0 jos puskuri on tyhja.
        KBD_STATUS ($0021): Palauttaa puskurissa olevien tapahtumien maaran.
                            0 = tyhja.

        Args:
            addr: MMIO-osoite (KBD_DATA tai KBD_STATUS)

        Returns:
            MMIO-rekisterin arvo
        """
        if self.keyboard is None:
            return 0
        if addr == KBD_DATA:
            return self.keyboard.read_data()
        if addr == KBD_STATUS:
            return self.keyboard.read_status()
        return 0  # varattu osoite

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
        try:
            self.memory.write(self.regs.sp, value)
        except ReadOnlyMemoryError:
            raise StackOverflowError(
                f"Pino törmäsi kirjoitussuojattuun osoitteeseen SP=0x{self.regs.sp:04X}"
            )
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

        Rekisterikoodaus (5 alinta bittia):
            0-15 = R0-R15, 16 = FP, 17 = SP

        Args:
            encoded: Koodattu rekisteri-indeksi

        Returns:
            Rekisterin 16-bittinen arvo

        Raises:
            InvalidOpcodeError: Jos indeksi on 18-31 (varattu)
        """
        idx = encoded & REG_IDX_MASK
        if idx < 18:
            return self._reg_array[idx]
        raise InvalidOpcodeError(f"Invalid register index: {idx}")

    def _set_reg(self, encoded: int, value: int) -> None:
        """
        Aseta rekisterin arvo koodatun indeksin perusteella.

        Args:
            encoded: Koodattu rekisteri-indeksi (0-17)
            value: Asetettava arvo (maskataan 16-bittiseksi)

        Raises:
            InvalidOpcodeError: Jos indeksi on 18-31 (varattu)
        """
        idx = encoded & REG_IDX_MASK
        if idx < 18:
            self._reg_array[idx] = value & WORD_MASK
            return
        raise InvalidOpcodeError(f"Invalid register index: {idx}")
