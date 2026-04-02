"""Simple keyboard device model.

The architecture document does not yet define exact MMIO addresses for keyboard state,
so this device offers a queue that CPU-side KGET implementation can consume later.
"""

from collections import deque


class KeyboardDevice:
    def __init__(self) -> None:
        self._queue: deque[int] = deque()

    def push_key(self, ascii_code: int) -> None:
        self._queue.append(ascii_code & 0xFF)

    def pop_key(self) -> int:
        if not self._queue:
            return 0
        return self._queue.popleft()
