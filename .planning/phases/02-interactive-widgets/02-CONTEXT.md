# Phase 2: Interactive Widgets - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Building four interactive widget functions in `tui.sh` — checklist (multi-select toggle), radio (single-select with dot indicators), yesno (confirmation dialog), text_input (freeform inline text entry) — all reusing Phase 1's terminal primitives, key reading, and rendering helpers. These become the widget toolkit for Phase 3 menus and Phase 4 module prompts.

**Scope anchor:** Widget functions only. No menu DSL, no module architecture, no orchestrator integration. The widgets are added to the existing `tui.sh` file alongside `tui_select()`.

</domain>

<decisions>
## Implementation Decisions

### Checklist interaction model
- **D-01:** SPACE toggles individual items. Ctrl+D confirms all selections (Done). Esc cancels and discards all changes.
- **D-02:** `*` = Select All, `-` = Deselect All (classic POSIX convention)
- **D-03:** Supports pre-selected items — caller passes initial checked indexes so the widget opens with some items already toggled on

### Checklist rendering style
- **D-04:** `[x]` / `[ ]` classic square bracket checkboxes — no Unicode dependency
- **D-05:** Only the `[x]` prefix distinguishes checked items from unchecked — no additional color, dim, or highlight treatment for checked items. The current cursor item always gets reverse-video highlight regardless.
- **D-06:** Status line: "N of M selected" (updates on every toggle)
- **D-07:** Default help footer: "Space=toggle, Ctrl+D=Done, Esc=Cancel, ?=More". `?` toggles full keybinding display.
- **D-08:** Same full-screen bordered box layout as `tui_select()` — title, optional subtitle, separator line, item list, status line, bottom border, footer

### Radio button visual & behavior
- **D-09:** `(•)` / `(○)` Unicode with `(*)` / `( )` ASCII fallback — auto-detect UTF-8 same as box-drawing chars in `tui.sh`
- **D-10:** Navigate with Up/Down arrows, SPACE to select/deselect, ENTER to confirm the selection, Esc to cancel
- **D-11:** Supports a pre-selected default index via caller parameter — that item starts with `(•)` when the widget opens

### Yes/No widget UX
- **D-12:** Full-screen box, self-contained modal dialog — consistent with other TUI widgets
- **D-13:** Left/Right arrows move highlight between Yes and No. ENTER confirms the highlighted choice. Esc cancels.
- **D-14:** "No" is pre-selected by default (safety-first for destructive operations)

### Text input widget UX
- **D-15:** Full-screen modal dialog with a centered input field — prompt label above, input below
- **D-16:** Full line editing: Backspace, Left/Right arrows, Home/End, Delete
- **D-17:** Reverse-video block cursor in the input field — same `\033[7m` style as `tui_select()` highlight
- **D-18:** ENTER confirms with current input (even if empty), Esc cancels — caller handles validation

### Widget return value conventions
- **D-19:** All widgets follow the same dual-return pattern: result printed to stdout + TUI_RESULT global set + exit code 0 (success) / 1 (cancelled)
- **D-20:** Checklist returns newline-separated 0-based indexes (one per line, suitable for `while read` consumption)
- **D-21:** Zero selections + Ctrl+D shows error message in status line, stays in checklist. User must select at least one item or Esc to cancel.
- **D-22:** Yes/No returns literal `'yes'` or `'no'` string to stdout and TUI_RESULT
- **D-23:** Text input returns the typed string. Radio returns the selected 0-based index.

### OpenCode's Discretion
- Exact function signatures (parameter ordering, how pre-selected items / default indexes are passed)
- Color/styling for checkbox and radio glyph rendering
- Exact modal dialog dimensions and layout for yesno and text_input
- Error message wording for "at least one item required" and other validation messages
- Visual flash behavior when pressing `*` to select all
- Demo mode for each widget (extending `tui.sh --demo` pattern)
- Internal helper naming within `_tui_*` namespace
- How the help footer collapse/expand interaction works for each widget
- Terminal state restoration edge cases (e.g., widget called without `tui_init()`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 2 goal, success criteria, requirements mapping (WDGT-01 through WDGT-06)
- `.planning/REQUIREMENTS.md` — WDGT-01 (Space toggle), WDGT-02 (Select/Deselect All), WDGT-03 (Yes/No confirmation), WDGT-05 (radio single-select), WDGT-06 (text input)
- `.planning/PROJECT.md` — POSIX compliance, zero-dependency, pure ANSI/ASCII constraints, Key Decisions table

### Phase 1 foundation (MUST read)
- `tui.sh` — The existing TUI engine (761 lines). All Phase 2 widgets build on: `tui_init()` / `tui_restore()`, `_tui_read_key()` / `_tui_read_byte()`, `_tui_render_select()`, `_tui_draw_box()`, `move_cursor()`, `clear_screen()`, `_tui_fallback_prompt()`, box-drawing auto-detection, color constants, shell-aware input, number jump accumulator
- `.planning/phases/01-tui-engine-core/01-CONTEXT.md` — Phase 1 decisions: `tui_` prefix (D-04), source+function-call API (D-02), single file `tui.sh` (D-01), shell-aware hybrid input (D-09), full-screen box rendering (D-13), help footer (D-16), number jump UX (D-20-22)

### Pattern reference
- `checklist.sh` (596 lines) — Existing POSIX multi-select checklist widget. Reference for: term_init/term_restore pattern, `[x]`/`[ ]` checkbox rendering, fallback numbered prompt, Fish shell support. Do NOT copy — write fresh code using `tui.sh` primitives. This file remains untouched.

### Constraints
- `.planning/codebase/CONCERNS.md` — Known POSIX anti-patterns to avoid: `$'\033'` (use `printf`), `echo -e` (use `printf`), `sed '\x1b'` (use `printf` substitution), missing QUIT signal trap
- `.planning/codebase/CONVENTIONS.md` — Naming conventions: `snake_case` functions, `_` prefix for internal helpers, `UPPER_SNAKE_CASE` for global constants

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tui.sh` — Full engine: `tui_init()` / `tui_restore()` (terminal state, signal traps, hide/show cursor), `_tui_read_key()` (shell-aware escape sequence parsing, sets `_tui_rk_result`), `_tui_render_select()` (full-screen box, item list with reverse-video highlight, scroll indicators, footer), `_tui_draw_box()` (bordered box primitive), `move_cursor()` / `clear_screen()` (ANSI cursor movement), `_tui_fallback_prompt()` (numbered prompt for dumb terminals), color/style constants (TUI_REV, TUI_DIM, TUI_RED, TUI_GREEN, etc.), box-drawing auto-detection
- `tui.sh:_tui_read_key()` already parses SPACE (`TUI_KEY_SPACE`), TAB (`TUI_KEY_TAB`), BACKSPACE (`TUI_KEY_BACKSPACE`), ENTER, ESC, arrows, PgUp/PgDn, Home/End, digits, and `?` — all key names needed by Phase 2 widgets are available
- `tui.sh:tui_select()` pattern: assign items to `eval _ts_label_N`, render loop calls `_tui_render_select` then `_tui_read_key`, case dispatch on key name, return via stdout + TUI_RESULT + exit code

### Established Patterns
- Numbered item list with reverse-video highlight (from `tui_select`)
- Dual return: stdout + TUI_RESULT + exit code (D-05 from Phase 1)
- `?` key toggles help footer between minimal and full keybinding display
- Status line at bottom of box: context-sensitive (shows "Item N of M" or "Go to: N_")
- Scroll indicators (`↑more` / `↓more`) when content overflows
- `stty min 0 time N` for multi-byte escape sequence timeout
- Fallback numbered prompt when no TTY available

### Integration Points
- Phase 3 (Menu System) will call checklist, radio, and yesno widgets for menu navigation and option selection
- Phase 4 (Module Architecture) will call text_input, radio, and yesno for inline parameter collection before module execution
- Phase 5 (Integration) will wire all widgets into the `flu.sh` orchestrator
- All widgets coexist in `tui.sh` alongside `tui_select()` — no separate source files

### Patterns to Maintain
- POSIX sh compatibility: no bashisms, every line passes `shellcheck -s sh`
- Pure ANSI/ASCII rendering (except auto-detected Unicode box/radio chars with fallback)
- Zero external dependencies (no `dialog`, `whiptail`, `ncurses`)
- `/dev/tty` explicit reads for keyboard input
- Signal-safe cleanup via `tui_restore()` in traps

</code_context>

<specifics>
## Specific Ideas

- The checklist should feel like the classic POSIX `[x]`/`[ ]` pattern — familiar to anyone who's used `aptitude` or `menuconfig`
- Radio buttons should visually echo TUI dialog conventions — the `(•)`/`(○)` is iconic and worth the Unicode auto-detection
- Each widget should feel like it belongs in the same family as `tui_select()` — same box framing, same footer, same keyboard muscle memory
- The yesno dialog is explicitly a safety mechanism — "No" defaults protect against accidental destructive operations

</specifics>

<deferred>
## Deferred Ideas

- Substring search/filter in checklist and radio lists — Phase 2 enhancement, tracked as ENGN-11 (v2)
- Terminal resize handling (SIGWINCH) — ENGN-10 (v2)
- Color themes via FLU_THEME env var — INTG-07 (v2)
- Contextual description panel below cursor item — INTG-09 (v2)

None raised during discussion.

</deferred>

---

*Phase: 02-interactive-widgets*
*Context gathered: 2026-05-24*
