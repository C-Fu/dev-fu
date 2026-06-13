---
phase: 16-tui-engine
plan: 01
subsystem: tui
tags: [ratatui, crossterm, signal-hook, terminal, raii, tui]

# Dependency graph
requires:
  - phase: 15-rust-scaffold
    provides: Cargo project structure, cli.rs, main.rs, platform.rs
provides:
  - TerminalGuard RAII with panic hook and signal handlers
  - Theme struct with dark default colors and BoxChars locale detection
  - Keyboard input mapping (crossterm to symbolic Key enum)
  - 5 demo CLI flags for widget testing
  - TUI module structure (tui/terminal.rs, tui/theme.rs, tui/input.rs)
affects: [16-02-widgets, 17-menu-system]

# Tech tracking
tech-stack:
  added: [ratatui 0.29, crossterm 0.28, signal-hook 0.3]
  patterns: [RAII terminal guard, locale-based box char detection, symbolic key enum]

key-files:
  created:
    - fust/src/tui/mod.rs
    - fust/src/tui/terminal.rs
    - fust/src/tui/theme.rs
    - fust/src/tui/input.rs
  modified:
    - fust/Cargo.toml
    - fust/Cargo.lock
    - fust/src/cli.rs
    - fust/src/main.rs

key-decisions:
  - "ratatui 0.29 with crossterm backend for TUI rendering (D-01, D-02)"
  - "signal-hook for SIGINT/SIGTERM/SIGHUP terminal restore (D-14)"
  - "Locale detection via LANG/LC_ALL/LC_CTYPE for UTF-8 box chars (D-12)"
  - "Terminal::size() returns Rect (not Size) for ratatui rendering compatibility"
  - "signal_hook::low_level::register wrapped in unsafe block (required by API)"

patterns-established:
  - "RAII guard pattern: TerminalGuard with Drop for terminal restore"
  - "Module layout: tui/ subdirectory with terminal.rs, theme.rs, input.rs"
  - "Symbolic Key enum: maps crossterm events to widget-friendly names"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-06-11
---

# Phase 16 Plan 01: TUI Engine Primitives Summary

**TerminalGuard RAII with signal handlers, ratatui/crossterm rendering pipeline, locale-aware box chars, and symbolic keyboard input mapping**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-11T08:36:44Z
- **Completed:** 2026-06-11T08:41:21Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- TerminalGuard with RAII Drop, panic hook, and SIGINT/SIGTERM/SIGHUP signal handlers guarantees terminal restore on all exit paths
- Theme struct with dark default colors matching tui.sh, BoxChars with UTF-8/ASCII auto-detection from locale env vars
- Keyboard input maps all crossterm events to symbolic Key enum (arrows, PgUp/PgDn, Home/End, digits, help, Ctrl-D, etc.)
- 5 demo flags (--demo-select/checklist/radio/yesno/text-input) wired through CLI to main.rs TUI dispatch
- `fust --demo-select` initializes terminal, renders bordered box with title, reads keypress, restores terminal cleanly

## Task Commits

Each task was committed atomically:

1. **Task 1: Cargo deps + TerminalGuard + Theme + locale detection** - `e7ee3d5` (feat)
2. **Task 2: Keyboard input mapping + demo flags + main.rs wiring** - `1faec90` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified
- `fust/Cargo.toml` - Added ratatui 0.29, crossterm 0.28, signal-hook 0.3 dependencies
- `fust/Cargo.lock` - Updated lockfile with 60 new crate dependencies
- `fust/src/tui/mod.rs` - TUI module root with terminal, theme, input submodule declarations
- `fust/src/tui/terminal.rs` - TerminalGuard RAII with init/drop, panic hook, signal handlers, TTY check (100 lines)
- `fust/src/tui/theme.rs` - BoxChars with UTF-8/ASCII locale detection, Theme struct with dark default (130 lines)
- `fust/src/tui/input.rs` - Key enum, read_key/read_key_timeout, crossterm-to-symbolic mapping (115 lines)
- `fust/src/cli.rs` - Added 5 demo flag fields to Cli struct
- `fust/src/main.rs` - Added mod tui, demo dispatch with TerminalGuard + ratatui draw + key read

## Decisions Made
- Used ratatui 0.29 (not 0.30) as specified in plan — stable, well-supported
- Wrapped `signal_hook::low_level::register` in unsafe block (required by signal-hook 0.3 API)
- `TerminalGuard::size()` converts ratatui's `Size` to `Rect(0, 0, w, h)` for rendering compatibility
- Ctrl-C mapped to `Key::Esc` (cancel) — consistent with tui.sh behavior

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Terminal::size() return type mismatch**
- **Found during:** task 1 (cargo check)
- **Issue:** Plan code used `self.terminal.size()?` directly as `Rect`, but ratatui 0.29 returns `Size` not `Rect`
- **Fix:** Convert `Size` to `Rect::new(0, 0, s.width, s.height)` in `TerminalGuard::size()`
- **Files modified:** fust/src/tui/terminal.rs
- **Committed in:** e7ee3d5 (task 1 commit)

**2. [Rule 1 - Bug] Fixed unsafe signal_hook::low_level::register call**
- **Found during:** task 1 (cargo check)
- **Issue:** signal-hook 0.3 marks `low_level::register` as unsafe; plan code called it in safe context
- **Fix:** Wrapped in `unsafe {}` block with SAFETY comment explaining signal handler context
- **Files modified:** fust/src/tui/terminal.rs
- **Committed in:** e7ee3d5 (task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 bug fixes)
**Impact on plan:** Both fixes necessary for compilation. No scope creep, no behavior changes.

## Issues Encountered
None beyond the auto-fixed compilation issues above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- TUI engine primitives complete: terminal safety, theme, input mapping all working
- 22 tests pass (9 new TUI tests + 13 existing)
- Ready for Plan 16-02: interactive widgets (select, checklist, radio, yesno, text-input)
- `fust --demo-select` provides end-to-end verification of terminal init/draw/input/restore pipeline

---
*Phase: 16-tui-engine*
*Completed: 2026-06-11*

## Self-Check: PASSED

All files exist, all commits verified, all acceptance criteria met.
