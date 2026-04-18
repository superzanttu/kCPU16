"""Core execution loop and decode mixin for CPU."""

from __future__ import annotations

from ..constants import (
    INT_DIV_ZERO,
    INT_INVALID_OPCODE,
    INT_MEMORY_ACCESS_FAULT,
    INT_PRIVILEGE_VIOLATION,
    INT_STACK_OVERFLOW,
    RAND_LFSR_SEED,
    WORD_MASK,
)
from ..exceptions import (
    InvalidOpcodeError,
    MemoryAccessFaultError,
    PrivilegeViolationError,
    ReadOnlyMemoryError,
    StackOverflowError,
)
from ..instruction import (
    EXEC_CYCLES,
    OPCODE_NOPS_MASK,
    OPCODE_NOPS_SHIFT,
    OPCODE_TABLE,
    _op,
)


class _Ins:
    """Decoded instruction container optimized for hot-path use."""

    __slots__ = ("opcode", "operands", "size_words")

    def __init__(self, opcode: int, operands: tuple[int, ...], size_words: int) -> None:
        """Store decoded opcode, operands and encoded instruction size."""
        self.opcode = opcode
        self.operands = operands
        self.size_words = size_words


_OPCODE_JMPI: int = _op(0, 5, 9, 0)
_OPCODE_CALLI: int = _op(0, 5, 10, 0)
_OPCODE_FILL: int = _op(0, 1, 11, 3)
_OPCODE_COPY: int = _op(0, 1, 12, 3)
_RUN_STOP_CYCLES = "cycles"
_RUN_STOP_BREAKPOINT = "breakpoint"
_RUN_STOP_HALTED = "halted"
_RUN_STOP_EXITED = "exited"

# Sentinel-arvo: disabled-ajastimelle niin suuri, ettei se laukea koskaan.
_TMR_DISABLED: int = 0x7FFF_FFFF_FFFF_FFFF


class CPUCoreMixin:
    """Core methods: dispatch tables, step/run loop and decode."""

    def __post_init__(self) -> None:
        """Initialize dispatch/cache tables used by the hot execution path."""
        self._exec_table: dict[int, object] = {}
        self._mem_check_table: dict[int, object] = {}
        self._cycles_table: dict[int, int] = {}
        self._exec_list: list[object] = [None] * 1024
        self._mem_check_list: list[object] = [None] * 1024
        self._cycles_list: list[int] = [1] * 1024
        self._reg_array: list[int] = self.regs._regs
        self._build_dispatch_table()

    def _build_dispatch_table(self) -> None:
        """Build opcode-to-handler, memory-check and cycle lookup tables."""
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
            "COPY": self._exec_copy,
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
            "STATE": self._exec_state,
            "NOP": self._exec_nop,
        }
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
            "COPY": self._mcheck_copy,
        }
        for opcode, (mnemonic, _, _) in OPCODE_TABLE.items():
            if mnemonic in handler_map:
                self._exec_table[opcode] = handler_map[mnemonic]
                self._exec_list[opcode >> 6] = handler_map[mnemonic]
            if mnemonic in mem_check_map:
                self._mem_check_table[opcode] = mem_check_map[mnemonic]
                self._mem_check_list[opcode >> 6] = mem_check_map[mnemonic]
            cycles_val = EXEC_CYCLES.get(mnemonic, 1)
            self._cycles_table[opcode] = cycles_val
            self._cycles_list[opcode >> 6] = cycles_val

    def reset(self) -> None:
        """Reset CPU to initial state: clear registers, counters, and timers.

        Simulates a cold-boot: all registers to 0 except SP (stack pointer),
        clears instruction/execution counters, resets timers, and disables
        the halted flag. Does not clear memory or storage.
        """
        self.halted = False
        self.instruction_counter = 0
        self.process_exit_requested = False
        self._uptime_counter = 0
        self._lfsr = RAND_LFSR_SEED
        self._simulated_time_us = 0
        self._next_tmr_time_us = _TMR_DISABLED
        self._next_ctmr_time_us = _TMR_DISABLED
        self._recent_exec_trace.clear()
        self.regs.reset()
        self._clock_snapshot = None
        self._clock_snapshot_sim_us = -1

    def step(self) -> None:
        """Execute a single instruction and update CPU state.

        Fetch-decode-execute one instruction, update program counter,
        accumulate simulated execution time, and check for pending
        interrupts (keyboard, timer, clock). Handles exceptions by
        triggering appropriate interrupts or halting on recursive errors.
        If already halted, this is a no-op.
        """
        if self.halted:
            return

        try:
            ins = self._fetch_decode(self.regs.pc)

            if ins.opcode & 0x8000 and not self.regs.in_kernel_mode:
                mnemonic = OPCODE_TABLE.get(ins.opcode, ("?", 0, True))[0]
                raise PrivilegeViolationError(mnemonic)

            check_fn = self._mem_check_table.get(ins.opcode)
            if check_fn is not None:
                check_fn(ins)  # type: ignore[operator]

            # Tallenna juuri suoritettava käsky crash-jäljitettä varten.
            self._recent_exec_trace.append((pc & WORD_MASK, ins.opcode & WORD_MASK))

            exec_cycles = self._cycles_table.get(ins.opcode, 1)
            if ins.opcode in (_OPCODE_FILL, _OPCODE_COPY) and len(ins.operands) >= 2:
                start = self._get_reg(ins.operands[0]) & WORD_MASK
                end = self._get_reg(ins.operands[1]) & WORD_MASK
                exec_cycles += ((end - start) & WORD_MASK) + 1

            handler = self._exec_table.get(ins.opcode)
            if handler is None:
                raise InvalidOpcodeError(f"Unknown opcode: 0x{ins.opcode:04X}")
            handler(ins)  # type: ignore[operator]

            self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK

            self.instruction_counter += 1
            self._simulated_time_us += exec_cycles
            if self.regs.sr & 0x0010:
                self._handle_keyboard_interrupt_if_needed()
                if self._simulated_time_us >= self._next_tmr_time_us:
                    self._handle_timer_interrupt_if_needed()
                if self._simulated_time_us >= self._next_ctmr_time_us:
                    self._handle_clock_interrupt_if_needed()

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

    def run(self, max_cycles: int | None = None) -> None:
        """Run CPU at maximum speed until halt or breakpoint.

        Executes instructions in a tight loop without UI updates.
        Minimal overhead due to batching and direct table lookups.

        Args:
            max_cycles: Maximum instruction count before stopping (None = no limit).
                        Breakpoints defined elsewhere are respected.
        """
        self._run_core(max_cycles=max_cycles)

    def run_until_breakpoint_or_cycles(
        self, max_cycles: int, breakpoints: set[int] | None
    ) -> tuple[int, str]:
        """Run CPU until breakpoint hit, max cycles exceeded, or halt.

        Fast execution with cycle accounting and breakpoint checks.
        Returns tuple of (cycles_executed: int, stop_reason: str) where
        stop_reason is one of: "cycles", "breakpoint", "halted", "exited".

        Args:
            max_cycles: Maximum instruction count to execute.
            breakpoints: Set of memory addresses where to stop, or None.
        """
        if max_cycles <= 0:
            return 0, _RUN_STOP_CYCLES
        return self._run_core(max_cycles=max_cycles, breakpoints=breakpoints)

    def _run_core(
        self, max_cycles: int | None = None, breakpoints: set[int] | None = None
    ) -> tuple[int, str]:
        """Execute tight run loop with optional cycle limit and breakpoints."""
        regs = self.regs
        mem_words = self.memory.words
        exec_list = self._exec_list
        mem_check_list = self._mem_check_list
        cycles_list = self._cycles_list
        reg_array = self._reg_array
        word_mask = WORD_MASK
        nops_shift = OPCODE_NOPS_SHIFT
        nops_mask_val = OPCODE_NOPS_MASK
        opcode_jmpi = _OPCODE_JMPI
        opcode_calli = _OPCODE_CALLI
        opcode_fill = _OPCODE_FILL
        opcode_copy = _OPCODE_COPY
        opcode_table = OPCODE_TABLE
        sr_i_mask = 1 << 4
        bp_contains = breakpoints.__contains__ if breakpoints is not None else None

        cycles = 0
        while not self.halted and not self.process_exit_requested:
            if max_cycles is not None and cycles >= max_cycles:
                return cycles, _RUN_STOP_CYCLES

            try:
                pc = regs.pc
                opcode = mem_words[pc & word_mask]

                if opcode & 0x8000 and not regs.in_kernel_mode:
                    raise PrivilegeViolationError(
                        opcode_table.get(opcode, ("?", 0, True))[0]
                    )

                if opcode == opcode_jmpi or opcode == opcode_calli:
                    ins = self._fetch_decode(pc)
                else:
                    if opcode not in opcode_table:
                        raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")
                    nops = (opcode >> nops_shift) & nops_mask_val
                    if nops == 0:
                        operands: tuple[int, ...] = ()
                    elif nops == 1:
                        operands = (mem_words[(pc + 1) & word_mask],)
                    elif nops == 2:
                        operands = (
                            mem_words[(pc + 1) & word_mask],
                            mem_words[(pc + 2) & word_mask],
                        )
                    else:
                        operands = (
                            mem_words[(pc + 1) & word_mask],
                            mem_words[(pc + 2) & word_mask],
                            mem_words[(pc + 3) & word_mask],
                        )
                    ins = _Ins(opcode, operands, 1 + nops)

                check_fn = mem_check_list[opcode >> 6]
                if check_fn is not None:
                    check_fn(ins)

                exec_cycles = cycles_list[opcode >> 6]
                if opcode in (opcode_fill, opcode_copy) and len(ins.operands) >= 2:
                    start = reg_array[ins.operands[0]] & word_mask
                    end = reg_array[ins.operands[1]] & word_mask
                    exec_cycles += ((end - start) & word_mask) + 1

                handler = exec_list[opcode >> 6]
                if handler is None:
                    raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")

                # Tallenna juuri suoritettava käsky crash-jäljitettä varten.
                self._recent_exec_trace.append((pc & word_mask, opcode & word_mask))
                handler(ins)

                regs.pc = (regs.pc + ins.size_words) & word_mask

                self.instruction_counter += 1
                self._simulated_time_us += exec_cycles
                if regs.sr & sr_i_mask:
                    self._handle_keyboard_interrupt_if_needed()
                    sim_time = self._simulated_time_us
                    if sim_time >= self._next_tmr_time_us:
                        self._handle_timer_interrupt_if_needed()
                    if sim_time >= self._next_ctmr_time_us:
                        self._handle_clock_interrupt_if_needed()

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
            if self.halted:
                return cycles, _RUN_STOP_HALTED
            if self.process_exit_requested:
                return cycles, _RUN_STOP_EXITED
            if bp_contains is not None and bp_contains(regs.pc):
                return cycles, _RUN_STOP_BREAKPOINT

        if self.halted:
            return cycles, _RUN_STOP_HALTED
        if self.process_exit_requested:
            return cycles, _RUN_STOP_EXITED
        return cycles, _RUN_STOP_CYCLES

    def _fetch_decode(self, pc: int) -> _Ins:
        """Decode one instruction at PC into a compact internal tuple object."""
        opcode = self.memory.read(pc)

        if opcode not in OPCODE_TABLE:
            raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")

        if opcode == _OPCODE_JMPI or opcode == _OPCODE_CALLI:
            reg_id = self.memory.read(pc + 1)
            count = self.memory.read(pc + 2)
            targets = tuple(self.memory.read(pc + 3 + i) for i in range(count))
            return _Ins(
                opcode=opcode,
                operands=(reg_id, count, *targets),
                size_words=3 + count,
            )

        operand_count = (opcode >> OPCODE_NOPS_SHIFT) & OPCODE_NOPS_MASK
        operands = tuple(self.memory.read(pc + 1 + i) for i in range(operand_count))

        return _Ins(opcode=opcode, operands=operands, size_words=1 + operand_count)
