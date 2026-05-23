# Phase 1: TUI Engine Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-23
**Phase:** 01-tui-engine-core
**Areas discussed:** Engine file structure, Key reading strategy, Single-select visual style, Number jump UX

---

## Engine File Structure

| Question | Option | Description | Selected |
|----------|--------|-------------|----------|
| File organization | Single file | One tui.sh with everything | ✓ |
| | Core + widget files | Separate core + widget files | |
| | Self-contained widgets | Standalone widgets sourcing core | |
| API contract | Source + function call | source tui.sh then call functions | ✓ |
| | Standalone CLI | tui.sh --select with flags | |
| | Dual mode | Both sourceable and CLI | |
| File location | Repo root | tui.sh alongside checklist.sh, fu.sh | ✓ |
| | src/ directory | src/tui.sh in subdirectory | |
| Relationship to checklist.sh | New file, fresh code | Write from scratch, checklist.sh as reference | ✓ |
| | Evolve checklist.sh | Refactor into tui.sh | |
| | Copy and extend | Copy checklist.sh and extend | |
| Function naming | tui_ prefix | tui_init(), tui_select(), _tui_* helpers | ✓ |
| | Flat naming | term_init(), select_menu() | |
| | Layered naming | tui_* for engine, widget-specific for widgets | |
| Return value | Both | stdout + TUI_RESULT global variable | ✓ |
| | Index to stdout | Print to stdout, caller captures | |
| | Global variable | Set TUI_RESULT only | |
| Signal traps | Engine handles own traps | tui_init() registers INT/TERM/HUP/QUIT | ✓ |
| | Caller manages traps | Explicit tui_restore() only | |
| TTY handling | Explicit /dev/tty | Read from /dev/tty, auto-fallback | ✓ |
| | Read from stdin | Caller ensures stdin is terminal | |

**Notes:** User chose "Both" for return value — wants flexibility of both stdout capture and global variable access.

---

## Key Reading Strategy

| Question | Option | Description | Selected |
|----------|--------|-------------|----------|
| Keypress reading | Shell-aware hybrid | read -rsn1 on bash/zsh, dd on dash/ash/busybox | ✓ |
| | Pure dd everywhere | dd bs=1 count=1 for all shells | |
| | POSIX read trick | stty -icanon + read line | |
| Escape sequences | Timed multi-byte read | ESC + timed continuation bytes | ✓ |
| | Fixed 3-byte parsing | Read fixed bytes after ESC | |
| Timeout | Configurable | TUI_KEY_TIMEOUT env var, default 100ms | ✓ |
| | 100ms (snappy) | Fixed 100ms inter-byte timeout | |
| | 200ms (SSH-safe) | Fixed 200ms for high-latency connections | |

**Notes:** User added hard constraint — no dd with of=, seek=, or conv= flags. Read-only dd usage only.

---

## Single-select Visual Style

| Question | Option | Description | Selected |
|----------|--------|-------------|----------|
| Visual style | Full-screen box | Clear screen, bordered box, title, items, footer | ✓ |
| | Full-screen list, no box | No border, just list with highlight | |
| | Inline box | Don't clear screen, render inline | |
| Item format | Numbered + reverse-video | Number + label, \033[7m highlight | ✓ |
| | Radio-button style | ( )/(•) indicators with number prefix | |
| | Colored highlight bar | Blue background + white text | |
| Box characters | Auto-detect | Try Unicode, fall back to ASCII | ✓ |
| | ASCII (+ - \|) | Universal, zero risk | |
| | Unicode box drawing | Modern look, may break on minimal terminals | |
| Help footer | Minimal + ? toggle | Primary keys visible, ? for full display | ✓ |
| | Compact single line | All keybindings always visible | |
| Title area | Title + separator | Centered title, optional subtitle, --- separator | ✓ |
| | Title in border | Title integrated into top border | |
| | Title only | No separator | |
| Scroll indicators | ↑more / ↓more | Dim indicators when content overflows | ✓ |
| | Percentage indicator | Scroll percentage (e.g., 33%) | |
| Status line | Item counter | "Item N of M" between items and footer | ✓ |
| | No status line | Items and footer only | |
| | Item description | Show current item label/description | |

---

## Number Jump UX

| Question | Option | Description | Selected |
|----------|--------|-------------|----------|
| Accumulator mode | Auto-timeout | Digits accumulate, timeout triggers jump | ✓ |
| | Enter to confirm | Type digits, press Enter | |
| | Hybrid | 1-digit instant, multi-digit Enter | |
| Visual feedback | Show digits in status line | "Go to: 15_" replaces item counter | ✓ |
| | Live cursor jump | Jump to matching item as typed | |
| | Silent accumulation | No visual feedback | |
| Out-of-range handling | Flash + clear | Error message, clear accumulator | ✓ |
| | Clamp to nearest | Jump to last valid item | |
| | Drop invalid digits | Silently ignore | |

---

## OpenCode's Discretion

- Internal variable naming within `_tui_*` functions
- Exact section ordering within `tui.sh`
- Exact escape sequence mapping (arrow keys, PgUp/PgDn, Home/End byte sequences)
- Color palette for dim text, scroll indicators, error flash
- Exact rendering implementation (cursor positioning, screen redraw strategy)
- Fallback numbered prompt format and behavior
- Shell detection method in `tui_init()`

## Deferred Ideas

None — discussion stayed within phase scope.
