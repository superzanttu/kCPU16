# pyright: reportMissingImports=false
"""Debug-tila kCPU16-emulaattorille.

Sisältää breakpoint-hallinnan ja rekisterimuutosten seurannan.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class DebugState:
    """Debuggerin tila: breakpointit ja rekisterimuutosten seuranta."""

    breakpoints: set[int] = field(default_factory=set)
    prev_registers: dict[str, int] = field(default_factory=dict)

    def toggle_breakpoint(self, addr: int) -> bool:
        """Lisää tai poista breakpoint. Palauttaa True jos lisättiin."""
        if addr in self.breakpoints:
            self.breakpoints.discard(addr)
            return False
        self.breakpoints.add(addr)
        return True

    def has_breakpoint(self, addr: int) -> bool:
        return addr in self.breakpoints

    def snapshot_registers(self, regs: dict[str, int]) -> dict[str, bool]:
        """Vertaa nykyisiä rekistereitä edellisiin. Palauttaa mitkä muuttuivat."""
        changed = {}
        for name, value in regs.items():
            changed[name] = self.prev_registers.get(name) != value
        self.prev_registers = dict(regs)
        return changed

    def clear_breakpoints(self) -> None:
        self.breakpoints.clear()
