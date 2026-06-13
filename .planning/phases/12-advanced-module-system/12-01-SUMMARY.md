---
phase: 12-advanced-module-system
plan: 01
subsystem: cli
tags: [cli, batch-mode, posix-sh, shellcheck]

# Dependency graph
requires:
  - phase: 04-module-architecture
    provides: flu_module_fetch, flu_module_parse_metadata, _flu_execute_with_timeout, _flu_log_execution
provides:
  - "flu_batch_run(): non-interactive batch module execution"
  - "flu_batch_list(): module listing in table and JSON format"
  - "CLI flags: --install, --remove, --list, --yes, --json, --help"
affects: [12-02, powershell-parity]

# Tech tracking
tech-stack:
  added: []
  patterns: [cli-while-case-parser, conditional-ansi-output, action-id-validation]

key-files:
  created: []
  modified:
    - flu.sh
    - modules.sh

key-decisions:
  - "Action ID validation against menu.db for T-12-01 threat mitigation (reject unknown IDs)"
  - "Conditional ANSI output via [ -t 1 ] check rather than post-hoc stripping for efficiency"
  - "Manual while/case CLI parser instead of getopts — getopts cannot handle --install value patterns in POSIX sh"

patterns-established:
  - "Batch execution: validate → fetch → parse → check params → check platform → execute → log → status"
  - "CLI dispatch: parse args → dispatch batch/list → exit before TUI; no CLI flags → enter TUI loop"

requirements-completed: [ADVN-01]

# Metrics
duration: 10min
completed: 2026-05-28
---

# Phase 12 Plan 01: CLI Batch Mode Summary

**Non-interactive CLI batch mode with --install/--remove/--list flags, JSON output, param rejection, and action ID validation against menu.db**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-27T20:08:09Z
- **Completed:** 2026-05-27T20:18:12Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- `flu_batch_run()` function in modules.sh for non-interactive module execution with continue-on-failure, status lines, and summary counts
- `flu_batch_list()` function in modules.sh for table and JSON module listing from menu.db
- CLI argument parsing in flu.sh with 6 flags (--install, --remove, --list, --yes, --json, --help)
- T-12-01 threat mitigation: action IDs validated against menu.db before execution
- All integration tests pass: help, list, JSON, error cases, param rejection

## Task Commits

Each task was committed atomically:

1. **Task 1: CLI batch execution engine in modules.sh** - `c644cd7` (feat)
2. **Task 2: CLI argument parsing and batch mode wiring in flu.sh** - `a982938` (feat)
3. **Task 3: Integration test — verify CLI batch mode end-to-end** - verification only, no code changes needed

## Files Created/Modified

- `modules.sh` - Added `_flu_strip_ansi()`, `flu_batch_run()`, `flu_batch_list()` as Sections 8.7–8.9
- `flu.sh` - Added CLI argument parsing and dispatch between platform detection and logo rendering

## Decisions Made

- **Action ID validation against menu.db:** Implemented as T-12-01 threat mitigation — unknown action IDs are rejected with clear error message before any fetch attempt
- **Conditional ANSI output:** Used `[ -t 1 ]` check to branch on TTY/no-TTY output rather than post-hoc sed stripping — cleaner and zero overhead when TTY is available
- **Manual while/case parser:** Chosen over getopts because getopts cannot handle `--install value` flag+value patterns in POSIX sh
- **Defense-in-depth platform check:** Added separate platform check in `flu_batch_run` even though `flu_module_parse_metadata` already checks, for specific error messages

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added action ID validation against menu.db**
- **Found during:** task 1 (batch execution engine)
- **Issue:** Threat model T-12-01 requires validating action_ids against menu.db entries — plan's task action didn't include this step explicitly
- **Fix:** Added grep-based validation loop that checks each action_id against menu.db before processing, rejecting unknown IDs with clear error
- **Files modified:** modules.sh
- **Verification:** `bash flu.sh --install fake_module --yes` prints "Unknown action ID" and exits 1
- **Committed in:** c644cd7 (task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 - missing critical security validation)
**Impact on plan:** Essential for threat model compliance. No scope creep.

## Issues Encountered

None — all integration tests passed on first run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CLI batch mode fully functional for CI/CD and scripted use
- Ready for plan 12-02 (module registry with auto-discovery)
- PowerShell parity (flu.ps1) will need equivalent batch mode implementation

## Self-Check: PASSED

All files exist, all commits found in git log.

---
*Phase: 12-advanced-module-system*
*Completed: 2026-05-28*
