"""Taaksepäinyhteensopiva laitepaketti: käytä mieluiten kcpu16.hardware.devices."""

from ..hardware.devices import BlockStorageDevice, KeyboardDevice, ScreenDevice

__all__ = ["KeyboardDevice", "ScreenDevice", "BlockStorageDevice"]
