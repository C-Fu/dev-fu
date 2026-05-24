---
phase: 06-powershell-port
plan: 03
subsystem: menu-system
tags: [powershell, menu, dsl-parser, hierarchical-navigation]
requires: [06-01]
provides: [menu.ps1]
affects: [06-04, 06-05]
tech-stack:
  added:
    - "PowerShell script (.ps1) dot-sourceable menu module"
    - "[System.Collections.Generic.HashSet[string]] for unique list building"
  patterns:
    - "Verb-Noun PowerShell function naming"
    - "`$Script:` scoped module-level variables for shared state"
    - "Delegates rendering to Show-TuiSelect (shared TUI widget)"
    - "Path stack for hierarchical navigation state"
key-files:
  created:
    - menu.ps1
  modified:
    - tui.ps1 (added TUI_KEY_LEFT handling to Show-TuiSelect)
decisions:
  - "Delegated menu level rendering to Show-TuiSelect (rather than inline _flu_menu_render port)"
  - "Added TUI_KEY_LEFT exit to Show-TuiSelect to enable menu back-navigation (Rule 2 deviation)"
  - "PowerShell HashSets replace POSIX eval-based indexed arrays for unique label storage"
metrics:
  duration: "00:01:42"
  completed: "2026-05-25"
---

# Phase 6 Plan 3: Menu System Summary

Port of the POSIX `menu.sh` hierarchical menu DSL parser and navigation engine to idiomatic PowerShell in `menu.ps1` — parsing the shared `menu.db` DSL file, querying menu trees at any depth, rendering via `Show-TuiSelect`, and navigating 3-level hierarchies with breadcrumbs and back-navigation.

## Completed Tasks

| # | Task | Commit | Description |
|---|------|--------|-------------|
| 1 | Menu DSL parser (Import-FluMenu, Get-FluMenuChildren, Test-FluMenuIsLeaf, Get-FluMenuBreadcrumb, Get-FluMenuAction) | `69f0369` | Parses pipe-delimited menu.db into script-scope arrays using HashSets; provides child lookup at any depth, leaf detection, breadcrumb formatting, and action ID extraction |
| 2 | Menu navigation engine (Show-FluMenuNavigate) with fallback | `1dbf80e` | Hierarchical 3-level navigation using Show-TuiSelect per level; path stack with Left/Esc back-navigation; TUI lifecycle management; numbered Read-Host fallback mode |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added TUI_KEY_LEFT handling to Show-TuiSelect**
- **Found during:** Task 2
- **Issue:** The menu navigation engine needs Left arrow to trigger back-navigation, but Show-TuiSelect treated Left arrow as a no-op (fell through to `default` case that only clears digitAccum). Without this, the plan's acceptance criterion "Left arrow key triggers back-navigation at non-root level" could not be met.
- **Fix:** Added `$Script:TUI_KEY_LEFT` case to Show-TuiSelect's switch statement, setting `$Script:TUI_RESULT = -1` and `$running = $false` — same behavior as Esc. The menu navigate function already has logic to distinguish root-level cancel from non-root back-navigation via `pathStack.Count`.
- **Files modified:** `tui.ps1` (lines 715-720)
- **Commit:** `1dbf80e`

**2. [Rule 3 - Verification Environment] PowerShell unavailable in execution environment**
- **Found during:** Task 1 verification
- **Issue:** `powershell` and `pwsh` binaries not found on this Linux worktree. Automated verification commands from the plan could not be executed.
- **Resolution:** The plan provides extremely detailed, line-by-line implementation code. All code was replicated exactly. Verification performed via static analysis (function count, line count, key-link pattern checks, function name presence, ANSI code compliance). All criteria pass statically.
- **Note:** Runtime verification should be performed on a system with PowerShell installed before 06-05 integration.

## Threat Flags

No new threat surface beyond the plan's threat model. Both threats are addressed:

| Threat ID | Status |
|-----------|--------|
| T-06-09 (menu.db tampering) | Mitigated: malformed/non-conforming lines skipped by regex filter `^\s*(#|$)` |
| T-06-10 (deep nesting DoS) | Mitigated: depth limit `pathStack.Count -ge 3` enforced in both TUI and fallback paths |

## Known Stubs

None. All functions are fully implemented — no placeholder data, no TODO markers, no hardcoded empty values that flow to UI rendering. The `$Script:_fluMenu*` arrays are empty at script load (expected) and populated at runtime by `Import-FluMenu`.

## Self-Check: PASSED

- [x] `menu.ps1` exists (485 lines, exceeds 200-line minimum)
- [x] Contains `Import-FluMenu` function
- [x] Contains `Get-FluMenuChildren` function
- [x] Contains `Get-FluMenuBreadcrumb` function
- [x] Contains `Get-FluMenuAction` function
- [x] Contains `Show-FluMenuNavigate` function
- [x] Contains `Test-FluMenuIsLeaf` function
- [x] Contains `Show-FluMenuNavigateFallback` function
- [x] `Show-TuiSelect` referenced in Show-FluMenuNavigate (key link)
- [x] `Get-Content` with `$DslFile` in Import-FluMenu (key link to menu.db)
- [x] All functions use Verb-Noun PowerShell naming
- [x] Uses `$Script:ESC` (no backtick-e) for PS 5.1 compatibility
- [x] Guard verifies `tui.ps1` was sourced before running
- [x] Commits `69f0369` and `1dbf80e` verified in git log
- [x] No file deletions in either commit
- [x] No untracked generated files from this plan
