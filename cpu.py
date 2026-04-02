"""CPU core skeleton implementing kCPU16 execution cycle ordering."""

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
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_V,
    SR_FLAG_Z,
    MODE_KERNEL,
    WORD_MASK,
)
from .exceptions import (
    InvalidOpcodeError,
    MemoryAccessFaultError,
    PrivilegeViolationError,
    StackOverflowError,
)
from .instruction import DecodedInstruction, OPCODE_TABLE
from .memory import Memory
from .registers import RegisterFile

if TYPE_CHECKING:
    from .devices.storage import BlockStorageDevice


@dataclass
class CPU:
    memory: Memory
    regs: RegisterFile
    storage: "BlockStorageDevice | None" = None

    halted: bool = False
    instruction_counter: int = 0
    process_exit_requested: bool = False

    def reset(self) -> None:
        self.halted = False
        self.instruction_counter = 0
        self.process_exit_requested = False
        self.regs.reset()

    def step(self) -> None:
        """One Fetch-Decode-Execute cycle with required checks in order."""
        if self.halted:
            return

        try:
            # 1) Fetch
            decoded = self._fetch_decode(self.regs.pc)

            # 2) Privilege Check
            self._check_privilege(decoded)

            # 3) Memory Check
            self._check_memory_access(decoded)

            # 4) Execute
            self._execute(decoded)

            # 5) PC Update
            self.regs.pc = (self.regs.pc + decoded.size_words) & WORD_MASK

            self.instruction_counter += 1
            self._handle_timer_interrupt_if_needed()
        except PrivilegeViolationError:
            self._trigger_interrupt(INT_PRIVILEGE_VIOLATION)
        except MemoryAccessFaultError:
            self._trigger_interrupt(INT_MEMORY_ACCESS_FAULT)
        except InvalidOpcodeError:
            self._trigger_interrupt(INT_INVALID_OPCODE)
        except ZeroDivisionError:
            self._trigger_interrupt(INT_DIV_ZERO)
        except StackOverflowError:
            self._trigger_interrupt(INT_STACK_OVERFLOW)

    def run(self, max_cycles: int = 1_000_000) -> None:
        cycles = 0
        while (
            not self.halted and not self.process_exit_requested and cycles < max_cycles
        ):
            self.step()
            cycles += 1

    def _fetch_decode(self, pc: int) -> DecodedInstruction:
        opcode = self.memory.read(pc)
        if opcode not in OPCODE_TABLE:
            raise InvalidOpcodeError(f"Unknown opcode: 0x{opcode:04X}")

        mnemonic, operand_count, privileged = OPCODE_TABLE[opcode]
        operands: list[int] = []
        for i in range(operand_count):
            operands.append(self.memory.read(pc + 1 + i))

        return DecodedInstruction(
            mnemonic=mnemonic,
            operands=operands,
            size_words=1 + operand_count,
            privileged=privileged,
        )

    def _check_privilege(self, ins: DecodedInstruction) -> None:
        if ins.privileged and not self.regs.in_kernel_mode:
            raise PrivilegeViolationError(ins.mnemonic)

    def _check_memory_access(self, ins: DecodedInstruction) -> None:
        if self.regs.in_kernel_mode:
            return

        if ins.mnemonic in {"READ", "STORE"} and len(ins.operands) >= 2:
            addr = ins.operands[1]
            self.memory.check_user_access(addr, self.regs.mpr)
        elif ins.mnemonic == "READ_IND" and len(ins.operands) >= 2:
            addr = self._get_reg(ins.operands[1])
            self.memory.check_user_access(addr, self.regs.mpr)
        elif ins.mnemonic == "STORE_IND" and len(ins.operands) >= 2:
            addr = self._get_reg(ins.operands[0])
            self.memory.check_user_access(addr, self.regs.mpr)

    def _execute(self, ins: DecodedInstruction) -> None:
        # This skeleton intentionally executes a minimal subset.
        if ins.mnemonic == "LOAD":
            reg_idx, imm = ins.operands
            self._set_reg(reg_idx, imm)
        elif ins.mnemonic == "CPY":
            dst, src = ins.operands
            self._set_reg(dst, self._get_reg(src))
        elif ins.mnemonic == "READ":
            reg_idx, addr = ins.operands
            self._set_reg(reg_idx, self.memory.read(addr))
        elif ins.mnemonic == "STORE":
            reg_idx, addr = ins.operands
            self.memory.write(addr, self._get_reg(reg_idx))
        elif ins.mnemonic == "READ_IND":
            reg_dst, reg_addr = ins.operands
            self._set_reg(reg_dst, self.memory.read(self._get_reg(reg_addr)))
        elif ins.mnemonic == "STORE_IND":
            reg_addr, reg_src = ins.operands
            self.memory.write(self._get_reg(reg_addr), self._get_reg(reg_src))
        elif ins.mnemonic == "ADD":
            dst, src = ins.operands
            result = self._get_reg(dst) + self._get_reg(src)
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(result > WORD_MASK, False)
        elif ins.mnemonic == "MUL":
            dst, src = ins.operands
            result = self._get_reg(dst) * self._get_reg(src)
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(result > WORD_MASK, False)
        elif ins.mnemonic == "SUB":
            dst, src = ins.operands
            a = self._get_reg(dst)
            b = self._get_reg(src)
            result = (a - b) & WORD_MASK
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(a < b, False)
        elif ins.mnemonic == "DIV":
            dst, src = ins.operands
            divisor = self._get_reg(src)
            if divisor == 0:
                raise ZeroDivisionError()
            result = self._get_reg(dst) // divisor
            self._set_reg(dst, result)
            self.regs.set_zn_flags(result)
        elif ins.mnemonic == "PUSH":
            (reg_idx,) = ins.operands
            self._push(self._get_reg(reg_idx))
        elif ins.mnemonic == "POP":
            (reg_idx,) = ins.operands
            self._set_reg(reg_idx, self._pop())
        elif ins.mnemonic == "JUMP":
            (addr,) = ins.operands
            self.regs.pc = (addr - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "CALL":
            (addr,) = ins.operands
            self._push((self.regs.pc + ins.size_words) & WORD_MASK)
            self.regs.pc = (addr - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "RET":
            self.regs.pc = (self._pop() - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "INT":
            (int_no,) = ins.operands
            self._trigger_interrupt(int_no)
        elif ins.mnemonic == "IRET":
            old_sr = self._pop()
            old_pc = self._pop()
            self.regs.sr = old_sr & WORD_MASK
            self.regs.pc = (old_pc - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "STI":
            self.regs.set_flag(SR_FLAG_I, 1)
        elif ins.mnemonic == "CLI":
            self.regs.set_flag(SR_FLAG_I, 0)
        elif ins.mnemonic == "HALT":
            self.halted = True
        elif ins.mnemonic == "EXIT":
            self.process_exit_requested = True
            self._trigger_interrupt(INT_PROCESS_EXIT)
        elif ins.mnemonic == "SMPR":
            (reg_idx,) = ins.operands
            self.regs.mpr = self._get_reg(reg_idx)
        elif ins.mnemonic == "CMP":
            reg_a, reg_b = ins.operands
            a = self._get_reg(reg_a)
            b = self._get_reg(reg_b)
            result = (a - b) & WORD_MASK
            self.regs.set_zn_flags(result)
            self.regs.set_carry_overflow(a < b, False)
        elif ins.mnemonic == "JZ":
            (addr,) = ins.operands
            if self.regs.get_flag(SR_FLAG_Z):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "JNZ":
            (addr,) = ins.operands
            if not self.regs.get_flag(SR_FLAG_Z):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "JLT":
            (addr,) = ins.operands
            if self.regs.get_flag(SR_FLAG_N) != self.regs.get_flag(SR_FLAG_V):
                self.regs.pc = (addr - ins.size_words) & WORD_MASK
        elif ins.mnemonic == "STMR":
            (reg_idx,) = ins.operands
            self.regs.tmr = self._get_reg(reg_idx)
        elif ins.mnemonic == "DREAD":
            reg_dst, reg_addr = ins.operands
            if self.storage is None:
                raise InvalidOpcodeError("Storage device not connected")
            storage_addr = self._get_reg(reg_addr)
            self._set_reg(reg_dst, self.storage.read_word(storage_addr))
        elif ins.mnemonic == "DWRITE":
            reg_src, reg_addr = ins.operands
            if self.storage is None:
                raise InvalidOpcodeError("Storage device not connected")
            storage_addr = self._get_reg(reg_addr)
            self.storage.write_word(storage_addr, self._get_reg(reg_src))
        else:
            raise InvalidOpcodeError(ins.mnemonic)

    def _trigger_interrupt(self, int_no: int) -> None:
        int_no &= 0xFFFF
        vector_addr = (INT_VECTOR_BASE + (int_no % INT_VECTOR_COUNT)) & WORD_MASK

        self._push(self.regs.pc)
        self._push(self.regs.sr)

        self.regs.set_flag(5, MODE_KERNEL)
        self.regs.set_flag(SR_FLAG_I, 0)

        self.regs.pc = self.memory.read(vector_addr)

    def _handle_timer_interrupt_if_needed(self) -> None:
        if self.regs.tmr == 0:
            return
        if self.regs.get_flag(SR_FLAG_I) == 0:
            return
        if (
            self.instruction_counter > 0
            and (self.instruction_counter % self.regs.tmr) == 0
        ):
            self._trigger_interrupt(INT_TIMER)

    def _push(self, value: int) -> None:
        self.memory.write(self.regs.sp, value)
        self.regs.sp = (self.regs.sp - 1) & WORD_MASK
        if not self.regs.in_kernel_mode and self.regs.sp < self.regs.mpr:
            raise StackOverflowError("User stack overflow")

    def _pop(self) -> int:
        self.regs.sp = (self.regs.sp + 1) & WORD_MASK
        return self.memory.read(self.regs.sp)

    def _get_reg(self, encoded: int) -> int:
        idx = encoded & 0x7
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
        value &= WORD_MASK
        idx = encoded & 0x7
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
