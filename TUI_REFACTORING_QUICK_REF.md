# tui.py Refactoring - Quick Reference

## CATEGORY 1: STATE MANAGEMENT (→ tui_state.py)

### Instance Variables
**Program & File State:**
- `current_file: Path | None`
- `current_disk_file: Path | None`
- `code_dir: Path`
- `storage_dir: Path`
- `is_assembled: bool`
- `_watched_mtime: int | None`
- `_watched_sources: dict[Path, int | None]`

**Address Mapping:**
- `addr_to_line: dict[int, int]`
- `_asm_addr_to_src: dict[int, str]`
- `_asm_addr_to_label: dict[int, str]`
- `_asm_jump_targets: dict[int, list[str]]`

**View State:**
- `mem_view_addr: int`
- `_last_screen_render: str`
- `_last_screen_lines: list[str] | None`
- `_last_vram_version: int`
- `_last_gfx_mode: int`
- `_text_fast_mode: bool`

**Caching:**
- `_disasm_cache: dict[tuple[int, tuple[int, ...]], str]`

**Output & Status:**
- `_output_buffer: list[str]`
- `_boot_status_text: str | None`
- `_disk_dirty: bool`

**Execution Control:**
- `_exec_mode: str`  # "stopped", "step", "fast", "max", "slow", "reset"
- `_slow_ips: int`  # 1-1000
- `_slow_multiplier: int`  # 1, 10, 100

**Widget Caches:**
- `_w_disasm_content: Static | None`
- `_w_regs_content: Static | None`
- `_w_flags_content: Static | None`
- `_w_screen_view: Static | None`
- `_w_memory_view: Static | None`
- `_w_stack_view: Static | None`

### Methods
- `_check_file_changes()`
- `_build_asm_caches(segments)`
- `_update_disk_title()`
- `_update_program_title()`
- `_sync_speed_slider()`
- `_do_open(path)`
- `_do_assemble()`

---

## CATEGORY 2: RENDERING (→ tui_render.py)

### Main Render Methods
- `_refresh_all(include_screen=False, force_screen=False)`
- `_refresh_disassembly()`
- `_refresh_registers()`
- `_refresh_flags()`
- `_refresh_cpu_status()`
- `_refresh_screen_tab(force=False)`
- `_refresh_memory()`
- `_refresh_stack()`

### Formatting & Display Helpers
- `_fmt_disasm_tail(disasm_tail)`
- `_fmt_disasm_line(line)`
- `_fmt_operands(mnemonic, ops_str)`
- `_format_hex_dump(words, base_addr)`

### State Display
- `_log_step_info()`
- `_show_cpu_crash(exc)`
- `_set_max_stale_visual_state(max_mode_active)`
- `_apply_stale_snapshot(widget_id)`

### Constants & Helper Data
- `REG_NAMES: dict[int, str]`
- `_REG_FIRST: set[str]`
- `_REG_SECOND: set[str]`
- `_BRANCH_MNEMONICS: frozenset[str]`
- `_RICH_MARKUP_RE: Pattern`

---

## CATEGORY 3: COMMAND HANDLERS (→ tui_commands.py)

### Main Dispatcher
- `_execute_command(command: str) -> CommandResult`

### Command Handlers
- `_handle_bp_command(args)`
- `_handle_mem_command(args)`
- `_handle_mset_command(args)`
- `_handle_mfill_command(args)`
- `_handle_disk_command(args)`
- `_handle_dset_command(args)`
- `_handle_dfill_command(args)`
- `_handle_mem2disk_command(args)`
- `_handle_disk2mem_command(args)`
- `_handle_reset_command(args)`

### Special Handlers
- `_do_syntax_check()`
- `_boot_from_disk_image(path)`

### Models
- `CommandResult` dataclass (ok: bool, message: str)

### Support
- `_format_hex_dump(words, base_addr)` (also in render, can share)

---

## CATEGORY 4: APP/LAYOUT (→ tui_app.py)

### Class & Structure
- `KCPU16TUI(App[None])` class definition
- `TITLE`, `SUB_TITLE` class variables
- `CSS` class variable (styling)
- `BINDINGS` class variable (keybindings)

### Lifecycle Hooks
- `__init__()`
- `on_mount()`

### Composition
- `compose() -> ComposeResult`

### Widget Event Handlers
- `on_button_pressed(event)`
- `on_speed_slider_changed(event)`
- `on_input_submitted(event)`
- `on_key(event)`

### Action Methods (Keyboard/Button)
- `action_step_once()`
- `action_run_full_speed()`
- `action_run_max_speed()`
- `action_run_slow_speed()`
- `action_stop_program()`
- `action_reset_machine()`
- `action_toggle_breakpoint()`
- `action_open_file()`
- `action_boot_disk()`
- `action_assemble_code()`
- `action_clear_screen()`
- `action_show_help()`
- `action_quit()`

### Execution Workers
- `_cpu_run_worker(mode: str)`
- `_reload_and_run(mode: str)`
- `_run_with_breakpoints(max_cycles)`
- `_update_run_mode_ui()`

### Output
- `_log(message)`

### Entry Point
- `run_tui(startup_asm=None, startup_dsk=None) -> int` (module-level function)

---

## SUPPORTING COMPONENTS

### Modal Dialogs/Widgets (→ tui_dialogs.py or keep in app)
- `SaveConfirmDialog` class
- `FilePickerDialog` class
- `SpeedSlider` class

### Module-Level Functions (Stay where used)
- `_build_addr_to_line(source, assembler)` → State module
- `_find_bootblock_jump_target(words)` → Commands or State

---

## REFACTORING CHECKLIST

### Step 1: Create File Structure
- [ ] Create `tui_state.py`
- [ ] Create `tui_render.py`
- [ ] Create `tui_commands.py`
- [ ] Create `tui_app.py` (new, split from tui.py)
- [ ] Optionally create `tui_dialogs.py`

### Step 2: Move State Module
- [ ] Copy all state variables to `TUIState` class or as module-level setup
- [ ] Move state-related methods
- [ ] Move file tracking & caching methods
- [ ] Add imports (Path, KCPU16Machine, Assembler, etc.)

### Step 3: Move Rendering Module
- [ ] Copy all `_refresh_*` methods
- [ ] Copy all `_fmt_*` methods
- [ ] Move constants (REG_NAMES, _REG_FIRST, etc.)
- [ ] Move regex: `_RICH_MARKUP_RE`
- [ ] Add imports (rich.text.Text, constants, etc.)
- [ ] Update widget references to use dependency injection

### Step 4: Move Command Handlers
- [ ] Copy `_execute_command` and all `_handle_*` methods
- [ ] Move `CommandResult` dataclass
- [ ] Move `_do_syntax_check`, `_boot_from_disk_image`
- [ ] Add imports (Path, constants, etc.)

### Step 5: Create App Module
- [ ] Copy class definition, CSS, BINDINGS
- [ ] Copy __init__ and on_mount
- [ ] Copy compose()
- [ ] Copy widget event handlers
- [ ] Copy all action_* methods
- [ ] Copy worker methods
- [ ] Copy `run_tui()` entry point
- [ ] Add imports from new modules

### Step 6: Fix Circular Imports & Integration
- [ ] Import state module in app module
- [ ] Import render module in app module
- [ ] Import commands module in app module
- [ ] Update all method calls (`_refresh_all()` → `render.refresh_all()`, etc.)
- [ ] Test imports in isolation

### Step 7: Testing
- [ ] Test basic startup
- [ ] Test file loading
- [ ] Test assembly
- [ ] Test stepping
- [ ] Test running (fast/slow/max)
- [ ] Test breakpoints
- [ ] Test memory commands
- [ ] Test disk commands
- [ ] Test screen rendering
- [ ] Full end-to-end test with example program

---

## IMPORT TEMPLATE FOR EACH MODULE

### tui_state.py
```python
from pathlib import Path
from .machine import KCPU16Machine
from .assembler import Assembler
from .disassembler import Disassembler
from .debugger import DebugState
from .constants import BOOT_RAM_START, WORD_MASK
```

### tui_render.py
```python
from rich.text import Text
from textual.widgets import Static
from .constants import (
    WORD_MASK, VRAM_START, GFX_MODE_REG, GFX_MODE_B, GFX_MODE_C,
    SR_FLAG_Z, SR_FLAG_N, SR_FLAG_C, SR_FLAG_V, SR_FLAG_I, SR_FLAG_P
)
from .disassembler import REVERSE_TABLE
from .instruction import OPCODE_TABLE
import re
import time
```

### tui_commands.py
```python
from pathlib import Path
from dataclasses import dataclass
from .constants import WORD_MASK, BOOT_RAM_START

@dataclass
class CommandResult:
    ok: bool
    message: str
```

### tui_app.py
```python
from pathlib import Path
import time
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual import events
from textual.message import Message
from textual.screen import ModalScreen
from textual.widget import Widget
from textual.worker import get_current_worker
from textual._work_decorator import work
from textual.widgets import (
    Button, Checkbox, Input, ListItem, ListView, RichLog, Static,
    TabbedContent, TabPane
)
from . import __version__
from .machine import KCPU16Machine
from .assembler import Assembler
from .disassembler import Disassembler
from .debugger import DebugState
from .constants import BOOT_RAM_START, WORD_MASK

# Import refactored modules
from . import tui_state
from . import tui_render
from . import tui_commands
```

---

## NOTES FOR CLEANEST MIGRATION

1. **Keep Machine + Assembler + Disassembler in App**: These are core emulator components, not UI concerns
2. **Dependency Injection over Globals**: Pass widget references and state to render functions rather than storing them
3. **Module Functions vs. Classes**: Render module can be pure functions; Command module dispatcher can be function-based; State can be class-based
4. **Update on_input_submitted()**: Should call `tui_commands._execute_command()` and get back `CommandResult`
5. **Refresh Calls**: Instead of `self._refresh_all()`, call render module: `tui_render.refresh_all(self.machine, self.state, ...)`
6. **Widget Querys**: Keep widget queries in App layer; render methods take widgets as parameters

---

## PRESERVING FUNCTIONALITY

All functionality remains identical after split:
- ✓ File loading & auto-watching
- ✓ Assembly & disassembly
- ✓ Step/run/breakpoints
- ✓ Memory/disk commands
- ✓ VRAM rendering (all modes: text, B, C)
- ✓ Register tracking
- ✓ Keyboard input passthrough
- ✓ All keybindings & actions

No behavior changes—only code organization improves.

