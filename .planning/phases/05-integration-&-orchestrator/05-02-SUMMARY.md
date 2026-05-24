---
phase: 05-integration-&-orchestrator
plan: 02
subsystem: flu.sh (Orchestrator Entry Point)
tags: [orchestrator, event-loop, tty-reattachment, spinner-integration, posix-sh, tdd]
dependency-graph:
  requires: [05-01]
  provides: [flu.sh orchestrator, TTY reattachment, platform startup banner, menu-to-module dispatch, spinner integration]
  affects: [flu.sh, test_flu.sh]
tech-stack:
  added: []
  patterns:
    [TTY reattachment (exec 0</dev/tty), subsystem sourcing (. "$FLU_SCRIPT_DIR/..."),
     platform detection (flu_module_set_env), box-rendered startup banner,
     while-loop event dispatch, spinner wrapping, _flu_ internal prefix, POSIX sh only]
key-files:
  created: [flu.sh, test_flu.sh]
  modified: []
decisions: [D-01, D-02, D-03, D-04, D-05, D-06]
metrics:
  duration: 0s
  task-count: 2
  file-count: 0
  completed-date: 2026-05-25
---

# Phase 5 Plan 02: flu.sh Orchestrator Core Summary

**One-liner:** Complete POSIX sh orchestrator entry point that wires TUI engine, menu system, and module architecture into a single curl-pipe-bash-deployable script with TTY reattachment, platform detection banner, and spinner-wrapped module dispatch.

---

## Tasks Completed

### task 1: create flu.sh skeleton — TTY reattachment, sourcing, platform, startup display (TDD)
**Commit:** `c3608cb`
**Type:** feat

Created `flu.sh` at repository root with six clearly separated sections:

- **Section 1 (Header):** Multi-line comment block documenting purpose, compatibility (bash/zsh/dash/ash/busybox sh), coexistence with fu.sh, and branch strategy.
- **Section 2 (TTY Reattachment — ENGN-09, D-02):** Detects piped stdin (`[ ! -t 0 ]`) and reattaches to `/dev/tty` via `exec 0</dev/tty`. Falls through (no exit) when `/dev/tty` is unavailable — tui.sh's `_tui_check_tty` sets `_tui_use_tui=false` for numbered prompt fallback mode. Differs from fu.sh which exits on `/dev/tty` unavailable.
- **Section 3 (Subsystem Sourcing — D-01):** Resolves `FLU_SCRIPT_DIR`, sources `tui.sh` → `menu.sh` → `modules.sh` in dependency order. Each import guarded with `# shellcheck disable=SC1091` per project conventions.
- **Section 4 (Platform Detection — D-03):** Calls `flu_module_set_env()` which exports all 7 FLU_* environment variables (FLU_OS, FLU_DISTRO, FLU_PKG_MGR, FLU_ARCH, FLU_IS_WSL, FLU_IS_TERMUX, FLU_IS_ROOT). Reuses existing modules.sh logic — no duplication.
- **Section 5 (Startup Display):** In TUI mode: enters raw mode (`tui_init`), renders a centered box via `_tui_draw_box()` with "flu.sh v0.1.0" title, displays OS/distro/pkg/arch with color-coded `_tui_printf_at` calls, waits for keypress (`_tui_read_key`), restores terminal (`tui_restore`). In fallback mode: plain text platform summary via `printf`.
- **Section 6 (Menu Definition):** Sets `FLU_MENU_FILE` to `$FLU_SCRIPT_DIR/menu.db`, verifies file existence with colored error output and `exit 1` on failure.

**TDD:** RED phase committed as `460612a` (tests for shebang, TTY, sourcing, platform, anti-bashisms — all failing). GREEN phase commits the skeleton with all 15/15 task-1 tests passing.

**Verification:**
- `bash -n flu.sh` exits 0, `dash -n flu.sh` exits 0, `shellcheck -s sh flu.sh` exits 0
- All 15 structural tests pass (shebang, TTY reattachment, 3 subsystem sources, platform detection, menu file, no bashisms)

---

### task 2: implement main event loop — menu navigation, module dispatch with spinner, result handling (TDD)
**Commit:** `9d5505a`
**Type:** feat

Added Section 7 (Main Event Loop) to flu.sh implementing the full end-to-end execution flow:

- **Step 1 — Menu Navigation (D-04):** Calls `flu_menu_navigate("$FLU_MENU_FILE")` which handles its own TUI lifecycle (init → render → key handling → restore). On leaf selection: returns 0, sets `TUI_RESULT` to path like `"Developer Tools|Languages|Python"`. On cancel at root: returns 1 — sets `_flu_running=false` and exits the loop.
- **Step 2 — Action Extraction:** Calls `flu_menu_get_action("$TUI_RESULT")` to extract the action_id (e.g., `"install_python"`) from the menu.db DSL. Empty result → `continue` to return to menu.
- **Step 3 — Spinner-Wrapped Module Execution (INTG-01, D-05):** Calls `flu_spinner_start()` to launch background spinner process, then `flu_module_execute(action_id)` which runs the full pipeline (fetch → parse → platform check → collect params → execute → display result). `flu_spinner_stop()` kills the background process and cleans up. The spinner is visible during the network fetch phase — `flu_module_display_result()` (called internally) overwrites the spinner area with the result modal.
- **Step 4 — Post-Execution:** Calls `clear_screen` to prepare for the next menu render iteration.
- **Step 5 — Clean Exit:** Calls `tui_restore()` (idempotent — safe no-op if already restored), prints green "flu.sh — Goodbye!" message, unsets all globals (`_flu_action`, `_flu_nav_rc`, `_flu_mod_rc`, `_flu_running`, `FLU_SCRIPT_DIR`, `FLU_MENU_FILE`).

**TDD:** Task-2 tests were already written (committed in RED phase `460612a`). GREEN phase fixes grep count assertions (non-comment-line matching) and adds the loop implementation. All 30/30 structural tests passing.

**Verification:**
- `bash -n flu.sh` exits 0, `dash -n flu.sh` exits 0, `shellcheck -s sh flu.sh` exits 0
- All 30 structural tests pass: 15 skeleton + 15 event loop (presence + exact counts on non-comment lines)
- Shellcheck clean with pragmas for sourced variables (`SC2154` for `_tui_use_tui`, `SC1091` for external sources)

---

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (Task 1) | `460612a` — `test(05-02): add failing structural tests for flu.sh orchestrator` | All tests FAIL (flu.sh did not exist) |
| GREEN (Task 1) | `c3608cb` — `feat(05-02): create flu.sh orchestrator skeleton` | 15/15 Task 1 tests PASS |
| RED (Task 2) | `460612a` — Task 2 tests fail (loop not implemented) | 13/15 Task 2 tests FAIL (expected) |
| GREEN (Task 2) | `9d5505a` — `feat(05-02): implement main event loop with menu dispatch and spinner integration` | 30/30 all tests PASS |

Note: Both RED phases are captured in the initial test commit. Task 2 RED was implicit — the tests existed but failed until implementation.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Fixed grep count assertion in test_flu.sh**

- **Found during:** Task 2 verification
- **Issue:** `_assert_grep_count` used `grep -c ... || printf '0'` which produced `"0\n0"` when grep found zero matches (grep -c exits 1 on zero matches, triggering the `||` fallback, causing double output with newline). This made `[ "$_agc_actual" -eq "$_agc_count" ]` fail as an illegal number comparison.
- **Fix:** Changed to `_agc_actual=$(grep -c ... 2>/dev/null); _agc_actual="${_agc_actual:-0}"` — captures grep output directly, defaults to 0 when grep fails (file not found).
- **Files modified:** `test_flu.sh`
- **Commit:** `9d5505a`

**2. [Rule 3 - Blocker] Added SC2154 pragma for sourced variable `_tui_use_tui`**

- **Found during:** Task 1 shellcheck verification
- **Issue:** `shellcheck -s sh` warned about `_tui_use_tui` being referenced but not assigned — the variable is set in sourced `tui.sh`, invisible to shellcheck.
- **Fix:** Added `# shellcheck disable=SC2154` before the `if [ "$_tui_use_tui" = "true" ]` check in the startup display section.
- **Files modified:** `flu.sh`
- **Commit:** `9d5505a`

**3. [Rule 3 - Blocker] grep count patterns matched comments in addition to code**

- **Found during:** Task 2 test verification
- **Issue:** `grep -c 'flu_menu_navigate' flu.sh` returned 3 (comments + actual call) instead of expected 1. Same for `flu_menu_get_action` and `flu_module_execute`.
- **Fix:** Updated test patterns to `'^[^#]*flu_menu_navigate'` to only match non-comment lines. Each function has exactly 1 call site on non-comment lines.
- **Files modified:** `test_flu.sh`
- **Commit:** `9d5505a`

---

## Known Stubs

None. All functions are fully wired: TTY reattachment → subsystem sourcing → platform detection → startup display → menu navigation → action extraction → spinner-wrapped module execution → clean exit.

The error recovery path (`_flu_mod_rc` preserved but not used) is explicitly deferred to Plan 05-03 per plan specification.

---

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: info | flu.sh | `exec 0</dev/tty` — TTY reattachment for curl-pipe-bash deployment. Standard practice, covered by plan threat model T-05-03 (accept). |
| threat_flag: info | flu.sh | `flu_module_execute` dispatches to remote module scripts fetched via HTTP. Trust boundary handled by modules.sh, covered by plan threat model. |

No new unmodeled threat surface introduced.

---

## Self-Check

- [x] `flu.sh` exists at repository root (198 lines)
- [x] `test_flu.sh` exists with 30/30 passing structural tests
- [x] Commit `460612a` exists: RED test commit
- [x] Commit `c3608cb` exists: Task 1 GREEN skeleton
- [x] Commit `9d5505a` exists: Task 2 GREEN event loop
- [x] `bash -n flu.sh` passes with exit 0
- [x] `dash -n flu.sh` passes with exit 0
- [x] `shellcheck -s sh flu.sh` passes with exit 0
- [x] All plan acceptance criteria verified
- [x] No bashisms in flu.sh
- [x] TTY reattachment uses D-02 fallback (no exit on /dev/tty unavailable)

**Self-Check: PASSED**
