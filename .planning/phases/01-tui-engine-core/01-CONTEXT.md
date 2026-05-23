# Phase 1: TUI Engine Core - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Portable POSIX terminal primitives, keyboard input handling, and single-select menu widget. The engine renders interactive menus with keyboard navigation (arrows, vi keys, PgUp/PgDn, Home/End, number jumping), reverse-video highlight, scroll indicators, help footer, and fallback numbered prompt — working identically across bash, zsh, dash, ash, and busybox sh.

**Scope anchor:** Terminal primitives + input system + single-select widget only. Additional widgets (checklist, radio, yes/no, text input) are Phase 2. Menu DSL and navigation are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Engine File Structure
- **D-01:** Single file `tui.sh` at repo root — all TUI engine code (primitives, input, rendering, single-select widget) in one file. Phase 2 will add more widgets to the same file.
- **D-02:** Source + function call API — downstream scripts `source tui.sh` then call `tui_select()` directly. No CLI flag parsing.
- **D-03:** Fresh code — new file written from scratch. `checklist.sh` serves as pattern reference only (not copied, not refactored). `checklist.sh` remains untouched and independent.
- **D-04:** `tui_` prefix for all public function names: `tui_init()`, `tui_restore()`, `tui_select()`, `_tui_*` for internal helpers.
- **D-05:** Dual return value — `tui_select()` prints selected 0-based index to stdout AND sets `TUI_RESULT` global variable. Exit code 0 = selected, 1 = cancelled.
- **D-06:** Engine registers its own signal traps in `tui_init()` for INT, TERM, HUP, QUIT — each calls `tui_restore()` then exits. Callers don't need to manage terminal cleanup.
- **D-07:** Reads keyboard input from `/dev/tty` explicitly (not stdin). `tui_init()` checks `/dev/tty` availability and auto-switches to fallback numbered prompt when unavailable.
- **D-08:** `checklist.sh` remains untouched — `tui.sh` is a separate, independent engine.

### Key Reading Strategy
- **D-09:** Shell-aware hybrid input — bash/zsh use built-in `read -rsn1` (no process spawn, fast), dash/ash/busybox use `dd bs=N count=N` from `/dev/tty` (portable, spawns process per keypress).
- **D-10:** Hard constraint: `dd` usage is read-only only. No `dd` invocations with `of=`, `seek=`, or `conv=` flags. Only `dd bs=N count=N` reading from `/dev/tty`.
- **D-11:** Timed multi-byte read for escape sequence parsing — after reading ESC byte, try reading continuation bytes with short timeout. If timeout fires, treat as bare Esc keypress.
- **D-12:** Configurable inter-byte timeout via `TUI_KEY_TIMEOUT` environment variable. Default 100ms. User can increase for high-latency SSH connections.

### Single-select Visual Style
- **D-13:** Full-screen box rendering — `tui_select()` clears screen, draws bordered box with title, item list, status line, and help footer. Professional lxdialog-like appearance.
- **D-14:** Numbered items with reverse-video (`\033[7m`) highlight on current item. Unselected items show dimmed number prefix.
- **D-15:** Auto-detect Unicode box drawing characters — try Unicode (┌─┐│└─┘), fall back to ASCII (+ - |) if locale doesn't support UTF-8.
- **D-16:** Minimal help footer showing primary keys (↑↓ Move, Enter Select, Esc Cancel). Press `?` to toggle full keybinding display.
- **D-17:** Title centered on first line inside box, optional subtitle below, then separator line (`---`) before item list.
- **D-18:** `↑more` / `↓more` scroll indicators when item content overflows visible area (per ENGN-04). Dim/styled to not distract. Disappear when not needed.
- **D-19:** Item counter in status line between items and footer — shows "Item N of M". Updates as cursor moves.

### Number Jump UX
- **D-20:** Auto-timeout digit accumulator for number jumping (ENGN-07). Each digit waits `TUI_KEY_TIMEOUT`. If another digit arrives, accumulate. If timeout fires, jump to accumulated number.
- **D-21:** Visual feedback — while typing digits, status line shows "Go to: N_" (replaces "Item N of M" temporarily). User sees what they've typed.
- **D-22:** Out-of-range handling — flash error message "Item N not found" in status line, clear accumulator, return to normal navigation. Non-disruptive.

### OpenCode's Discretion
- Internal variable naming within `_tui_*` functions
- Exact section ordering within `tui.sh` (follow checklist.sh convention: terminal helpers → input → rendering → widget)
- Exact escape sequence mapping (arrow keys, PgUp/PgDn, Home/End byte sequences)
- Color palette for dim text, scroll indicators, error flash
- Exact rendering implementation (cursor positioning, screen redraw strategy)
- Fallback numbered prompt format and behavior
- Shell detection method in `tui_init()`

</decisions>

<specifics>
## Specific Ideas

- `tui.sh` should feel like a clean-room lxdialog — professional, responsive, but pure shell
- The `checklist.sh` pattern of `source` + function call is proven and should be followed closely
- The inter-byte timeout must work reliably over SSH — this is a known concern from STATE.md

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, requirements mapping
- `.planning/REQUIREMENTS.md` — ENGN-01 through ENGN-08, WDGT-04, INTG-03, INTG-04 (Phase 1 requirements)

### Pattern reference
- `checklist.sh` — Existing POSIX TUI widget (596 lines). Reference for: term_init/term_restore pattern, dd-based key reading, fallback mode, rendering approach. Do NOT copy — write fresh code.

### Project context
- `.planning/PROJECT.md` — POSIX compliance constraint, zero-dependency constraint, pure ANSI/ASCII constraint
- `.planning/STATE.md` — Known POSIX portability risks, SSH timing concerns with dd-based key reading
- `.planning/codebase/CONCERNS.md` — Known bugs in checklist.sh to avoid (str_len sed \x1b, echo -e, $'\033' bashisms)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `checklist.sh` (596 lines): Proven POSIX TUI widget with `term_init()`/`term_restore()` pattern, `read_key()` using dd, `move_cursor()`/`clear_screen()` helpers, fallback numbered prompt, embedded Fish shell support. Pattern reference only — do not copy.
- `fu.sh` (2629 lines): Platform detection, color constants, box-drawing characters — reference for color palette and box-drawing approach.

### Established Patterns
- `source` + function call for embedding widgets (from `checklist.sh`)
- Signal trap registration in init function (from `checklist.sh` — but missing QUIT, which must be fixed)
- `dd bs=1 count=1 2>/dev/null </dev/tty` for portable single-byte reads
- `stty -g` save / `stty $saved` restore for terminal state management
- `\033[7m` reverse-video for highlight (from fu.sh color palette)

### Integration Points
- Phase 2 will add `checklist()`, `radio()`, `yesno()`, `text_input()` widgets to the same `tui.sh` file — these will reuse `tui_init()`, `tui_restore()`, and internal rendering helpers
- Phase 3 menu system will `source tui.sh` and call `tui_select()` for menu navigation
- Phase 5 `flu.sh` orchestrator will `source tui.sh` as the TUI foundation

### Patterns to Avoid (from CONCERNS.md)
- `$'\033'` — Bashism, not POSIX. Use `$(printf '\033')` instead.
- `echo -e` — Not POSIX portable. Use `printf` instead.
- `sed '\x1b'` — Not portable to BusyBox/BSD sed. Use `$(printf '\033')` substitution.
- Missing QUIT in signal traps — checklist.sh only traps INT, TERM, HUP. Must add QUIT.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-tui-engine-core*
*Context gathered: 2026-05-23*
