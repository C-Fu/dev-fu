---
phase: 01-tui-engine-core
plan: 02
subsystem: tui
tags: [posix, shell, terminal, ansi, menu, widget, single-select, navigation]

requires:
  - "Plan 01-01: tui_init(), tui_restore(), _tui_read_key(), _tui_fallback_prompt(), rendering primitives, key constants"
provides:
  - "tui_select() — full single-select menu widget with keyboard navigation and number jump"
  - "Full-screen box rendering with reverse-video highlight, scroll indicators, status line, help footer"
  - "Demo mode via --demo flag for standalone testing"
affects: [02-interactive-widgets, 03-menu-system, 05-integration]

tech-stack:
  added: []
  patterns:
    - "tui_select() source+function API: . tui.sh && tui_select title subtitle items..."
    - "Dual return: stdout (0-based index) + TUI_RESULT global + exit code 0/1"
    - "Indexed variable storage via eval with sed sanitization (POSIX-compatible)"
    - "Number jump accumulator with auto-timeout on non-digit key"
    - "Full-screen rendering with cursor positioning via move_cursor()"

key-files:
  created: []
  modified:
    - tui.sh

key-decisions:
  - "Footer placed outside the box (below bottom border) for cleaner visual separation"
  - "Number jump auto-flushes on any non-digit key instead of timer-based (simpler, more reliable)"
  - "Used case statement on $0 to guard demo mode against sourced execution"
  - "Status row at rows-3, bottom border at rows-2, footer at rows-1 for 24-row terminal"

patterns-established:
  - "Widget pattern: tui_select() stores items in _ts_label_N via eval, renders via _tui_render_select()"
  - "Event loop: while :; do render; read key; case dispatch; done — repeat for each widget"
  - "Demo mode guard: case ${0##*/} in tui.sh) ... ;; esac prevents execution when sourced"

requirements-completed: [ENGN-01, ENGN-02, ENGN-03, ENGN-04, ENGN-05, ENGN-06, ENGN-07, WDGT-04]

duration: 8min
completed: 2026-05-23
---

# Phase 1 Plan 02: Single-Select Menu Widget Summary

**Complete tui_select() widget with full-screen box rendering, keyboard navigation (arrows/vi/PgUp/PgDn/Home/End), reverse-video highlight, scroll indicators, number jump accumulator, and standalone demo mode**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-23T03:00:00Z
- **Completed:** 2026-05-23T03:08:00Z
- **Tasks:** 2
- **Files modified:** 1 (tui.sh)

## Accomplishments
- Full tui_select() widget with complete keyboard navigation (Up/Down, j/k, PgUp/PgDn, Home/End)
- Full-screen box rendering with centered title, optional subtitle, separator, reverse-video highlight
- Scroll indicators (↑more/↓more) that appear/disappear based on content overflow
- Number jump accumulator with auto-flush on non-digit key and visual feedback (Go to: N_)
- Status line showing item counter or error messages
- Help footer with ? toggle between minimal and full keybinding display
- Demo mode with 25 test items via `sh tui.sh --demo`
- Fallback numbered prompt when TERM=dumb or no TTY
- All 816 lines pass shellcheck -s sh with zero warnings/errors

## Task Commits

Each task was committed atomically:

1. **task 1: box rendering, item display, scroll indicators, and tui_select() structure** - `ac77ba0` (feat)
2. **task 2: navigation, number jump accumulator, dual return value, and demo mode** - `e1315dd` (feat)

## Files Created/Modified
- `tui.sh` - Added _tui_draw_box(), _tui_render_select(), complete tui_select() with event loop, and demo mode (447→816 lines)

## Decisions Made
- Footer placed outside the box (below bottom border) rather than inside — cleaner visual separation between content and controls
- Number jump auto-flushes on any non-digit keypress instead of timer-based approach — simpler and more reliable since _tui_read_key() blocks between keypresses
- Used `case "${0##*/}" in tui.sh)` to guard demo mode against accidental execution when sourced — avoids `exit 0` terminating the calling script

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
- Executor agent failed twice with empty returns — fell back to inline execution
- SC2154 shellcheck warning on eval-assigned _rs_lab variable — resolved with targeted disable directive

## Self-Check: PASSED

- FOUND: tui.sh (816 lines)
- SHELLCHECK: PASS (zero errors/warnings)
- ALL FUNCTIONS: PASS (tui_select, _tui_render_select, _tui_draw_box)
- NAVIGATION KEYS: PASS (Up/Down/PgUp/PgDn/Home/End/j/k all dispatched)
- SELECTION: PASS (Enter=exit 0+index, Esc/q=exit 1)
- NUMBER JUMP: PASS (accumulator, visual feedback, out-of-range error)
- DEMO MODE: PASS (sh tui.sh --demo runs 25-item menu)
- FALLBACK: PASS (TERM=dumb shows numbered prompt)
- NO BASHISMS: [[ ]]=0, echo -e=0, $'\033'=0, let=0, dd write flags=0
- TUI_RESULT: PASS (global set on selection)
- tui_restore: PASS (8 references, all exit paths covered)

---
*Phase: 01-tui-engine-core*
*Completed: 2026-05-23*
