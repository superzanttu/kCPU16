"""Execution handler mixin for CPU opcode implementations."""

from __future__ import annotations

from ..constants import (
    CLOCK_INT_INTERVAL,
    CLOCK_MMIO_END,
    CLOCK_MMIO_START,
    GFX_FLIP_REG,
    INT_PROCESS_EXIT,
    KBD_MMIO_END,
    KBD_MMIO_START,
    MODE_KERNEL,
    RAND_MMIO,
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


_TMR_DISABLED_EXEC = 0x7FFFFFFFFFFFFFFF


class CPUEXecMixin:
    """Extracted opcode execution handlers used by CPU dispatch tables."""

    # --- Tiedonsiirtokaskyt ---

    def _exec_load(self, ins) -> None:
        reg_idx, value = ins.operands
        self._set_reg(reg_idx, value)

    def _exec_cpy(self, ins) -> None:
        dst, src = ins.operands
        self._set_reg(dst, self._get_reg(src))

    def _exec_read(self, ins) -> None:
        reg_idx, addr = ins.operands
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store(self, ins) -> None:
        reg_idx, addr = ins.operands
        self._write_word(addr, self._get_reg(reg_idx))

    def _exec_read_ind(self, ins) -> None:
        reg_idx, ptr_reg = ins.operands
        addr = self._get_reg(ptr_reg)
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store_ind(self, ins) -> None:
        ptr_reg, src_reg = ins.operands
        addr = self._get_reg(ptr_reg)
        self._write_word(addr, self._get_reg(src_reg))

    def _exec_read_rel(self, ins) -> None:
        reg_idx, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._set_reg(reg_idx, self._read_word(addr))

    def _exec_store_rel(self, ins) -> None:
        src_reg, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._write_word(addr, self._get_reg(src_reg))

    def _exec_storei(self, ins) -> None:
        imm, addr = ins.operands
        self._write_word(addr, imm & WORD_MASK)

    def _exec_storei_ind(self, ins) -> None:
        ptr_reg, value = ins.operands
        addr = self._get_reg(ptr_reg)
        self._write_word(addr, value)

    def _exec_storei_rel(self, ins) -> None:
        imm, offset = ins.operands
        addr = (self.regs.fp + offset) & WORD_MASK
        self._write_word(addr, imm & WORD_MASK)

    def _exec_fill(self, ins) -> None:
        reg_start, reg_end, reg_value = ins.operands
        start = self._get_reg(reg_start) & WORD_MASK
        end = self._get_reg(reg_end) & WORD_MASK
        val = self._get_reg(reg_value) & WORD_MASK
        ranges = self._iter_fill_ranges(start, end)

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
        start_reg, end_reg, dst_reg = ins.operands
        start = self._get_reg(start_reg) & WORD_MASK
        end = self._get_reg(end_reg) & WORD_MASK
        dst = self._get_reg(dst_reg) & WORD_MASK

        src_ranges = self._iter_fill_ranges(start, end)
        length = ((end - start) & WORD_MASK) + 1
        dst_ranges = self._iter_copy_dest_ranges(dst, length)

        src_has_mmio = False
        dst_has_mmio_side_effect = False
        for seg_start, seg_end in src_ranges:
            if seg_start <= CLOCK_MMIO_END and seg_end >= CLOCK_MMIO_START:
                src_has_mmio = True
                break
            if seg_start <= KBD_MMIO_END and seg_end >= KBD_MMIO_START:
                src_has_mmio = True
                break
            if seg_start <= RAND_MMIO <= seg_end:
                src_has_mmio = True
                break
        for seg_start, seg_end in dst_ranges:
            if seg_start <= CLOCK_INT_INTERVAL <= seg_end:
                dst_has_mmio_side_effect = True
                break
            if seg_start <= RAND_MMIO <= seg_end:
                dst_has_mmio_side_effect = True
                break
            if seg_start <= GFX_FLIP_REG <= seg_end:
                dst_has_mmio_side_effect = True
                break

        if not src_has_mmio and not dst_has_mmio_side_effect:
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
        dst, src = ins.operands
        a = self._get_reg(dst)
        b = self._get_reg(src)
        result = (a - b) & WORD_MASK
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_mul(self, ins) -> None:
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
        dst, src = ins.operands
        divisor = self._get_reg(src)
        if divisor == 0:
            raise ZeroDivisionError()
        result = self._get_reg(dst) // divisor
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)

    def _exec_cmp(self, ins) -> None:
        reg_a, reg_b = ins.operands
        a = self._get_reg(reg_a)
        b = self._get_reg(reg_b)
        result = (a - b) & WORD_MASK
        self.regs.set_zn_flags(result)
        overflow = bool(((a ^ b) & (a ^ result)) & WORD_SIGN_BIT)
        self.regs.set_carry_overflow(a < b, overflow)

    def _exec_adc(self, ins) -> None:
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
        dst, src = ins.operands
        result = self._get_reg(dst) & self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_or(self, ins) -> None:
        dst, src = ins.operands
        result = self._get_reg(dst) | self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_xor(self, ins) -> None:
        dst, src = ins.operands
        result = self._get_reg(dst) ^ self._get_reg(src)
        self._set_reg(dst, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_not(self, ins) -> None:
        (reg_idx,) = ins.operands
        result = (~self._get_reg(reg_idx)) & WORD_MASK
        self._set_reg(reg_idx, result)
        self.regs.set_zn_flags(result)
        self.regs.set_carry_overflow(False, False)

    def _exec_shl(self, ins) -> None:
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
        (reg_idx,) = ins.operands
        self._push(self._get_reg(reg_idx))

    def _exec_pop(self, ins) -> None:
        (reg_idx,) = ins.operands
        self._set_reg(reg_idx, self._pop())

    def _exec_swsp(self, ins) -> None:
        dst, src = ins.operands
        old_sp = self.regs.sp
        self.regs.sp = self._get_reg(src) & WORD_MASK
        self._set_reg(dst, old_sp)

    # --- Hyppykaskyt ---

    def _exec_jump(self, ins) -> None:
        (addr,) = ins.operands
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_call(self, ins) -> None:
        (addr,) = ins.operands
        self._push((self.regs.pc + ins.size_words) & WORD_MASK)
        self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_ret(self, ins) -> None:
        self.regs.pc = (self._pop() - ins.size_words) & WORD_MASK

    def _exec_jz(self, ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jnz(self, ins) -> None:
        (addr,) = ins.operands
        if not self.regs.get_flag(SR_FLAG_Z):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jlt(self, ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) != self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jgt(self, ins) -> None:
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 0 and n == v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jle(self, ins) -> None:
        (addr,) = ins.operands
        z = self.regs.get_flag(SR_FLAG_Z)
        n = self.regs.get_flag(SR_FLAG_N)
        v = self.regs.get_flag(SR_FLAG_V)
        if z == 1 or n != v:
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jge(self, ins) -> None:
        (addr,) = ins.operands
        if self.regs.get_flag(SR_FLAG_N) == self.regs.get_flag(SR_FLAG_V):
            self.regs.pc = (addr - ins.size_words) & WORD_MASK

    def _exec_jmpi(self, ins) -> None:
        reg_id = ins.operands[0]
        count = ins.operands[1]
        index = self._get_reg(reg_id)
        if index >= count:
            raise InvalidOpcodeError(
                f"JMPI: indeksi {index} sallitun alueen ulkopuolella (maara={count})"
            )
        self.regs.pc = (ins.operands[2 + index] - ins.size_words) & WORD_MASK

    def _exec_calli(self, ins) -> None:
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
        (int_no,) = ins.operands
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(int_no)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_iret(self, ins) -> None:
        old_sr = self._pop()
        old_pc = self._pop()
        self.regs.sr = old_sr & WORD_MASK
        self.regs.pc = (old_pc - ins.size_words) & WORD_MASK

    def _exec_sti(self, ins) -> None:
        self.regs.set_flag(SR_FLAG_I, 1)

    def _exec_cli(self, ins) -> None:
        self.regs.set_flag(SR_FLAG_I, 0)

    # --- Jarjestelmakaskyt ---

    def _exec_halt(self, ins) -> None:
        self.halted = True

    def _exec_exit(self, ins) -> None:
        self.process_exit_requested = True
        self.regs.pc = (self.regs.pc + ins.size_words) & WORD_MASK
        self._trigger_interrupt(INT_PROCESS_EXIT)
        self.regs.pc = (self.regs.pc - ins.size_words) & WORD_MASK

    def _exec_smpr(self, ins) -> None:
        (reg_idx,) = ins.operands
        self.regs.mpr = self._get_reg(reg_idx)

    def _exec_stmr(self, ins) -> None:
        (reg_idx,) = ins.operands
        new_tmr = self._get_reg(reg_idx)
        self.regs.tmr = new_tmr
        self._next_tmr_time_us = (
            _TMR_DISABLED_EXEC if new_tmr == 0 else self._simulated_time_us + new_tmr
        )

    def _exec_sctmr(self, ins) -> None:
        (reg_idx,) = ins.operands
        new_ctmr = self._get_reg(reg_idx)
        self.regs.ctmr = new_ctmr
        self._next_ctmr_time_us = (
            _TMR_DISABLED_EXEC
            if new_ctmr == 0
            else self._simulated_time_us + new_ctmr * 1000
        )

    def _exec_dread(self, ins) -> None:
        reg_dst, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self._set_reg(reg_dst, self.storage.read_word(self._get_reg(reg_addr)))

    def _exec_dwrite(self, ins) -> None:
        reg_src, reg_addr = ins.operands
        if self.storage is None:
            raise InvalidOpcodeError("Storage device not connected")
        self.storage.write_word(self._get_reg(reg_addr), self._get_reg(reg_src))

    def _exec_tsl(self, ins) -> None:
        reg_idx, addr = ins.operands
        old_value = self.memory.read(addr)
        self._set_reg(reg_idx, old_value)
        self.memory.write(addr, 1)
        self.regs.set_zn_flags(old_value)

    def _exec_nop(self, ins) -> None:
        pass
