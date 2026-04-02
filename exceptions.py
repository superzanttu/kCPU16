"""Domain exceptions used by the emulator."""


class KCPU16Error(Exception):
    """Base class for emulator errors."""


class InvalidOpcodeError(KCPU16Error):
    """Raised when decoder cannot map an opcode."""


class PrivilegeViolationError(KCPU16Error):
    """Raised when user mode executes kernel-only instruction."""


class MemoryAccessFaultError(KCPU16Error):
    """Raised when user mode touches protected memory."""


class StackOverflowError(KCPU16Error):
    """Raised when stack pointer goes outside allowed bounds."""
