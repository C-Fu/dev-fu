---
phase: 01-tui-engine-core
plan: 01
subsystem: tui
tags: [posix, shell, terminal, ansi, escape-sequences, stty, dd, key-reading]

# Dependency graph
requires: []
provides:
  - "tui_init() / tui_restore() — terminal state management with signal-safe cleanup"
  - "_tui_read_key() — shell-aware keyboard input with escape sequence parsing"
  - "_tui_fallback_prompt() — numbered text fallback for non-TTY environments"
  - "Color/style constants (TUI_RESET, TUI_BOLD, TUI_DIM, TUI_REV, etc.)"
  - "Box-drawing character constants with UTF-8 auto-detect"
  - "Rendering primitives (move_cursor, clear_screen, _tui_printf_at)"
  - "Key name constants (TUI_KEY_UP/DOWN/ENTER/ESC/PGUP/PGDN/HOME/END/Q/HELP/NUMBER)"
affects: [02-tui-engine-core, 03-menu-system, 05-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ESC=$(printf '\\033') for portable escape sequences (no $'\\033' bashism)"
    - "Shell-aware branching: _tui_has_read_n drives read -rsn1 vs dd bs=1 count=1"
    - "Signal trap pattern: trap 'tui_restore; exit N' INT TERM HUP QUIT (4 signals)"
    - "Stty save/restore: _tui_saved_stty=$(stty -g) on init, stty $saved on restore"
    - "Configurable timeout: TUI_KEY_TIMEOUT env var (deciseconds, default 10 = 100ms)"

key-files:
  created:
    - tui.sh
  modified: []

key-decisions:
  - "Used shellcheck disable=SC2034 for library constants — they're consumed by callers who source the file"
  - "Used shellcheck disable=SC3045 for read -rsn1 — guarded by _tui_has_read_n check, only runs on bash/zsh"
  - "Used shellcheck disable=SC2059 for _tui_printf_at — printf wrapper, format comes from caller"

patterns-established:
  - "Portable ESC via printf: ESC=$(printf '\\033'), build sequences as \"${ESC}[Nm\""
  - "Read-only dd only: dd bs=N count=N from /dev/tty — no of=, seek=, or conv= flags"
  - "Four-signal trap coverage: INT, TERM, HUP, QUIT (fixes checklist.sh missing QUIT)"
  - "Escape sequence parsing: timed multi-byte read with stty min 0 time $TUI_KEY_TIMEOUT"
  - "Fallback mode: _tui_use_tui=false when TERM=dumb or no /dev/tty"

requirements-completed: [ENGN-08, INTG-03, INTG-04]

# Metrics
duration: 4min
completed: 2026-05-23
---

# Phase 1 Plan 01: TUI Engine Primitives Summary

**Portable POSIX TUI engine with terminal init/restore (4-signal traps), shell-aware key reading (read -rsn1 on bash/zsh, dd on POSIX), escape sequence parsing with configurable timeout, and fallback numbered prompt**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-23T02:47:49Z
- **Completed:** 2026-05-23T02:52:37Z
- **Tasks:** 2
- **Files modified:** 1 (tui.sh)

## Accomplishments
- Created tui.sh (447 lines) — complete TUI engine foundation that passes `shellcheck -s sh` with zero errors/warnings
- Terminal state management with signal-safe cleanup covering INT, TERM, HUP, and QUIT (fixes checklist.sh gap)
- Shell-aware key reading using `read -rsn1` on bash/zsh and `dd bs=1 count=1` on POSIX shells — no bashisms
- Escape sequence parser handling arrows, PgUp/PgDn, Home/End with configurable TUI_KEY_TIMEOUT
- Fallback numbered prompt that activates when TERM=dumb or /dev/tty unavailable
- Vi key bindings: j/k for navigation, g/G for home/end

## Task Commits

Each task was committed atomically:

1. **task 1: create tui.sh with terminal primitives, constants, and rendering helpers** - `ce4a089` (feat)
2. **task 2: implement shell-aware key reading, escape parsing, and fallback prompt** - `0c7cd02` (feat)

## Files Created/Modified
- `tui.sh` - Complete TUI engine: terminal init/restore, color constants, box-drawing auto-detect, rendering primitives, key reading, escape parsing, fallback prompt (447 lines)

## Decisions Made
- Added `# shellcheck disable=SC2034` at file level — library constants are consumed by external callers, shellcheck can't see that
- Added `# shellcheck disable=SC3045` for `read -rsn1` — guarded by `_tui_has_read_n`, only executes on bash/zsh where `-s` is valid
- Added `# shellcheck disable=SC2059` for `_tui_printf_at` — intentional printf wrapper pattern where format comes from caller

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
- Shellcheck not installed on system — downloaded binary to `/tmp/opencode/shellcheck` for verification
- Shellcheck exit code 1 on first pass due to SC2034 (unused library constants) and SC2059 (printf format) — resolved with targeted disable directives
- SC3045 (read -s not POSIX) flagged on second task commit — resolved with targeted disable since code path is bash/zsh-only

## Next Phase Readiness
- tui.sh is ready for Plan 02 (single-select widget) which will add `tui_select()` using these primitives
- All public API functions defined: `tui_init()`, `tui_restore()`, `_tui_read_key()`, `_tui_fallback_prompt()`
- All global state variables initialized: `_tui_use_tui`, `_tui_has_read_n`, `_tui_saved_stty`, `_tui_key_timeout`
- Key constants and box-drawing constants available for widget rendering

## Self-Check: PASSED

- FOUND: tui.sh
- FOUND: .planning/phases/01-tui-engine-core/01-01-SUMMARY.md
- FOUND: ce4a089 (task 1 commit)
- FOUND: 0c7cd02 (task 2 commit)
- SHELLCHECK: PASS (zero errors/warnings)
- ALL FUNCTIONS: PASS (tui_init, tui_restore, _tui_read_key, _tui_fallback_prompt, _tui_read_byte, move_cursor, clear_screen)
- NO BASHISMS: $'\033'=0, echo -e=0, [[]]=0, dd write flags=0, let=0

---
*Phase: 01-tui-engine-core*
*Completed: 2026-05-23*
