"""High-level machine wrapper: CPU + memory + devices + boot flow."""

from __future__ import annotations

from dataclasses import dataclass, field

from .constants import BOOT_RAM_START, BOOT_RAM_END, VRAM_END, VRAM_START
from .cpu import CPU
from .devices import BlockStorageDevice, KeyboardDevice, ScreenDevice
from .memory import Memory
from .registers import RegisterFile


@dataclass
class KCPU16Machine:
    memory: Memory = field(default_factory=Memory)
    regs: RegisterFile = field(default_factory=RegisterFile)
    storage: BlockStorageDevice = field(default_factory=BlockStorageDevice)
    keyboard: KeyboardDevice = field(default_factory=KeyboardDevice)
    screen: ScreenDevice = field(default_factory=ScreenDevice)

    cpu: CPU = field(init=False)

    def __post_init__(self) -> None:
        self.cpu = CPU(memory=self.memory, regs=self.regs, storage=self.storage)

    def cold_reset(self) -> None:
        self.memory.reset()
        self.cpu.reset()

    def boot_from_storage(self) -> None:
        """Implements documented boot copy from storage 0x0000..0x00FF to RAM 0x0100..0x01FF."""
        boot_words = self.storage.read_block(0)
        self.memory.load_words(BOOT_RAM_START, boot_words)
        self.regs.pc = BOOT_RAM_START

    def load_program(self, words: list[int], start_addr: int = BOOT_RAM_START) -> None:
        self.memory.load_words(start_addr, words)
        self.regs.pc = start_addr

    def run(self, max_cycles: int = 1000000) -> None:
        self.cpu.run(max_cycles=max_cycles)

    def step(self) -> None:
        self.cpu.step()

    def dump_registers(self) -> dict[str, int]:
        return {
            "R0": self.regs.r0,
            "R1": self.regs.r1,
            "R2": self.regs.r2,
            "R3": self.regs.r3,
            "FP": self.regs.fp,
            "SP": self.regs.sp,
            "PC": self.regs.pc,
            "SR": self.regs.sr,
            "MPR": self.regs.mpr,
            "TMR": self.regs.tmr,
        }

    @property
    def process_exited(self) -> bool:
        return self.cpu.process_exit_requested

    def render_screen(self) -> str:
        return self.screen.render_text(self.memory)

    def clear_screen_memory(self, value: int = 0) -> None:
        v = value & 0xFFFF
        for addr in range(VRAM_START, VRAM_END + 1):
            self.memory.write(addr, v)
