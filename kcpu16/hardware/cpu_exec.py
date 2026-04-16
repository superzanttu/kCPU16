"""Execution handler mixin for CPU opcode implementations."""

from __future__ import annotations

from ..constants import (
    INT_PROCESS_EXIT,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_V,
    SR_FLAG_Z,
    VRAM_END,
    VRAM_START,
    WORD_BITS,
    WORD_MASK,
    WORD_SIGN_BIT,
)
from ..exceptions import InvalidOpcodeError
from ..instruction import STATE_ID_MASK


_TMR_DISABLED_EXEC = 0x7FFFFFFFFFFFFFFF


class CPUEXecMixin:
    """Extracted opcode execution handlers used by CPU dispatch tables."""

    # --- Tiedonsiirtokaskyt ---

    def _exec_load(self, ins) -> None:
        """Execute LOAD: write immediate value to destination register."""
        reg_idx, value = ins.operands
        self._set_reg(reg_idx, value)

    def _exec_cpy(self, ins) -> None:
        """Execute CPY: copy register value into destination register."""
        dst, src = ins.operands
        self._set_reg(dst, self._get_reg(src))

    def _exec_read(self, ins) -> None:
        """Execute READ direct: load memory word at absolute address to register."""
        reg_idx, addr = ins.operands
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store(self, ins) -> None:
        """Execute STORE direct: write register value to absolute memory address."""
        reg_idx, addr = ins.operands
        self._write_word(addr, self._get_reg(reg_idx))

    def _exec_read_ind(self, ins) -> None:
        """Execute READ indirect: address comes from pointer register."""
        reg_idx, ptr_reg = ins.operands
        addr = self._get_reg(ptr_reg)
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store_ind(self, ins) -> None:
        """Execute STORE indirect: destination address comes from pointer register."""
        ptr_reg, src_reg = ins.operands
        addr = self._get_reg(ptr_reg)
        self._write_word(addr, self._get_reg(src_reg))

    def _exec_read_rel(self, ins) -> None:
        """Execute READ relative: load from FP+offset into register."""
        reg_idx, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store_rel(self, ins) -> None:
        """Execute STORE relative: write register to FP+offset."""
        src_reg, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._write_word(addr, self._get_reg(src_reg))

    def _exec_storei(self, ins) -> None:
        """Execute STOREI direct: write immediate value to absolute address."""
        imm, addr = ins.operands
        self._write_word(addr, imm & WORD_MASK)

    def _exec_storei_ind(self, ins) -> None:
        """Execute STOREI indirect: write immediate value to pointer address."""
        ptr_reg, value = ins.operands
        addr = self._get_reg(ptr_reg)
        self._write_word(addr, value)

    def _exec_storei_rel(self, ins) -> None:
        """Execute STOREI relative: write immediate value to FP+offset."""
        imm, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._write_word(addr, imm & WORD_MASK)

    def _exec_fill(self, ins) -> None:
        """Execute FILL: write one register value across start..end range."""
        reg_start, reg_end, reg_value = ins.operands
        start = self._get_reg(reg_start) & WORD_MASK
        end = self._get_reg(reg_end) & WORD_MASK
        val = self._get_reg(reg_value) & WORD_MASK
        ranges = self._iter_fill_ranges(start, end)

        if not self.memory.ranges_overlap_mmio(ranges):
            words = self.memory.words
            for seg_start, seg_end in ranges:
                words[seg_start : seg_end + 1] = [val] * (seg_end - seg_start + 1)
            if self.screen is not None:
                for seg_start, seg_end in ranges:
                    ov_start = max(seg_start, VRAM_START)
                    ov_end = min(seg_end, VRAM_END)
                    if ov_start <= ov_end:
                        self.screen.mark_vram_dirty(ov_start)
                        self.screen.mark_vram_dirty(ov_end)
            return

        write_word = self._write_word
        for seg_start, seg_end in ranges:
            addr = seg_start
            while True:
                write_word(addr, val)
                if addr == seg_end:
                    break
                addr = (addr + 1) & WORD_MASK

    def _exec_copy(self, ins) -> None:
        """Execute COPY: copy source range [start..end] to destination range."""
        start_reg, end_reg, dst_reg = ins.operands
        start = self._get_reg(start_reg) & WORD_MASK
        end = self._get_reg(end_reg) & WORD_MASK
        dst = self._get_reg(dst_reg) & WORD_MASK

        src_ranges = self._iter_fill_ranges(start, end)
        length = ((end - start) & WORD_MASK) + 1
        dst_ranges = self._iter_copy_dest_ranges(dst, length)

        src_has_mmio = self.memory.ranges_overlap_mmio(src_ranges)
        dst_has_mmio = self.memory.ranges_overlap_mmio(dst_ranges)

        if not src_has_mmio and not dst_has_mmio:
            words = self.memory.words
            src_data: list[int] = []
            for seg_start, seg_end in src_ranges:
                src_data.extend(words[seg_start : seg_end + 1])

            idx = 0
            for seg_start, seg_end in dst_ranges:
                seg_len = seg_end - seg_start + 1
                words[seg_start : seg_end + 1] = src_data[idx : idx + seg_len]
                idx += seg_len

            if self.screen is not None:
                for seg_start, seg_end in dst_ranges:
                    ov_start = max(seg_start, VRAM_START)
                    ov_end = min(seg_end, VRAM_END)
                    if ov_start <= ov_end:
                        self.screen.mark_vram_dirty(ov_start)
                        self.screen.mark_vram_dirty(ov_end)
            return

        read_word = self._read_word
        write_word = self._write_word
        src_addr = start
        dst_addr = dst
        remaining = length
        while remaining > 0:
            write_word(dst_addr, read_word(src_addr))
            src_addr = (src_addr + 1) & WORD_MASK
            dst_addr = (dst_addr + 1) & WORD_MASK
            remaining -= 1

    # --- Aritmeettiset kaskyt ---

    def _exec_add(self, ins) -> None:
        """Execute ADD and update Z/N/C/V flags."""
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = a + b
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        masked = result & WORD_MASK
        overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(result > WORD_MASK, overflow)

    def _exec_sub(self, ins) -> None:
        """Execute SUB and update Z/N/C/V flags."""
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = (a - b) & WORD_MASK
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_mul(self, ins) -> None:
        """Execute MUL and update Z/N/C/V flags."""
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = a * b
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        masked = result & WORD_MASK
        overflow = bool(((a ^ masked) & (b ^ masked)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(result > WORD_MASK, overflow)

    def _exec_div(self, ins) -> None:
        """Execute DIV and raise ZeroDivisionError on divisor 0."""
        dst, src = ins.operands
        divisor = self._get_reg(src)
        if divisor == 0:
            raise ZeroDivisionError()
        result = self._get_reg(dst) // divisor
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)

    def _exec_cmp(self, ins) -> None:
        """Execute CMP by computing A-B and updating flags without storing result."""
        reg_a, reg_b = ins.operands
        a = self._get_reg(reg_a)
        b = self._get_reg(reg_b)
        result = (a - b) & WORD_MASK
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_adc(self, ins) -> None:
        """Execute ADC (add with carry) and update flags."""
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

    # --- Logiikkakaskyt ---

    def _exec_and(self, ins) -> None:
        """Execute bitwise AND and update Z/N flags."""
        dst, src = ins.operands
        result = self._get_reg(dst) & self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_or(self, ins) -> None:
        """Execute bitwise OR and update Z/N flags."""
        dst, src = ins.operands
        result = self._get_reg(dst) | self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_xor(self, ins) -> None:
        """Execute bitwise XOR and update Z/N flags."""
        dst, src = ins.operands
        result = self._get_reg(dst) ^ self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_not(self, ins) -> None:
        """Execute bitwise NOT and update Z/N flags."""
        (reg_idx,) = ins.operands
        result = (~self._get_reg(reg_idx)) & WORD_MASK
        self._set_reg(reg_idx, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_shl(self, ins) -> None:
        """Execute logical left shift and update carry/ZN flags."""
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

    def _exec_shr(self, ins) -> None:
        """Execute logical right shift and update carry/ZN flags."""
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

    # --- Pinokaskyt ---

    def _exec_push(self, ins) -> None:
        """Execute PUSH: push register value onto stack."""
        (reg_idx,) = ins.operands
        self._push(self._get_reg(reg_idx))

    def _exec_pop(self, ins) -> None:
        """Execute POP: pop top-of-stack into destination register."""
        (reg_idx,) = ins.operands
        self._set_reg(reg_idx, self._pop())

    def _exec_swsp(self, ins) -> None:
        """Execute SWSP: swap-like move between SP and register."""
        dst, src = ins.operands
        old_sp = self.regs.sp
        self.regs.sp = self._get_reg(src) & WORD_MASK
        self._set_reg(dst, old_sp)

    # --- Hyppykaskyt ---

    def _exec_jump(self, ins) -> None:
        """Execute unconditional absolute jump."""
        (addr,) = ins.operands
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_call(self, ins) -> None:
        """Execute CALL: push return address and jump to target."""
        (addr,) = ins.operands
        self._push((self.regs.pc + ins.size_words) & WORD_MASK)
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_ret(self, ins) -> None:
        """Execute RET: restore return address from stack."""
        self.regs.pc = (self._pop() - ins.size_words) & WORD_MASK

    def _exec_jz(self, ins) -> None:
        """Execute JZ: jump when zero flag is set."""
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jnz(self, ins) -> None:
        """Execute JNZ: jump when zero flag is clear."""
        (addr,) = ins.operands
        if not self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jlt(self, ins) -> None:
        """Execute JLT: signed less-than condition jump."""
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) != self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jgt(self, ins) -> None:
        """Execute JGT: signed greater-than condition jump."""
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 0 and n == v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jle(self, ins) -> None:
        """Execute JLE: signed less-than-or-equal condition jump."""
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 1 or n != v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jge(self, ins) -> None:
        """Execute JGE: signed greater-than-or-equal condition jump."""
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) == self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jmpi(self, ins) -> None:
        """Execute JMPI jump table branch selected by register index."""
        reg_id = ins.operands[0]
        count = ins.operands[1]
        index = self._get_reg(reg_id)
        if index >= count:
            raise InvalidOpcodeError(
                f"JMPI: indeksi {index} sallitun alueen ulkopuolella (maara={count})"
            )
        self.regs.pc = (ins.operands[2 + index] - ins.size_words) & WORD_MASK

    def _exec_calli(self, ins) -> None:
        """Execute CALLI jump table call selected by register index."""
        reg_id = ins.operands[0]
        count = ins.operands[1]
        index = self._get_reg(reg_id)
        if index >= count:
            raise InvalidOpcodeError(
                f"CALLI: indeksi {index} sallitun alueen ulkopuolella (maara={count})"
            )
        self._push((self.regs.pc + ins.size_words) & WORD_MASK)
        self.regs.pc = (ins.operands[2 + index] - ins.size_words) & WORD_MASK

    # --- Keskeytykset ---

    def _exec_int(self, ins) -> None:
        """Execute INT software interrupt with explicit interrupt number."""
        (int_no,) = ins.operands
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(int_no)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_iret(self, ins) -> None:
        """Execute IRET by restoring SR and PC from kernel stack."""
        old_sr = self._pop()
        old_pc = self._pop()
        self.regs.sr = old_sr & WORD_MASK
        self.regs.pc = (old_pc - ins.size_words) & WORD_MASK

    def _exec_sti(self, ins) -> None:
        """Execute STI: enable interrupt handling bit in SR."""
        self.regs.set_flag(SR_FLAG_I, 1)

    def _exec_cli(self, ins) -> None:
        """Execute CLI: disable interrupt handling bit in SR."""
        self.regs.set_flag(SR_FLAG_I, 0)

    # --- Jarjestelmakaskyt ---

    def _exec_halt(self, ins) -> None:
        """Execute HALT by marking CPU halted."""
        self.halted = True

    def _exec_exit(self, ins) -> None:
        """Execute EXIT and trigger process-exit interrupt."""
        self.process_exit_requested = True
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(INT_PROCESS_EXIT)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_smpr(self, ins) -> None:
        """Execute SMPR: set memory protection register from source register."""
        (reg_idx,) = ins.operands
        self.regs.mpr = self._get_reg(reg_idx)

    def _exec_stmr(self, ins) -> None:
        """Execute STMR: set timer interval and next timer deadline."""
        (reg_idx,) = ins.operands
        new_tmr = self._get_reg(reg_idx)
        self.regs.tmr = new_tmr
        self._next_tmr_time_us = (
            _TMR_DISABLED_EXEC if new_tmr == 0 else self._simulated_time_us + new_tmr
        )

    def _exec_sctmr(self, ins) -> None:
        """Execute SCTMR: set clock-timer interval and next deadline."""
        (reg_idx,) = ins.operands
        new_ctmr = self._get_reg(reg_idx)
        self.regs.ctmr = new_ctmr
        self._next_ctmr_time_us = (
            _TMR_DISABLED_EXEC
            if new_ctmr == 0
            else self._simulated_time_us + new_ctmr * 1000
        )

    def _exec_dread(self, ins) -> None:
        """Execute DREAD from storage device address register to destination register."""
        reg_dst, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self._set_reg(reg_dst, self.storage.read_word(self._get_reg(reg_addr)))

    def _exec_dwrite(self, ins) -> None:
        """Execute DWRITE from source register to storage device address."""
        reg_src, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self.storage.write_word(self._get_reg(reg_addr), self._get_reg(reg_src))

    def _exec_tsl(self, ins) -> None:
        """Execute TSL (test-and-set lock) and update Z/N from old value."""
        reg_idx, addr = ins.operands
        old_value = self.memory.read(addr)
        self._set_reg(reg_idx, old_value)
        self.memory.write(addr, 1)
        self.regs.set_zn_flags(old_value)

    def _exec_state(self, ins) -> None:
        """Emit one-word state signal (id 0..15) to optional UI callback."""
        state_id = ins.opcode & STATE_ID_MASK
        cb = getattr(self, "state_callback", None)
        if callable(cb):
            cb(state_id)

    def _exec_nop(self, ins) -> None:
        """Execute NOP with no side effects."""
        pass
