---
phase: 16-tui-engine
plan: 02
subsystem: tui
tags: [ratatui, widgets, select, checklist, radio, yesno, text-input, tui]

# Dependency graph
requires:
  - phase: 16-tui-engine plan 01
    provides: TerminalGuard RAII, Theme, Key enum, read_key, demo CLI flags
provides:
  - Select widget (single-select list with vim keys, go-to, help toggle, ratatui scrolling)
  - Checklist widget (multi-select with checkboxes, select-all/deselect-all, pre-checked items)
  - Radio widget (single-select with ●/○ indicators, default selection)
  - YesNo widget (centered modal dialog with Clear, Left/Right toggle)
  - TextInput widget (centered modal with inline editing, cursor, max_len=256)
  - Demo dispatch wiring all 5 flags to actual widget invocations
affects: [17-menu-system]

# Tech tracking
tech-stack:
  added: []
  patterns: [widget function API per D-08, struct-per-widget state per D-06, ratatui ListState scrolling per D-11, centered modal with Clear widget]

key-files:
  created:
    - fust/src/tui/widgets/mod.rs
    - fust/src/tui/widgets/select.rs
    - fust/src/tui/widgets/radio.rs
    - fust/src/tui/widgets/checklist.rs
    - fust/src/tui/widgets/yesno.rs
    - fust/src/tui/widgets/text_input.rs
  modified:
    - fust/src/tui/mod.rs
    - fust/src/main.rs
    - fust/src/tui/theme.rs

key-decisions:
  - "Manual item styling over ListState highlight — full control over per-item colors with theme"
  - "Option<usize> for radio selected state — None means no selection yet, matches tui.sh _tr_selected=0 semantics"
  - "Text input: only Esc cancels, not 'q' — user might type 'q' as input character"
  - "BoxChars::from_locale() pure function — eliminates env var race condition in parallel tests"
  - "Checklist requires ≥1 selection on confirm (matching tui.sh) — empty confirm shows error"

patterns-established:
  - "Widget function signature: fn(terminal, theme, title, ...) -> Result<T> per D-08"
  - "Widget state struct with cursor, scroll, show_help, go_digits, error_msg, page_size"
  - "Go-to number key accumulation with auto-jump when next*10 > count (per D-09)"
  - "Centered modal pattern: Clear widget + Block + inner margin for yesno/text_input"
  - "Footer text: compact by default, extended when show_help=true (per D-10)"

requirements-completed: []

# Metrics
duration: 9min
completed: 2026-06-11
---

# Phase 16 Plan 02: Interactive Widgets Summary

**5 interactive TUI widgets (select, checklist, radio, yesno, text_input) using ratatui List/Block/Paragraph/Clear, with vim keys, go-to number jump, help toggle, and demo dispatch wiring**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-11T08:46:12Z
- **Completed:** 2026-06-11T08:55:08Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Select widget: single-select list with vim navigation (j/k/g/G), number-key go-to (D-09), help toggle (D-10), ratatui ListState scrolling (D-11), wrapping cursor
- Checklist widget: multi-select with [x]/[ ] checkboxes, Space toggle, * select-all, - deselect-all, pre-checked items, selection count display
- Radio widget: single-select with (●)/(○) indicators, Space to select, default parameter, same navigation as select
- YesNo widget: centered modal with Clear background, Left/Right/Tab toggle, y/n shortcuts, default parameter
- TextInput widget: centered modal with inline editing, cursor movement (Left/Right/Home/End), Backspace/Delete, reverse-video block cursor, max_len=256 (T-16-06)
- Demo dispatch: all 5 flags (--demo-select/checklist/radio/yesno/text-input) launch working interactive widgets with sample data
- 47 tests pass (25 new widget tests + 22 existing from prior phases)

## Task Commits

Each task was committed atomically:

1. **Task 1: Select + Radio widgets** - `1fad3bf` (feat)
2. **Task 2: Checklist + YesNo + TextInput widgets + demo dispatch** - `066b872` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified
- `fust/src/tui/widgets/mod.rs` - Widget module root with pub mod declarations for all 5 widgets
- `fust/src/tui/widgets/select.rs` - Single-select list widget (270 lines): SelectState, vim keys, go-to, help toggle, ratatui List/ListState rendering
- `fust/src/tui/widgets/radio.rs` - Single-select radio widget (260 lines): RadioState with Option<usize> selected, (●)/(○) indicators, default parameter
- `fust/src/tui/widgets/checklist.rs` - Multi-select checklist widget (290 lines): ChecklistState with Vec<bool> checked, * select-all, - deselect-all, pre-checked items
- `fust/src/tui/widgets/yesno.rs` - Yes/No confirmation dialog (150 lines): centered modal with Clear, Left/Right toggle, y/n shortcuts
- `fust/src/tui/widgets/text_input.rs` - Freeform text input (210 lines): centered modal, inline cursor, Backspace/Delete, max_len=256, only Esc cancels
- `fust/src/tui/mod.rs` - Added `pub mod widgets` declaration
- `fust/src/main.rs` - Replaced placeholder demo with actual widget invocations for all 5 demo flags
- `fust/src/tui/theme.rs` - Extracted BoxChars::from_locale() pure function to fix test race condition

## Decisions Made
- Used manual item styling (per-item Span styles) instead of ratatui's ListState highlight_style — gives full control over selected/unselected colors matching the theme
- Radio widget uses `Option<usize>` for selected state — `None` means nothing selected yet (matching tui.sh's `_tr_selected=0` sentinel), `Some(idx)` after Space
- Text input only allows Esc to cancel, not 'q' — user might want to type the letter 'q' in the input field
- Checklist requires at least 1 selection on Enter/Ctrl-D confirm (matching tui.sh behavior) — shows error "Select at least one item" if none selected
- Refactored BoxChars::detect() to use pure `from_locale(&str)` helper — eliminates parallel test race condition on shared env vars

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ratatui 0.29 API differences**
- **Found during:** task 1 (cargo build)
- **Issue:** `ratatui::terminal::Terminal` is private in ratatui 0.29 (re-exported at `ratatui::Terminal`); `ListState::set_offset()` doesn't exist; `Modifier::REVERSE` is actually `Modifier::REVERSED`
- **Fix:** Changed import to `ratatui::Terminal`; removed `set_offset()` call (ratatui handles scroll automatically via `select()`); changed `REVERSE` to `REVERSED`
- **Files modified:** fust/src/tui/widgets/select.rs, fust/src/tui/widgets/radio.rs, fust/src/tui/widgets/text_input.rs
- **Committed in:** 1fad3bf (task 1) and 066b872 (task 2)

**2. [Rule 1 - Bug] Fixed parallel test race condition in theme tests**
- **Found during:** task 2 (cargo test)
- **Issue:** `box_chars_utf8` and `box_chars_ascii` tests both modify shared env vars (LANG, LC_ALL, LC_CTYPE) and run in parallel, causing intermittent failures
- **Fix:** Extracted `BoxChars::from_locale(&str)` pure function; tests now call it directly with locale strings instead of mutating env vars
- **Files modified:** fust/src/tui/theme.rs
- **Committed in:** 066b872 (task 2)

---

**Total deviations:** 2 auto-fixed (2 bug fixes)
**Impact on plan:** Both fixes necessary for compilation/test correctness. No scope creep, no behavior changes.

## Issues Encountered
None beyond the auto-fixed issues above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 5 interactive widgets complete with full keyboard navigation, go-to, and help toggle
- Demo dispatch provides end-to-end verification of each widget
- 47 tests pass including 25 new widget tests
- Ready for Phase 17 (Menu System) — widgets provide the building blocks for menu navigation
- `fust --demo-select/checklist/radio/yesno/text-input` all launch working interactive widgets

---
*Phase: 16-tui-engine*
*Completed: 2026-06-11*

## Self-Check: PASSED

All 9 files exist, both commits verified (1fad3bf, 066b872), all 47 tests pass, cargo build exits 0.
