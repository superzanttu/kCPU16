"""Register model for kCPU16."""

from dataclasses import dataclass, field

from .constants import (
    DEFAULT_MPR,
    DEFAULT_TIMER_INTERVAL,
    MODE_KERNEL,
    SR_FLAG_C,
    SR_FLAG_I,
    SR_FLAG_N,
    SR_FLAG_P,
    SR_FLAG_V,
    SR_FLAG_Z,
    WORD_MASK,
)


@dataclass
class RegisterFile:
    """Represents GPRs and special registers."""

    r0: int = 0
    r1: int = 0
    r2: int = 0
    r3: int = 0

    fp: int = 0
    sp: int = 0xFFFF
    pc: int = 0x0100
    sr: int = 0

    mpr: int = DEFAULT_MPR
    tmr: int = DEFAULT_TIMER_INTERVAL

    _gpr_names: tuple[str, ...] = field(default=("R0", "R1", "R2", "R3"), init=False)

    def reset(self) -> None:
        self.r0 = 0
        self.r1 = 0
        self.r2 = 0
        self.r3 = 0
        self.fp = 0
        self.sp = 0xFFFF
        self.pc = 0x0100
        self.sr = 0
        self.mpr = DEFAULT_MPR
        self.tmr = DEFAULT_TIMER_INTERVAL
        self.set_flag(SR_FLAG_P, MODE_KERNEL)
        self.set_flag(SR_FLAG_I, 0)

    def get_flag(self, bit: int) -> int:
        return 1 if (self.sr & (1 << bit)) else 0

    def set_flag(self, bit: int, value: int) -> None:
        if value:
            self.sr |= 1 << bit
        else:
            self.sr &= ~(1 << bit)
        self.sr &= WORD_MASK

    @property
    def in_kernel_mode(self) -> bool:
        return bool(self.get_flag(SR_FLAG_P))

    def set_zn_flags(self, value: int) -> None:
        value &= WORD_MASK
        self.set_flag(SR_FLAG_Z, 1 if value == 0 else 0)
        self.set_flag(SR_FLAG_N, 1 if (value & 0x8000) else 0)

    def set_carry_overflow(self, carry: bool, overflow: bool) -> None:
        self.set_flag(SR_FLAG_C, 1 if carry else 0)
        self.set_flag(SR_FLAG_V, 1 if overflow else 0)
