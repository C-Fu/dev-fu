---
phase: 02-interactive-widgets
plan: 03
type: execute
subsystem: TUI Engine
tags: [tui, text-input, text-entry, widget, line-editing]
requires: [02-01]
provides: [tui_text_input, _ti_render, _ti_insert_char, _ti_delete_char, _ti_backspace_char]
affects: [tui.sh]
tech-stack:
  added: []
  patterns: [eval-based-indexed-storage, full-screen-box-rendering, event-loop-with-raw-byte-dispatch, dual-return-stdout-TUI_RESULT, fallback-read-prompt, centered-modal-dialog, awk-substr-string-manipulation, reverse-video-block-cursor]
key-files:
  created: []
  modified: [tui.sh]
key_decisions:
  - "Uses _tui_read_char() raw byte reading instead of _tui_read_key to avoid jinx key conflicts (j/k/q/g/G mapped to navigation in _tui_read_key)"
  - "Self-contained escape sequence parser for arrow keys, Home, End, Delete in the event loop"
  - "Cursor initialized at end of default value (if provided) for better UX — plan used 0 but ${#_ti_value} is more natural"
  - "Render prompt on first body row (y+3) instead of separator row (y+2) for cleaner visual layout"
duration: ~3 min
completed: 2026-05-24T06:33:01Z
---

# Phase 2 Plan 3: Text Input Widget — Summary

**One-liner:** Implements `tui_text_input()` — a full-screen centered modal text entry widget with inline line editing (Backspace, Delete, Left/Right, Home/End), reverse-video block cursor, horizontal scroll, Enter-confirms/Esc-cancels pattern, and non-TTY fallback prompt.

---

## Tasks Completed

### Task 1: Implement `_tui_render_text_input()` rendering helper and `tui_text_input()` widget

**Commit:** `4263272`

Built the complete text input widget as a single cohesive unit (~294 lines) in `tui.sh` Section 15:

- **`tui_text_input()`** — Main widget function accepting `title`, `prompt`, and optional `default_value`. Initializes all `_ti_*` state variables, defines nested helpers, and runs the event loop. Follows the established dual-return pattern: stdout + TUI_RESULT + exit 0 (Enter) / exit 1 (Esc).

- **`_ti_cursor_left()` / `_ti_cursor_right()`** — Cursor position helpers. `_ti_cursor` ranges from 0 (before first char) to `${#_ti_value}` (after last char). Bounds-checked on every move.

- **`_ti_insert_char()`** — Inserts a character at cursor position using POSIX `awk substr` for string slicing (no bash `${var:0:1}` substring syntax). Handles three cases: cursor at start (prepend), cursor at end (append), cursor in middle (split and join).

- **`_ti_delete_char()`** — Forward delete: removes the character at cursor position. `awk substr` to extract `_ti_left` (chars before cursor) and `_ti_right` (chars after cursor+1), then concatenate.

- **`_ti_backspace_char()`** — Backwards delete: moves cursor left one position, then deletes the character that was before the original cursor using the same split-and-join technique as `_ti_delete_char()`.

- **`_ti_fallback()`** — Non-TTY fallback using simple `read` prompt. Shows title, prompt, optional default value, and `>` input prompt. If user enters empty string and a default exists, uses the default. Returns string via stdout + TUI_RESULT.

- **`_ti_render()`** — Full-screen rendering helper. Uses `_tui_draw_box()` for the centered modal frame (60×7 default, clamped to terminal size). Overlays:
  - **Prompt label** on first body row (y+3), centered within the box
  - **Input field** on third body row (y+5) with border `V` on both sides
  - **Visible portion** of text buffer with horizontal scrolling (keeps cursor in view when text exceeds input width)
  - **Reverse-video block cursor**: character at cursor position rendered with `TUI_REV`; if cursor is past all characters, shows a reverse-video space
  - **Footer** on the bottom border row with dimmed keybinding hints (condensed/expanded via `?` toggle)

- **Event loop** — Uses `_tui_read_char()` for raw byte reading (not `_tui_read_key`) to avoid the jinx key conflict where `j`/`k`/`q`/`g`/`G` are mapped to navigation keys. Self-contained escape sequence parser handles:
  - `\033[C` → cursor right (Right arrow)
  - `\033[D` → cursor left (Left arrow)
  - `\033[H` → cursor=0 (Home)
  - `\033[F` → cursor=end (End)
  - `\033[3~` → forward delete (Delete key)
  - `\033[1~` → cursor=0 (Home alternate)
  - `\033[4~` → cursor=end (End alternate)
  - Plain `\033` with timeout → Esc (cancel)
  
  Printable ASCII (0x20-0x7E) inserted at cursor position via `_ti_insert_char()`. Control chars (Tab, Ctrl+D) ignored. `?` toggles help footer.

- **Demo mode** — `sh tui.sh --demo-text-input` runs standalone demo. Optional default value: `sh tui.sh --demo-text-input "pre-filled text"`. Prints entered text or "Cancelled" on Esc.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Jinx key conflict: single-byte characters mapped to navigation**

- **Found during:** Implementation planning
- **Issue:** The plan's event loop used `_tui_read_key`, which maps single characters `j`/`k`/`q`/`g`/`G` to `TUI_KEY_UP`/`DOWN`/`Q`/`HOME`/`END` for vi-style navigation. In a text input widget, these characters must be typable as literal text, not interpreted as navigation. The plan's `TUI_KEY_UNKNOWN` + `_tui_rb_byte` check wouldn't handle them because they're caught by explicit case branches before falling through to `TUI_KEY_UNKNOWN`.
- **Fix:** Switched to `_tui_read_char()` for raw byte reading with a self-contained escape sequence parser for the navigation keys (arrow keys, Home, End, Delete). This correctly types all printable ASCII characters while still supporting real arrow key escape sequences. This aligns with the plan's own objective which says "Uses `_tui_read_char()` from Plan 02-01 for character-by-character input."
- **Files modified:** `tui.sh` (event loop in `tui_text_input()`)
- **Commit:** `4263272`

**2. [Rule 1 - Bug] Digits mapped to TUI_KEY_NUMBER would be ignored**

- **Found during:** Implementation planning
- **Issue:** The plan's event loop only handled `TUI_KEY_UNKNOWN` for printable character insertion, but digits `[0-9]` are mapped to `TUI_KEY_NUMBER` by `_tui_read_key`, so they'd fall through to the `*` catch-all and be silently ignored.
- **Fix:** Resolved by the same `_tui_read_char()` approach — digits are read as raw bytes and correctly identified as printable ASCII (0x30-0x39) in the `*` case branch.
- **Files modified:** `tui.sh` (event loop in `tui_text_input()`)
- **Commit:** `4263272`

**3. [Rule 1 - Bug] Render prompt row collision with separator**

- **Found during:** Implementation planning
- **Issue:** The plan placed the prompt label on row `_ti_y + 2`, which is the separator line drawn by `_tui_draw_box()` (renders `V + H...H + V`). Overwriting it with prompt text would leave partial separator hash marks visible.
- **Fix:** Moved prompt to first body row (`_ti_y + 3`) for clean rendering. Input field on row `_ti_y + 5` (third body row).
- **Files modified:** `tui.sh` (`_ti_render()` function)
- **Commit:** `4263272`

**4. [Rule 2 - Missing functionality] Default value cursor position**

- **Found during:** Implementation planning
- **Issue:** The plan set `_ti_cursor=0` unconditionally. When a default value is provided (e.g., `tui_text_input "Edit" "Value:" "existing text"`), the cursor should be at the end of the default text so the user can immediately append or edit from a natural position.
- **Fix:** Initialize `_ti_cursor=${#_ti_value}` (cursor at end of default value if one is provided).
- **Files modified:** `tui.sh` (`tui_text_input()` initialization)
- **Commit:** `4263272`

**5. [Deviation - ShellCheck] SC2181 indirect exit code check**

- **Found during:** ShellCheck validation
- **Issue:** The fallback function used `$?` indirectly after a chained `read || read` expression, triggering SC2181.
- **Fix:** Captured the exit code explicitly: `_ti_rc=0; IFS= read ... || { IFS= read; _ti_rc=$?; }` then checked `"$_ti_rc" -ne 0`.
- **Files modified:** `tui.sh` (`_ti_fallback()` function)
- **Commit:** `4263272`

---

## Key Implementation Details

### Raw Byte Event Loop Architecture

Rather than using `_tui_read_key` (which pre-canonicalizes every keystroke to a symbolic name, including vi-style mappings for single characters), the text input widget reads raw bytes via `_tui_read_char()` and implements its own escape sequence parser. This ensures:

- **All printable ASCII (0x20-0x7E) is typable** — including `j`, `k`, `q`, `g`, `G`, digits, punctuation
- **Real arrow keys work correctly** — `\033[C`/`\033[D` for Left/Right, `\033[H`/`\033[F` for Home/End
- **Delete key detection** — `\033[3~` for forward delete
- **Esc timeout handling** — After reading `\033`, sets `stty min 0 time 10` for 1-second timeout. If no subsequent byte arrives, it's a plain Esc (cancel). If `[` or `O` follows, parses the escape sequence.

### String Manipulation (POSIX sh)

All string operations use `awk substr` to avoid bash-specific substring syntax (`${var:offset:length}`):

- **Insert at cursor:** Split into `_ti_left` (substr 1 to cursor) and `_ti_right` (substr cursor+1 to end), concatenate with new char between
- **Delete at cursor:** Same split but skip one position in `_ti_right` (start at cursor+2)
- **Backspace:** Decrement cursor first, then same split-and-skip logic
- **Horizontal scroll:** Calculate `_ti_input_start` based on cursor position relative to visible width, extract visible portion via `substr`

### Rendering

- **Box:** `_tui_draw_box` with width 60, height 7, centered on screen. Clamped to terminal size.
- **Prompt:** Centered text on first body row (y+3), truncated to inner box width
- **Input field:** Third body row (y+5), bordered by `TUI_BOX_V` on both sides
- **Cursor:** Reverse-video (`TUI_REV`) character at cursor position when cursor is on a character; reverse-video space when cursor is past end
- **Scroll:** When text exceeds input width, `_ti_input_start` shifts to keep cursor in the visible window
- **Footer:** Dimmed text on bottom border row, toggles between compact and full help via `?`

### Return Value Conventions (D-19, D-23)

- **Success (exit 0):** Types string printed to stdout + set in `TUI_RESULT`
- **Cancel (exit 1):** `TUI_RESULT=''`, no stdout output
- **Fallback (exit 0):** Same return pattern; empty input with default uses the default value

### POSIX Compliance

- Zero bashisms: no `[[ ]]`, no `echo -e`, no `$'\033'`, no `${var:0:1}`, no `let`
- All escape sequences use `ESC=$(printf '\033')` pattern
- String manipulation uses `awk substr` exclusively
- `sh -n tui.sh` and `shellcheck -s sh tui.sh` both pass with zero errors/warnings
- Cursor movement helpers use POSIX arithmetic: `$((_ti_cursor - 1))`

---

## Verification

| Check | Result |
|-------|--------|
| `shellcheck -s sh tui.sh` | PASS (exit 0, no warnings) |
| `sh -n tui.sh` | PASS (valid syntax) |
| `tui_text_input()` exists | PASS (1 function definition) |
| `_ti_render()` exists | PASS (rendering helper) |
| `_ti_insert_char()` exists | PASS (char insertion) |
| `_ti_delete_char()` exists | PASS (forward delete) |
| `_ti_backspace_char()` exists | PASS (backspace delete) |
| `--demo-text-input` flag | PASS |
| Full-screen centered modal | PASS (60×7 box, centered) |
| Reverse-video block cursor | PASS (TUI_REV char at cursor) |
| Backspace editing | PASS |
| Delete editing | PASS |
| Left/Right cursor arrows | PASS (escape seq parse) |
| Home/End boundary jumps | PASS (escape seq parse) |
| Enter confirms (even empty) | PASS |
| Esc cancels (exit 1) | PASS |
| Horizontal scroll | PASS (cursor tracking) |
| Max 256 chars enforced | PASS |
| Printable ASCII insertion | PASS (0x20-0x7E) |
| Non-printable chars ignored | PASS |
| Fallback non-TTY prompt | PASS |
| stdout + TUI_RESULT return | PASS |
| Variable cleanup on exit | PASS (all _ti_* unset) |
| No bashisms | PASS |
| Threat mitigations | PASS (T-02-07, T-02-08, T-02-09) |

---

## Self-Check: PASSED

- [x] `tui.sh` exists and reflects all changes (2144 lines, +294 from prior)
- [x] Commit `4263272` exists (Text input widget implementation)
- [x] No file deletions in commit
- [x] ShellCheck clean (zero errors/warnings)
- [x] All acceptance criteria verified
- [x] No stubs found in new code
- [x] No new threat surface beyond documented threat model
