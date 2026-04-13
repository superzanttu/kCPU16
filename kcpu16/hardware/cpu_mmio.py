"""MMIO helper mixin for CPU memory reads and writes."""

from __future__ import annotations

from datetime import datetime

from ..constants import (
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
    KBD_DATA,
    KBD_MMIO_END,
    KBD_MMIO_START,
    KBD_STATUS,
    RAND_LFSR_MASK,
    RAND_MMIO,
    UPTIME_W0,
    UPTIME_W1,
    UPTIME_W2,
    UPTIME_W3,
    VRAM_END,
    VRAM_START,
    WORD_MASK,
)


_TMR_DISABLED_MMIO = 0x7FFFFFFFFFFFFFFF


class CPUMMIOMixin:
    """Shared MMIO read/write helpers extracted from the CPU core class."""

    def _read_word(self, addr: int) -> int:
        """Read one word, including MMIO-backed registers."""
        addr &= WORD_MASK
        if CLOCK_MMIO_START <= addr <= CLOCK_MMIO_END:
            return self._read_clock_mmio(addr)
        if KBD_MMIO_START <= addr <= KBD_MMIO_END:
            return self._read_kbd_mmio(addr)
        if addr == RAND_MMIO:
            lsb = self._lfsr & 1
            self._lfsr = (self._lfsr >> 1) ^ ((-lsb) & RAND_LFSR_MASK)
            return self._lfsr
        return self.memory.read(addr)

    def _write_word(self, addr: int, value: int) -> None:
        """Write one word, applying MMIO side effects when needed."""
        addr &= WORD_MASK
        value &= WORD_MASK
        if addr == CLOCK_INT_INTERVAL:
            self.regs.ctmr = value
            self._next_ctmr_time_us = (
                _TMR_DISABLED_MMIO
                if value == 0
                else self._simulated_time_us + value * 1000
            )
            return
        if CLOCK_MMIO_START <= addr <= CLOCK_MMIO_END:
            return
        if KBD_MMIO_START <= addr <= KBD_MMIO_END:
            return
        if addr == RAND_MMIO:
            self._lfsr = value if value != 0 else 1
            return
        if addr == GFX_FLIP_REG:
            if value != 0 and self.flip_callback is not None:
                self.flip_callback()  # type: ignore[operator]
            return
        self.memory.write(addr, value)
        if VRAM_START <= addr <= VRAM_END and self.screen is not None:
            self.screen.mark_vram_dirty(addr)

    def _read_clock_mmio(self, addr: int) -> int:
        """Return real-time or uptime-backed clock MMIO values."""
        if (
            self._clock_snapshot is None
            or self._clock_snapshot_sim_us != self._simulated_time_us
        ):
            self._clock_snapshot = datetime.now()
            self._clock_snapshot_sim_us = self._simulated_time_us
        now = self._clock_snapshot
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
        self._update_uptime_if_needed()
        if addr == UPTIME_W3:
            return 0
        if addr == UPTIME_W2:
            return 0
        if addr == UPTIME_W1:
            return (self._uptime_counter >> 16) & WORD_MASK
        if addr == UPTIME_W0:
            return self._uptime_counter & WORD_MASK
        if addr == CLOCK_INT_INTERVAL:
            return self.regs.ctmr & WORD_MASK
        return 0

    def _read_kbd_mmio(self, addr: int) -> int:
        """Read keyboard MMIO registers."""
        if self.keyboard is None:
            return 0
        if addr == KBD_DATA:
            return self.keyboard.read_data()
        if addr == KBD_STATUS:
            return self.keyboard.read_status()
        return 0
