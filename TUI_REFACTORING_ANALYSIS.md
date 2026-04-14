# kCPU16 TUI Refactoring Analysis

Analysis of `tui.py` categorization into 4 focused modules for maintainability and code organization.

---

## 1. STATE MANAGEMENT (→ tui_state.py)

### Instance Variables to Move

#### Program State
- `current_file: Path | None` – Loaded .asm file path
- `current_disk_file: Path | None` – Current .dsk storage file
- `code_dir: Path` – Directory containing .asm examples
- `storage_dir: Path` – Directory containing .dsk files
- `is_assembled: bool` – Whether code is loaded and ready
- `_watched_mtime: int | None` – File modification time (nanoseconds) for change detection
- `_watched_sources: dict[Path, int | None]` – All watched source files + their mtimes

#### Address Mapping & Source Tracking
- `addr_to_line: dict[int, int]` – Mapping: instruction address → source line number
- `_asm_addr_to_src: dict[int, str]` – Mapping: address → original source line (with comments)
- `_asm_addr_to_label: dict[int, str]` – Mapping: address → user-defined label name
- `_asm_jump_targets: dict[int, list[str]]` – Mapping: address → list of branch instructions that target it

#### View/Display State
- `mem_view_addr: int` – Starting address for Memory tab hex dump view
- `_last_screen_render: str` – Last rendered VRAM output (for dirty-check optimization)
- `_last_screen_lines: list[str] | None` – Cached screen lines (text mode only)
- `_last_vram_version: int` – VRAM version counter (detects changes)
- `_last_gfx_mode: int` – Last observed graphics mode (detects changes)
- `_text_fast_mode: bool` – Enable text-mode optimization in fast execution

#### Instruction Cache
- `_disasm_cache: dict[tuple[int, tuple[int, ...]], str]` – Cache: (addr, words) → disasm_tail

#### Output & Logging
- `_output_buffer: list[str]` – Buffered log messages (for potential export)
- `_boot_status_text: str | None` – Boot operation status message

#### Disk State
- `_disk_dirty: bool` – Whether storage has unsaved changes

#### Execution Mode
- `_exec_mode: str` – Current execution mode: "stopped", "step", "fast", "max", "slow", "reset"
- `_slow_ips: int` – Speed setting for SLOW mode (1–1000 instructions/second)
- `_slow_multiplier: int` – Multiplier for SLOW mode display (1, 10, or 100)

#### Widget References (Hot-Path Optimization Caches)
- `_w_disasm_content: Static | None` – Cached reference to disassembly Static widget
- `_w_regs_content: Static | None` – Cached reference to registers Static widget
- `_w_flags_content: Static | None` – Cached reference to flags Static widget
- `_w_screen_view: Static | None` – Cached reference to screen display Static widget
- `_w_memory_view: Static | None` – Cached reference to memory view Static widget
- `_w_stack_view: Static | None` – Cached reference to stack view Static widget

### Component Objects (Remain in App, Initialized in State Manager)
- `machine: KCPU16Machine` – CPU emulator (core hardware)
- `assembler: Assembler` – Assembly → machine code compiler
- `disassembler: Disassembler` – Machine code → assembly decompiler
- `dbg: DebugState` – Breakpoints + register change tracking

### Methods to Move

#### File Watching & Tracking
- `_check_file_changes()` – Detect file modifications and auto-reassemble
- `_watched_mtime` property management

#### Cache Building & Maintenance
- `_build_asm_caches(segments)` – Build addr→src, addr→label, jump_targets after assembly
- `_build_addr_to_line()` function (already module-level, can stay but referenced)

#### State Snapshots & Tracking
- `_update_disk_title()` – Update disk file display name in UI
- `_update_program_title()` – Update program name in UI
- `_sync_speed_slider()` – Sync slider with _slow_ips value

#### State Initialization
- Constructor initialization logic (already in `__init__`, organize into dedicated methods)
- `_initialize_state()` – Setup all state variables
- `_initialize_caches()` – Setup cache structures

#### File I/O State Management
- `_do_open(path)` – Load and prepare assembly file (orchestrates file → state)
- `_do_assemble()` – Compile and load assembly (coordinates state + machine)

### Interdependencies

- **Depends on**: `machine`, `assembler`, `Path` (stdlib)
- **Depended on by**: Rendering module (reads state for display), Commands module (reads/writes state), App module (initializes state)
- **Key coupling**: File path resolution, memory access for building addr→line map

### Imports Needed

```python
from pathlib import Path
from .machine import KCPU16Machine
from .assembler import Assembler
from .disassembler import Disassembler
from .debugger import DebugState
from .constants import BOOT_RAM_START, WORD_MASK
```

---

## 2. RENDERING (→ tui_render.py)

### Methods to Move

#### Screen/VRAM Rendering (High Priority)
- `_refresh_screen_tab(force=False)` – Render VRAM with mode detection + dirty-check optimization
- All related VRAM rendering logic, double-buffering

#### Disassembly Rendering
- `_refresh_disassembly()` – Render disassembly window with PC highlight, breakpoint markers
- `_fmt_disasm_tail(line)` – Color-format mnemonic + operands (without address)
- `_fmt_disasm_line(line)` – Color-format full disassembly line (with address)
- `_fmt_operands(mnemonic, ops_str)` – Convert operands to readable format with colors
  - Handles register names (R0, FP, SP)
  - Handles memory references ([addr], [R1], [FP+2])
  - Handles immediate values with correct coloring
  - Handles branch target labels

#### Register Display Rendering
- `_refresh_registers()` – Two-column register display with change highlighting
- Register change detection integration with `dbg.snapshot_registers()`

#### Flags & CPU Status Rendering
- `_refresh_flags()` – Display individual flag bits + CPU mode + uptime + interrupt timers
- `_refresh_cpu_status()` – Program state + execution mode + cycle counter + breakpoint list

#### Memory/Stack View Rendering
- `_refresh_memory()` – Hex dump starting from `mem_view_addr`
- `_refresh_stack()` – Stack view (SP+1 onwards, 20 items)

#### Orchestration
- `_refresh_all(include_screen=False, force_screen=False)` – Call all refresh methods

#### Visual State Management for MAX Mode
- `_set_max_stale_visual_state(max_mode_active)` – Dimming visual for stale panels during MAX execution
- `_apply_stale_snapshot(widget_id)` – Convert widget content to stale snapshot

#### Logging Output Formatting
- `_log_step_info()` – Format and log step-by-step execution details
- `_show_cpu_crash(exc)` – Detailed crash report with registers, instruction, flags
- `_format_hex_dump(words, base_addr)` – Format memory/disk block as hex dump

### Helper Formatting Functions (Module-Level, After Class)
```python
# These become module-level functions or remain as Static methods

def _fmt_instruction_line(addr, opcode, words, disasm_tail, pc, has_bp, source_line):
    """Format a single disassembly line with all decorations."""

def _fmt_register_row(names, regs, changed):
    """Format a two-column register display row."""

def _fmt_flag_display(flags, mode, uptime, tmr, ctmr, gfx_mode, boot_status):
    """Format flags panel content."""
```

### Interdependencies

- **Depends on**: 
  - State module (reads state variables: `mem_view_addr`, `_last_vram_version`, `_exec_mode`, etc.)
  - App module's widget cache references (`_w_disasm_content`, etc.)
  - `machine` (reads CPU/memory/registers for display)
  - `dbg` (reads breakpoints, register changes)
  - `disassembler` (converts bytecode to mnemonics)
  - `constants` (flag masks, memory ranges)

- **Depended on by**: App module (calls refresh methods), Workers thread (calls `_refresh_all`)

- **Widget Access Pattern**: 
  - Rendering methods receive widget references via App or use `self.query_one()`
  - Should switch to dependency injection: receive widget refs as parameters

### Imports Needed

```python
from rich.text import Text
from textual.widgets import Static, RichLog
from .constants import (
    WORD_MASK, VRAM_START, GFX_MODE_REG, GFX_MODE_B, GFX_MODE_C,
    SR_FLAG_Z, SR_FLAG_N, SR_FLAG_C, SR_FLAG_V, SR_FLAG_I, SR_FLAG_P,
    BOOT_RAM_START
)
from .disassembler import REVERSE_TABLE
from .instruction import OPCODE_TABLE
```

---

## 3. COMMAND HANDLERS (→ tui_commands.py)

### Main Entry Point
- `_execute_command(command: str) -> CommandResult` – Main command dispatcher

### Command Handler Methods

#### File & Assembly Commands
- `_do_syntax_check()` – Syntax validation without loading
- `_boot_from_disk_image(path)` – Load and boot from .dsk file

#### Breakpoint Commands
- `_handle_bp_command(args)` – Parse `bp <addr> | bp list | bp clear`

#### Memory Commands
- `_handle_mem_command(args)` – Parse `mem <addr> [count]`
- `_handle_mset_command(args)` – Parse `mset <addr> <value>`
- `_handle_mfill_command(args)` – Parse `mfill <addr> <count> <value>`

#### Storage/Disk Commands
- `_handle_disk_command(args)` – Parse `disk <block> | disk load|save <path>`
- `_handle_dset_command(args)` – Parse `dset <block> <offset> <value>`
- `_handle_dfill_command(args)` – Parse `dfill <block> <value>`
- `_handle_mem2disk_command(args)` – Parse `mem2disk <addr> <block>`
- `_handle_disk2mem_command(args)` – Parse `disk2mem <block> <addr>`

#### Reset Commands
- `_handle_reset_command(args)` – Parse `reset [deep|cpu]`

#### Helper Functions
- `_format_hex_dump(words, base_addr)` – Format memory/disk as hex dump (also in rendering)
- `_parse_number(s)` – Parse hex/decimal/binary/octal input

### Interdependencies

- **Depends on**:
  - State module (reads/writes all state variables)
  - App module (machine, workers, execution control)
  - `Path` (file operations)
  - `CommandResult` dataclass

- **Depended on by**: 
  - App's `on_input_submitted()` (when user types command)
  - Action methods may delegate to commands

- **Orchestration**: Commands often need to:
  1. Parse input parameters
  2. Validate state (e.g., "is file loaded?")
  3. Call App/State methods to perform action
  4. Return result + update UI if needed

### Imports Needed

```python
from pathlib import Path
from .constants import WORD_MASK, BOOT_RAM_START
from dataclasses import dataclass

@dataclass
class CommandResult:
    ok: bool
    message: str
```

---

## 4. APP/LAYOUT (→ tui_app.py)

### Main App Class
- `KCPU16TUI(App[None])` – Main Textual application

### Layout & Composition
- `compose() -> ComposeResult` – Build entire widget tree
- `CSS` class variable – Styling for all widgets

### Initialization & Lifecycle
- `__init__()` – Partial initialization (state setup moved to State module)
- `on_mount()` – Lifecycle hook: finalize after DOM is ready

### Keybindings & Binding Handlers
- `BINDINGS` class variable – Keyboard shortcut definitions
- `on_button_pressed(event)` – Toolbar button click dispatcher
- `on_speed_slider_changed(event)` – Speed slider value change
- `on_input_submitted(event)` – Command input handler

### Action Methods (Keyboard Shortcuts + Button Clicks)
#### Movement/Display Actions
- `action_step_once()` – Single instruction step (F7/F10)

#### Execution Control Actions
- `action_run_full_speed()` – Run at full speed, updateable UI (F5)
- `action_run_max_speed()` – Maximum speed, minimal UI updates (F4)
- `action_run_slow_speed()` – Configurable slow speed with per-instruction UI (F6)
- `action_stop_program()` – Stop execution (F8)

#### Program Control Actions
- `action_reset_machine()` – Full reset to initial state (Ctrl+R)
- `action_toggle_breakpoint()` – Toggle BP at PC (F2)

#### File Operations Actions
- `action_open_file()` – File picker for .asm loading (Ctrl+O)
- `action_boot_disk()` – File picker for .dsk boot (Boot button)
- `action_assemble_code()` – Reassemble current file (Ctrl+B)

#### Display Actions
- `action_clear_screen()` – Clear VRAM (F9)
- `action_show_help()` – Display help message (F1)

#### App Control
- `action_quit()` – Exit app with save confirmation (Ctrl+Q)

### Background Worker Management
- `_cpu_run_worker(mode)` – Threaded CPU execution (fast/max/slow modes)
- `_reload_and_run(mode)` – Reload file and start execution

### Keyboard Input Passthrough
- `on_key(event)` – Pass ASCII characters to emulator's keyboard device when running

### UI Update Coordination
- `_update_run_mode_ui()` – Update toolbar button states to reflect execution mode
- `_open_browser_page(url)` – Open browser for documentation (if implemented)

### Dialog/Modal Management
- Dialog classes: `SaveConfirmDialog`, `FilePickerDialog`, `SpeedSlider` (widget components)

### Utility/Logging
- `_log(message)` – Write to output panel with timestamp

### Entry Point Function
- `run_tui(startup_asm, startup_dsk)` – Main entry point for CLI

### Interdependencies

- **Depends on**:
  - State module (state management methods)
  - Rendering module (refresh methods)
  - Command module (command execution)
  - Textual framework (App, widgets, bindings)
  - `machine`, `assembler`, `disassembler`, `dbg`

- **Depended on by**: 
  - No internal dependencies (is root)
  - Called from CLI entry point

- **Orchestration Flow**:
  ```
  UI Event (key/button) → Action method
                        → State update (via commands/direct)
                        → Refresh UI (rendering methods)
                        → Worker thread (for CPU execution)
  ```

### Imports Needed

```python
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
from pathlib import Path
import time
from .constants import ARCH_SYMBOLS, BOOT_RAM_START
from .__version__ import __version__

# Internal modules (to be created)
from .tui_state import TUIState  # or State management functions
from .tui_render import Renderer  # or rendering functions
from .tui_commands import CommandResult  # or command dispatcher
```

---

## 5. SUPPORTING COMPONENTS (Stay in Separate Files or Integrate)

### Dataclasses & Models
- `CommandResult` – Command execution result + message ✓ (move to tui_commands.py)

### Modal Dialogs & Widgets
These can move to separate `tui_dialogs.py` or stay in app file, depending on complexity:
- `SaveConfirmDialog` – Confirm unsaved changes modal
- `FilePickerDialog` – File selection dialog  
- `SpeedSlider` – Custom slider widget for speed control

### Module-Level Functions & Constants
- `_build_addr_to_line(source, assembler)` – Build address→line mapping ✓ (stays module-level or moves to State)
- `_find_bootblock_jump_target(words)` – Find first branch in bootblock ✓ (stays module-level or moves to Commands)
- `REG_NAMES` constant dict ✓ (moves to tui_render.py with operand formatting)
- `_REG_FIRST`, `_REG_SECOND`, `_BRANCH_MNEMONICS` ✓ (move to tui_render.py)
- `_RICH_MARKUP_RE` regex ✓ (move to tui_render.py)

---

## 6. DEPENDENCY GRAPH

```
┌─────────────────────────────────────────────────────────┐
│ External: Textual, Rich, pathlib, time, dataclasses  │
└────┬──────────────────────────────────────────────────┘
     │
     ├──> tui_render.py ◄──┐
     │    (Formatting,      │ reads state
     │    Display logic)    │
     │                      │
─────┼──> tui_state.py ◄────┼──── tui_commands.py
     │    (State vars,      │    (Command parsing,
     │    File tracking)    │     validation, dispatch)
     │    ▲                 │
     │    │ uses            │
     │    └─────────────────┼──┐
     │                      │  │
     └──> tui_app.py ◄──────┴──┘
          (Main app,
           App lifecycle,
           Actions,
           Orchestration)
          
     ─────────────────
     Machine (CPU hardware core)
     Assembler (Compiler)
     Disassembler (Decompiler)
     DebugState (BP + registers)
```

### Module Initialization Order

1. **tui_state.py** – Pure state management, minimal dependencies
2. **tui_render.py** – Depends on state for reading; can import state module
3. **tui_commands.py** – Depends on state for reading/writing; orchestrates actions
4. **tui_app.py** – Imports all above; Textual app entry point

---

## 7. MIGRATION STRATEGY

### Phase 1: Extract State Module
1. Create `tui_state.py` with `TUIState` class or module-level functions
2. Move all instance variables' initialization
3. Move file watching, caching, state synchronization
4. Update `tui.py` to use state methods

### Phase 2: Extract Rendering Module
1. Create `tui_render.py` with rendering functions/class
2. Move all `_refresh_*` methods
3. Move all `_fmt_*` formatting methods
4. Move constants (`REG_NAMES`, `_BRANCH_MNEMONICS`, etc.)
5. Update `tui.py` to call rendering module

### Phase 3: Extract Command Handlers
1. Create `tui_commands.py` with command dispatcher
2. Move `_execute_command` and all `_handle_*` methods
3. Move `CommandResult` dataclass
4. Update `on_input_submitted()` to delegate to commands module

### Phase 4: Refactor App Module
1. Trim `tui_app.py` to core app logic only
2. Delegate to state/render/command modules
3. Keep: compose, bindings, actions, workers, lifecycle

### Phase 5: Integration Testing
- Verify each module imports work
- Test all workflows (load→assemble→step, run, breakpoints, etc.)
- Visual testing of UI rendering

---

## 8. BENEFITS OF SPLIT

| Aspect                   | Benefit                                                                |
| ------------------------ | ---------------------------------------------------------------------- |
| **Maintainability**      | Smaller, focused modules (~200-400 lines each) vs. 4000+ line monolith |
| **Testability**          | Rendering logic can be tested independently of UI framework            |
| **Reusability**          | Rendering functions usable by CLI/web clients                          |
| **Parallel Development** | Multiple developers can work on different modules                      |
| **Debugging**            | Stack traces shorter; issues localized to specific module              |
| **Code Review**          | Smaller diff sizes for PRs                                             |
| **Performance**          | Easier to profile and optimize individual modules                      |

---

## 9. FILE STRUCTURE AFTER REFACTORING

```
kcpu16/
├── tui/
│   ├── __init__.py          # Exports run_tui()
│   ├── app.py               # Main KCPU16TUI class + Textual app (800-1000 lines)
│   ├── state.py             # State management + file tracking (400-500 lines)
│   ├── render.py            # All rendering + formatting (800-1000 lines)
│   ├── commands.py          # Command dispatcher + handlers (600-800 lines)
│   ├── dialogs.py           # SaveConfirmDialog, FilePickerDialog, SpeedSlider (400 lines)
│   ├── constants.py         # Operand format tables, regex, etc. (100 lines)
│   └── models.py            # CommandResult dataclass (20 lines)
├── machine.py               # (unchanged)
├── assembler.py             # (unchanged)
├── cpu.py / cpu_core.py     # (unchanged)
└── ...
```

Or keep as single `tui.py` with clear section markers:
```python
# ============ STATE MANAGEMENT ============
# ============ RENDERING ============
# ============ COMMAND HANDLERS ============
# ============ APP/LAYOUT ============
```

---

## 10. KEY DESIGN DECISIONS

### Decision: Stateful Renderer vs. Pure Functions

**Options:**
- A) Create `Renderer` class with state (widget references, caches)
- B) Use pure functions that receive state + widgets as parameters

**Recommendation: Option B** (pure functions)
- Easier to test independently
- No hidden state dependencies
- Thread-safe (functions don't modify shared state)
- Can be reused across different UI frameworks

**Implementation:**
```python
def render_disassembly(
    machine: KCPU16Machine,
    state: TUIState,
    dbg: DebugState,
    disassembler: Disassembler
) -> str:
    """Pure function: returns rendered disassembly HTML/Text."""
```

### Decision: Module vs. Class Organization

**Recommendation: Module-level functions initially**, then refactor to class if:
- State grows complex
- Need to share intermediate calculations
- Want to encapsulate logging/caching

---

## 11. CHECKLIST FOR IMPLEMENTATION

- [ ] Create four new files: `tui_state.py`, `tui_render.py`, `tui_commands.py`, `tui_app.py`
- [ ] Move constants to appropriate modules
- [ ] Move instance variables to state module
- [ ] Move all `_refresh_*` methods to render module
- [ ] Move all `_execute_command` and handlers to command module
- [ ] Update imports in each module
- [ ] Fix circular import issues
- [ ] Test file loading & assembly
- [ ] Test step/run/pause commands
- [ ] Test breakpoints
- [ ] Test disk operations
- [ ] Test UI rendering (disassembly, registers, memory, stack)
- [ ] Full integration test with example programs

