---
phase: 02-interactive-widgets
plan: 01
type: execute
subsystem: TUI Engine
tags: [tui, checklist, key-reader, widgets]
requires: []
provides: [tui_checklist, TUI_KEY_CTRL_D, TUI_KEY_DELETE, TUI_KEY_ASTERISK, TUI_KEY_MINUS, _tui_read_char]
affects: [tui.sh]
tech-stack:
  added: []
  patterns: [eval-based-indexed-storage, full-screen-box-rendering, event-loop-with-key-dispatch, dual-return-stdout-TUI_RESULT, fallback-numbered-prompt]
key-files:
  created: []
  modified: [tui.sh]
key_decisions: []
duration: ~11 min
completed: 2026-05-24T06:13:26Z
---

# Phase 2 Plan 1: Checklist Widget & Key Reader Extensions — Summary

**One-liner:** Extends `tui.sh` key reader with Delete/Ctrl+D meta-keys, adds `_tui_read_char()` for raw input, and implements a full-screen `tui_checklist()` multi-select widget with `[x]`/`[ ]` checkboxes, select-all/deselect-all, and dual `stdout` + `TUI_RESULT` return semantics.

---

## Tasks Completed

### Task 1: Extend key reader with Ctrl+D, Delete, *, -, and `_tui_read_char()`

**Commit:** `60bef62`

Added four new key constants (`TUI_KEY_CTRL_D`, `TUI_KEY_DELETE`, `TUI_KEY_ASTERISK`, `TUI_KEY_MINUS`) to Section 7, wired up byte detection for Ctrl+D (0x04), `*` (0x2A), `-` (0x2D) in the `_tui_read_key()` dispatch, and added escape sequence `\033[3~` → `TUI_KEY_DELETE` handling. New `_tui_read_char()` function (Section 8a) provides raw byte reading for future text input widgets.

### Task 2: Implement `tui_checklist()` multi-select checkbox widget

**Commit:** `8b05200`

Built the complete checklist widget in three components:

- **`_tui_checklist_fallback()`** (Section 9a) — Numbered prompt for non-TTY environments. Lists items with `[x]`/`[ ]` marks, respects pre-selections, accepts space-separated numbers, outputs newline-separated 0-based indexes.

- **`_tui_render_checklist()`** (Section 11a) — Full-screen rendering helper mirroring `_tui_render_select()` exactly, with checkbox prefix (`[x]`/`[ ]`), reverse-video cursor highlight, `↑more`/`↓more` scroll indicators, and status line showing `N of M selected`.

- **`tui_checklist()`** (Section 12a) — Main widget with `--checked N1 N2 ...` parameter parsing, complete event loop dispatching on: `SPACE` (toggle), `Ctrl+D`/`ENTER` (confirm with zero-selection guard), `*` (select all), `-` (deselect all), `UP`/`DOWN`/`PGUP`/`PGDN`/`HOME`/`END` (navigation), `ESC`/`q` (cancel), `?` (toggle help footer). All `_tc_*` globals unset on every exit path. Demo mode via `sh tui.sh --demo-checklist`.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `_tc_rc` unset before `return` in fallback path**
- **Found during:** Task 2 testing
- **Issue:** `unset _tc_title ... _tc_rc` ran before `return $_tc_rc`, causing return code to always evaluate to the exit code of `unset` (0) instead of the fallback function's actual exit code. This caused fallback cancel (empty input) to incorrectly return exit 0.
- **Fix:** Saved `_tc_rc` to `_tc_ret` before the `unset` block, then `return $_tc_ret`.
- **Files modified:** `tui.sh` (line 1048)
- **Commit:** `8b05200` (squashed into task 2 commit)

**2. [Rule 1 - Bug] Added missing shellcheck SC2154 directives for eval-assigned variables**
- **Found during:** Task 2 shellcheck run
- **Issue:** Variables `_fbc_checked`, `_tc_cur`, `_tc_chk` assigned via `eval` triggered SC2154 ("referenced but not assigned").
- **Fix:** Added `# shellcheck disable=SC2154` on the usage lines after each eval assignment.
- **Files modified:** `tui.sh`
- **Commit:** `8b05200` (squashed into task 2 commit)

---

## Key Implementation Details

### Checklist Return Semantics (D-19, D-20, D-21)

- **Success (exit 0):** Prints newline-separated 0-based indexes of checked items to stdout. Sets `TUI_RESULT` to the count of selected items.
- **Cancel (exit 1):** Clears `TUI_RESULT`, prints nothing to stdout.
- **Zero-selection guard (D-21):** Ctrl+D or Enter with zero checked items shows `Select at least one item` in red on the status line, keeps the widget open.

### Checklist Rendering (D-04, D-05, D-08)

- `[x]` / `[ ]` classic square bracket checkboxes — no Unicode dependency.
- Only the `[x]` prefix distinguishes checked items; no additional color, dim, or highlight for checked state.
- Cursor item always gets full reverse-video highlight (`TUI_REV`) regardless of checked state, following `tui_select()` convention.
- Same full-screen bordered box layout as `tui_select()`: title, optional subtitle, separator, item list, status line, bottom border, footer.

### Key Reader Extensions

- **Ctrl+D (0x04):** Detected in single-byte branch via `$(printf '\004')` — no escape sequence needed. Used by checklist for Done confirmation and future text_input for EOF.
- **Delete (\033[3~):** Three-byte escape sequence detected in the `[`/`O` branch. Reads third byte, checks for `~`, maps to `TUI_KEY_DELETE`. Foundation for text_input field editing in Plan 02-03.
- **Asterisk (0x2A) / Minus (0x2D):** Single-byte printable characters mapped to `TUI_KEY_ASTERISK` and `TUI_KEY_MINUS` for select-all/deselect-all.

### POSIX Compliance

- Zero bashisms verified: no `[[ ]]`, no `echo -e`, no `$'\033'`, no `let`, no `==` inside `[ ]`.
- All `eval`-based variable storage uses `sed "s/'/'\\''/g"` sanitization (per T-02-03 mitigation).
- Escape sequences use `ESC=$(printf '\033')` pattern.
- `ShellCheck -s sh` exits 0 with zero errors/warnings.

---

## Verification

| Check | Result |
|-------|--------|
| `shellcheck -s sh tui.sh` | PASS (exit 0, no warnings) |
| `sh -n tui.sh` | PASS (valid syntax) |
| New key constants exist | PASS (TUI_KEY_CTRL_D, TUI_KEY_DELETE, TUI_KEY_ASTERISK, TUI_KEY_MINUS) |
| `_tui_read_char()` exists | PASS |
| `tui_checklist()` exists | PASS |
| `_tui_render_checklist()` exists | PASS |
| `[x]` / `[ ]` checkboxes | PASS (4 occurrences each: fallback + render) |
| "N of M selected" status line | PASS |
| `--demo-checklist` flag | PASS |
| Fallback numbered prompt | PASS (tested with pre-selections, valid input, cancel) |
| No bashisms | PASS |
| Threat mitigations | PASS (T-02-01: unknown bytes → UNKNOWN, T-02-02: single keypress per cycle, T-02-03: sed sanitization) |

---

## Self-Check: PASSED

- [x] `tui.sh` exists and reflects all changes
- [x] Commit `60bef62` exists (Task 1)
- [x] Commit `8b05200` exists (Task 2)
- [x] No file deletions in commits
- [x] ShellCheck clean
- [x] All acceptance criteria verified
