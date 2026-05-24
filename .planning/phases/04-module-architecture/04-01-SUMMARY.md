---
phase: 04-module-architecture
plan: 01
subsystem: module-architecture
tags: [modules, fetch, metadata, parser, posix]
requires: [flu_menu_get_action]
provides: [flu_module_resolve_url, flu_module_fetch, flu_module_parse_metadata, _flu_parse_params]
affects: [modules.sh]
tech-stack:
  added: [modules.sh]
  patterns: [awk metadata parsing, curl/wget fallback, retry loop, POSIX sh globals]
key-files:
  created:
    - modules.sh (277 lines)
  modified: []
decisions:
  - "Action IDs resolve to GitHub raw URLs under flu-modules/main/modules/"
  - "Metadata parsed via awk from stdin with @key: value comment headers"
  - "No temp files for fetch — content captured in shell variable before emitting to stdout"
  - "Pipe subshell limitation acknowledged — globals available via heredoc/redirect, stdout for pipe usage"
metrics:
  duration: "~8 min"
  completed_date: "2026-05-25"
  tasks: 2
  files_created: 1
  lines_of_code: 277
---

# Phase 4 Plan 1: Module Fetch Engine & Metadata Parser — Summary

Created `modules.sh` — the foundation library for Phase 4 Module Architecture. Provides URL resolution from action identifiers, remote module script fetching with curl/wget fallback and retry logic, metadata extraction from `@key: value` comment headers, and parameter declaration parsing.

## What Was Built

**Single file: `modules.sh` (277 lines, POSIX sh, shellcheck -s sh clean)**

| Function | Purpose |
|----------|---------|
| `flu_module_resolve_url(action_id)` | Maps action ID → GitHub raw URL (FLU_MODULES_BASE_URL override support) |
| `flu_module_fetch(action_id)` | Fetches module script via curl/wget with 3-retry, 2s delay, actionable errors |
| `flu_module_parse_metadata()` | Parses `@key: value` from stdin, validates required fields, platform check |
| `_flu_parse_params(param_string)` | Parses `name=type:choices;...` into `index\|name\|type\|choices` rows |

**Key design decisions:**
- Content captured in shell variable during fetch to avoid partial output on retry failures
- Metadata parser supports both pipe (stdout output) and heredoc (globals) usage patterns
- POSIX pipe subshell limitation: `_fmp_*` globals only visible via stdin redirect (heredoc/`<`), not via `|` pipe — stdout output always available
- Platform validation maps `uname -s` to short names (linux, darwin)
- Default timeout: 300 seconds when `@timeout` not specified

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed awk gsub operating on wrong target variable**
- **Found during:** Task 1 verification
- **Issue:** awk `gsub(/^# @name: */, "", name)` passed `name` as third argument to gsub, causing it to operate on the empty variable instead of `$0` (the current line). Result: metadata fields retained the `# @key:` prefix, breaking all field extraction.
- **Fix:** Removed the third argument from all 6 gsub calls: `gsub(/^# @name: */, "")` — gsub defaults to operating on `$0`, then `name=$0` captures the cleaned value.
- **Files modified:** modules.sh (lines 119-124)
- **Commit:** b7a07da

### Procedural Notes

**Tasks 1 and 2 committed together:** Both tasks modify the single `modules.sh` file and were implemented atomically in one write. Task 2's metadata parser and param parser were included in the initial file creation since they share the same shellcheck pragmas, tui.sh sourcing, and POSIX compliance requirements. Commit `b7a07da` covers all functions.

## Verification Results

| Check | Result |
|-------|--------|
| `shellcheck -s sh modules.sh` | PASS (zero errors) |
| `sh -c '. ./modules.sh && echo OK'` | PASS |
| `flu_module_resolve_url "install_python"` | `https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/install_python.sh` |
| `flu_module_parse_metadata` with valid header | All 6 `_fmp_*` globals set correctly (heredoc) |
| `_flu_parse_params "scope=radio:global,user;name=text"` | 2 rows: `0\|scope\|radio\|global,user` and `1\|name\|text\|` |
| Missing `@name` → returns 1 | PASS |
| Missing `@version` → returns 1 | PASS |
| Platform mismatch (darwin only, on linux) → returns 1 | PASS |
| `FLU_MODULES_BASE_URL` override | PASS |
| `_flu_parse_params ""` → returns 0 | PASS |
| `_flu_parse_params "invalid"` (no `=`) → returns 1 | PASS |
| No bashisms (no `local`, `[[ ]]`, `echo -e`, `$'\033'`, `${var:0:1}`, `seq`) | PASS |
| `min_lines: 80` requirement | 277 lines (346% of minimum) |

## Threat Flags

None — all security-relevant patterns (network fetch via curl/wget, URL construction from action_id, eval-assigned globals) are covered by the plan's threat model (T-04-01 through T-04-04).

## Known Stubs

None.
