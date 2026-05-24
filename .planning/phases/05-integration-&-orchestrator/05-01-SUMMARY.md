---
phase: 05-integration-&-orchestrator
plan: 01
subsystem: tui.sh (TUI Engine)
tags: [spinner, async-render, posix-sh, tui-widget]
dependency-graph:
  requires: []
  provides: [flu_spinner_start, flu_spinner_stop, _flu_spinner_render]
  affects: [tui.sh]
tech-stack:
  added: []
  patterns: [_flu_ internal prefix, flu_ public functions, subshell background process, carriage-return overwrite, POSIX sh only]
key-files:
  created: [test_spinner.sh]
  modified: [tui.sh]
decisions: []
metrics:
  duration: 133s
  task-count: 2
  file-count: 2
  completed-date: 2026-05-25
---

# Phase 5 Plan 01: Spinner Widget Summary

**One-liner:** Reusable async rotating-character spinner widget in tui.sh with UTF-8 braille and ASCII fallback, zero bashisms, for network operation progress indication.

---

## Tasks Completed

### task 1: add spinner widget functions to tui.sh (TDD)
**Commit:** 4dd23fa
**Type:** feat

Added Section 16: Async spinner widget between Section 15 (tui_text_input) and the demo block:

- `_flu_spinner_detect_utf8()` — module-scope UTF-8 locale detection (mirrors `_tui_detect_box_chars` pattern). Selects braille `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` (10 frames) or ASCII `|/-\` (4 frames).
- `_flu_spinner_render()` — renders one frame. In TUI mode: `_tui_printf_at` at bottom-center with `"  Loading {char}"`. In fallback mode: `printf '\r  Working... {char}'` with carriage-return overwrite.
- `flu_spinner_start()` — launches `(while :; do _flu_spinner_render; sleep 0.1; done) &` background subshell. Idempotent guard: no-op if `_flu_spinner_pid` already set.
- `flu_spinner_stop()` — kills background process via `kill` + `wait`, clears screen area (cursor move + `_tui_clear_line` in TUI, newline in fallback), unsets `_flu_spinner_pid`. Safe no-op when no spinner running.

**TDD:** RED phase committed as `72241e8` (10 tests, all failing). GREEN phase committed as `4dd23fa` (10/10 passing).

**Verification:**
- `bash -n tui.sh` exits 0
- All 10 spinner tests pass (process creation, guard, cleanup, no-op safety, re-entrancy, render function)
- Zero `$'\033'`, `echo -e`, or `sed '\x1b'` anti-patterns

### task 2: verify spinner with test harness
**Commit:** 0257f04
**Type:** feat

Added `--demo-spinner` case to the tui.sh demo block (before the `*)` catch-all):
- Prints "Spinner demo — starting spinner for 3 seconds..."
- Calls `flu_spinner_start`, `sleep 3`, `flu_spinner_stop`
- Prints "Spinner stopped."
- Exits 0

**Verification:**
- `sh tui.sh --demo-spinner` — braille spinner animates for ~3 seconds, stops cleanly
- `TERM=dumb sh tui.sh --demo-spinner` — text lines output (no ANSI escape codes), completes successfully
- No zombie processes remain after demo exits
- Existing demos (`--demo-yesno`, etc.) continue to work unchanged

---

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED | `72241e8` — `test(05-01): add failing test for spinner widget` | 10/10 tests FAIL (expected) |
| GREEN | `4dd23fa` — `feat(05-01): implement spinner widget functions` | 10/10 tests PASS |

REFACTOR gate not needed — implementation follows all conventions on first pass.

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None. All functions are fully implemented with live behavior.

---

## Self-Check

- [x] `tui.sh` exists and contains all three spinner functions
- [x] `test_spinner.sh` exists with 10 passing tests
- [x] Commit `72241e8` exists: RED test commit
- [x] Commit `4dd23fa` exists: GREEN implementation commit
- [x] Commit `0257f04` exists: demo-spinner harness commit
- [x] `bash -n tui.sh` passes with exit 0
- [x] All acceptance criteria from PLAN.md verified

**Self-Check: PASSED**
