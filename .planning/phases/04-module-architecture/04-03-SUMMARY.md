---
phase: 04-module-architecture
plan: 03
subsystem: module-architecture
tags: [modules, result-display, recovery-hints, box-modal, posix]
requires:
  - phase: 04-01
    provides: [flu_module_resolve_url, flu_module_fetch, flu_module_parse_metadata]
  - phase: 04-02
    provides: [flu_module_execute, flu_module_set_env, flu_module_collect_params, _flu_execute_with_timeout]
provides:
  - flu_module_display_result — box-rendered result modal with success/failure status banners
  - _flu_display_recovery_hints — exit-code-to-actionable-hint mapping (7 patterns)
  - _flu_wait_for_key — single keypress pause helper
affects: [modules.sh]
tech-stack:
  added: []
  patterns: [POSIX sh box-rendered modal, exit-code-driven recovery hints, temp-file-based output capture with redirection, awk word-wrap for hint text]
key-files:
  created: []
  modified:
    - modules.sh (924 lines, +208 from Plan 04-02 baseline)
key-decisions:
  - "Footer rendered at box_h-2 (inside box, above bottom border) — corrected the plan's literal box_h-1 which would overwrite the box's bottom border row"
  - "Output content read from temp file (/tmp/flu_result_$$) with < redirection — avoids POSIX pipe subshell issue where while-read in pipeline loses variable state (same pattern as flu_module_collect_params)"
  - "Consolidated overlapping recovery pattern *command not found* into *not found* catch-all — shellcheck SC2222 flagged unreachable branch; behavior unchanged since hint text is identical"
  - "Recovery hints rendered in TUI_YELLOW with word-wrap via awk to fit box inner width"
requirements-completed:
  - MODL-05
metrics:
  duration: "~3 min"
  completed_date: "2026-05-25"
  tasks: 2
  files_modified: 1
  lines_of_code: 924
---

# Phase 4 Plan 3: Result Display & Error Reporting — Summary

Box-rendered result modal with success/failure status banners, in-box content rendering, and actionable recovery hints derived from exit codes — completing the D-09 execution pipeline (fetch → parse → prompt → execute → display).

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-24T18:20:08Z
- **Completed:** 2026-05-24T18:22:30Z
- **Tasks:** 2
- **Files modified:** 1 (modules.sh: +208 lines from plan 04-02 baseline)

## Accomplishments

- `flu_module_display_result()` — Full box-rendered result modal replacing the `_flu_module_show_status` stub from Plan 04-02. Renders a bordered box via `_tui_draw_box` with:
  - **Success** (exit 0): Green `✓ module — Complete` title, module stdout displayed line-by-line
  - **Failure** (exit ≠ 0): Red `✗ module — Failed (exit: N)` title, module stderr + recovery hints
  - Line truncation to fit box width via `awk substr`
  - "No error output" fallback message for silent failures
  - "Press any key to return to menu" footer with keypress pause
- `_flu_wait_for_key()` — Single keypress reader using `_tui_read_key` from tui.sh, pauses modal until user acknowledges
- `_flu_display_recovery_hints()` — Maps 7 error patterns to actionable hints, word-wraps inside result box in TUI_YELLOW:
  - Exit 124: timeout hint with configured timeout value
  - Exit 126: corrupted download hint
  - Exit 127: missing dependency hint
  - Exit 1: pattern-matched (curl/network, permission denied, not found, generic)
  - Network codes 6,7,22,28: connectivity + proxy hint
  - Generic fallback for any other exit code
- `flu_module_execute()` wired end-to-end: captures stdout/stderr via temp files (`/tmp/flu_module_out_$$`, `/tmp/flu_module_err_$$`), passes to `flu_module_display_result()`, cleans up temp files on all exit paths
- Tui.sh sourcing guards on both display and recovery functions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create result display modal with box rendering and status banners** — `7ca59d6` (feat)
2. **Task 2: Implement recovery hints system and integrate result display into execution pipeline** — `d79f4e5` (feat)

## Files Modified

- `modules.sh` — Extended from 716 to 924 lines. Replaced Section 10 stub, extended Section 9 (flu_module_execute), added Section 11:
  - Section 9: `flu_module_execute()` — output capture + display wiring
  - Section 10: `flu_module_display_result()` + `_flu_wait_for_key()` — result modal
  - Section 11: `_flu_display_recovery_hints()` — recovery hints

## Decisions Made

- **Footer positioning**: The plan specified footer at `_fdr_y + _fdr_box_h - 1` (the bottom border row). Implementation uses `_fdr_y + _fdr_box_h - 2` (one row above bottom border, inside the box). This prevents overwriting the box-drawing border characters — same pattern as `_tui_render_select` which renders footer outside its box.

- **Output capture via temp files**: `flu_module_execute()` redirects `_flu_execute_with_timeout` stdout/stderr to `/tmp/flu_module_out_$$` and `/tmp/flu_module_err_$$`, reads them into `_flu_module_output` and `_flu_module_stderr` globals, then cleans up. This is necessary because the display function needs the captured content — cannot display directly to terminal during execution when the modal hasn't been shown yet.

- **Word-wrap via awk**: Recovery hints use awk-based word wrapping (`fold -s` alternative in pure POSIX sh) to fit text within the box's inner width. The awk approach handles both soft breaks (at spaces) and hard breaks (no spaces found, break at max width).

- **Recovery pattern consolidation**: The `*"command not found"*` pattern was removed as it was unreachable (substring `"not found"` in the earlier pattern matches it first). Shellcheck SC2221/SC2222 flagged this. Consolidated to `*"not found"*|*"Not found"*` — same hint text, both cases covered.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unreachable case pattern in recovery hints**
- **Found during:** Task 2 shellcheck review
- **Issue:** `*"not found"*|*"Not found"*|*"command not found"*` — the `*"not found"*` pattern always matched before `*"command not found"*`, making the third branch unreachable (SC2221/SC2222)
- **Fix:** Removed the unreachable `*"command not found"*` branch — consolidated to `*"not found"*|*"Not found"*`. The hint text was identical across all three patterns, so no behavior change.
- **Files modified:** modules.sh (line 873)
- **Committed in:** d79f4e5

**2. [Rule 1 - Bug] Adjusted footer row position from plan specification**
- **Found during:** Task 1 implementation
- **Issue:** Plan specified footer at `_fdr_y + _fdr_box_h - 1` which is the bottom border row — would overwrite box-drawing characters
- **Fix:** Changed to `_fdr_y + _fdr_box_h - 2` — renders inside the box, one row above the bottom border
- **Files modified:** modules.sh (line 813)
- **Committed in:** 7ca59d6

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs)
**Impact on plan:** Both fixes are cosmetic/structural corrections to rendering; no functional impact on the result display system.

## Issues Encountered

None — implementation followed the plan closely. The footer position and case-pattern overlap were minor plan-vs-reality adjustments handled as auto-fixes.

## Known Stubs

None. The `_flu_module_show_status` stub from Plan 04-02 has been fully replaced by the `flu_module_display_result` modal. All output rendering is wired end-to-end through the execution pipeline.

## Threat Flags

None — all security-relevant surface (output rendering in terminal box, temp file cleanup, recovery hint derivation from exit codes) is covered by the plan's threat model (T-04-09 through T-04-11).

## Verification Results

| Check | Result |
|-------|--------|
| `shellcheck -s sh modules.sh` | PASS (zero errors/warnings from new code) |
| `flu_module_display_result` defined | PASS |
| `_flu_display_recovery_hints` defined | PASS |
| Success pattern (✓ ... Complete) | PASS |
| Failure pattern (✗ ... Failed exit: N) | PASS |
| Recovery hint: timeout (124) | PASS |
| Recovery hint: dependency (127) | PASS |
| Recovery hint: network error | PASS |
| Press any key footer | PASS |
| Temp file cleanup in execute | PASS |
| Output capture (stdout+stderr) | PASS |
| D-09 pipeline end-to-end wired | PASS (fetch→parse→prompt→execute→display) |
| No bashisms | PASS (no `local`, `[[ ]]`, `echo -e`, `$'\033'`) |
| Zero bash-specific syntax | PASS |
| Line count: +208 from 04-02 baseline | PASS (924 total) |

## Next Phase Readiness

- `modules.sh` is now feature-complete for Phase 4 requirements (MODL-01 through MODL-05)
- The full D-09 pipeline is end-to-end wired: fetch → parse → set env → platform check → collect params → execute → display
- `flu_module_execute()` is the main entry point for the orchestrator (Phase 5) to consume
- All functions follow `flu_` public / `_flu_` internal naming convention
- Ready for Phase 5: Orchestration & Integration

## Self-Check: PASSED

| Item | Result |
|------|--------|
| SUMMARY.md exists | FOUND |
| modules.sh exists (924 lines) | FOUND |
| Task 1 commit (7ca59d6) | FOUND |
| Task 2 commit (d79f4e5) | FOUND |
| flu_module_display_result() defined | FOUND |
| _flu_display_recovery_hints() defined | FOUND |
| Zero bashisms | PASS |

---
*Phase: 04-module-architecture*
*Completed: 2026-05-25*
