"""Memory access check mixin for CPU instruction handlers."""

from __future__ import annotations

from ..constants import VRAM_END, VRAM_START, WORD_MASK


class CPUMemCheckMixin:
    """Extracted memory check handlers used by CPU dispatch tables."""

    def _mcheck_direct(self, ins) -> None:
        """READ, STORE, STOREI, TSL - operands[1] is a direct memory address."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(ins.operands[1], self.regs.mpr)

    def _mcheck_ind_src(self, ins) -> None:
        """READ_IND - source address comes from register operand[1]."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(self._get_reg(ins.operands[1]), self.regs.mpr)

    def _mcheck_ind_dst(self, ins) -> None:
        """STORE_IND, STOREI_IND - destination address comes from register operand[0]."""
        if not self.regs.in_kernel_mode:
            self.memory.check_user_access(self._get_reg(ins.operands[0]), self.regs.mpr)

    def _mcheck_rel_src(self, ins) -> None:
        """READ_REL - source address is FP + offset operand[1]."""
        if not self.regs.in_kernel_mode:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

    def _mcheck_rel_dst(self, ins) -> None:
        """STORE_REL, STOREI_REL - destination address is FP + offset operand[1]."""
        if not self.regs.in_kernel_mode:
            addr = (self.regs.fp + ins.operands[1]) & WORD_MASK
            self.memory.check_user_access(addr, self.regs.mpr)

    def _mcheck_fill(self, ins) -> None:
        """FILL - destination range must be writable and user-accessible."""
        start = self._get_reg(ins.operands[0]) & WORD_MASK
        end = self._get_reg(ins.operands[1]) & WORD_MASK
        ranges = self._iter_fill_ranges(start, end)

        write_mask = self.memory._write_mask
        for seg_start, seg_end in ranges:
            hit = write_mask.find(1, seg_start, seg_end + 1)
            while hit != -1:
                self.memory.check_write_protected(hit)
                hit = write_mask.find(1, hit + 1, seg_end + 1)

        if not self.regs.in_kernel_mode:
            mpr = self.regs.mpr & WORD_MASK
            for seg_start, seg_end in ranges:
                if VRAM_START <= seg_start and seg_end <= VRAM_END:
                    continue
                if seg_start >= mpr:
                    continue
                self.memory.check_user_access(seg_start, mpr)

    def _mcheck_copy(self, ins) -> None:
        """COPY - source must be readable and destination fully writable."""
        start = self._get_reg(ins.operands[0]) & WORD_MASK
        end = self._get_reg(ins.operands[1]) & WORD_MASK
        dst = self._get_reg(ins.operands[2]) & WORD_MASK
        src_ranges = self._iter_fill_ranges(start, end)
        length = ((end - start) & WORD_MASK) + 1
        dst_ranges = self._iter_copy_dest_ranges(dst, length)

        write_mask = self.memory._write_mask
        for seg_start, seg_end in dst_ranges:
            hit = write_mask.find(1, seg_start, seg_end + 1)
            while hit != -1:
                self.memory.check_write_protected(hit)
                hit = write_mask.find(1, hit + 1, seg_end + 1)

        if not self.regs.in_kernel_mode:
            mpr = self.regs.mpr & WORD_MASK
            for seg_start, seg_end in src_ranges:
                if VRAM_START <= seg_start and seg_end <= VRAM_END:
                    continue
                if seg_start >= mpr:
                    continue
                self.memory.check_user_access(seg_start, mpr)
            for seg_start, seg_end in dst_ranges:
                if VRAM_START <= seg_start and seg_end <= VRAM_END:
                    continue
                if seg_start >= mpr:
                    continue
                self.memory.check_user_access(seg_start, mpr)
