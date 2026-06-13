---
phase: 06-powershell-port
plan: 01
subsystem: tui-engine
tags: [powershell, tui, ansi, keyboard, select-widget]
requires: []
provides: [tui.ps1]
affects: [06-02, 06-03, 06-04, 06-05]
tech-stack:
  added:
    - "PowerShell script (.ps1) dot-sourceable module"
    - "ANSI escape codes via [char]27 (PS 5.1 compatible)"
    - "[Console]::ReadKey() for keyboard input"
    - "kernel32.dll P/Invoke for VT processing enable"
  patterns:
    - "Verb-Noun PowerShell function naming"
    - "`$Script:` scoped module-level variables"
    - "Inline box rendering (matching tui.sh _tui_render_select)"
key-files:
  created:
    - tui.ps1
  modified: []
decisions:
  - "j/k vi keys mapped DOWN/UP (standard vi convention, fixed from tui.sh inversion)"
  - "Inline box rendering used for Show-TuiSelect (rather than Write-TuiBox) for subtitle layout control"
  - "Multi-digit number accumulator applies on next non-digit key (simplified from tui.sh early-jump)"
metrics:
  duration: ""
  completed: "2026-05-25"
---

# Phase 6 Plan 1: TUI Engine Foundation Summary

Ported the POSIX `tui.sh` TUI engine foundation to idiomatic PowerShell in `tui.ps1` — ANSI rendering primitives with PS 5.1 VT processing enable, keyboard input via `[Console]::ReadKey()`, and full single-select menu widget with scroll indicators, number jump, vi keys, and fallback mode.

## Completed Tasks

| # | Task | Commit | Description |
|---|------|--------|-------------|
| 1 | ANSI rendering primitives and terminal init/restore | `f31dfd2` | PS version detection, VT enable, ANSI constants, box drawing chars, Initialize-Tui, Restore-Tui, Move-TuiCursor, Clear-TuiScreen, Write-TuiAt, Write-TuiBox |
| 2 | Keyboard input system via [Console]::ReadKey() | `13e060c` | 19 TUI_KEY_* constants, Read-TuiKey with ConsoleKey/char detection, Read-TuiChar for text input |
| 3 | Single-select menu widget (Show-TuiSelect) | `ff8dadf` | Full-screen bordered select with scroll, highlight, number jump, vi keys, help footer, fallback |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed regex escaping in Read-TuiKey character mappings**
- **Found during:** Task 2
- **Issue:** Plan code used raw `*` and `?` in `switch -Regex` patterns, which have special meaning in regex
- **Fix:** Escaped to `'\*'` and `'\?'` for literal character matching
- **Commit:** `13e060c`

**2. [Rule 1 - Bug] Fixed subtitle row overwriting title in Show-TuiSelect**
- **Found during:** Task 3
- **Issue:** Subtitle was rendered at `$boxY + 1` (title row position), overwriting the box title
- **Fix:** Refactored to inline box rendering matching tui.sh `_tui_render_select` layout: title row → subtitle row → separator → items → footer → bottom border. Removed Write-TuiBox usage from Show-TuiSelect.
- **Commit:** `ff8dadf`

**3. [Rule 1 - Bug] Fixed missing `$needsRedraw = $true` after number jump application**
- **Found during:** Task 3 review
- **Issue:** When accumulated digits were applied on a non-digit keypress, the screen didn't update to reflect the new cursor position until the next keypress
- **Fix:** Added `$needsRedraw = $true` in the pre-switch number application block
- **Commit:** `ff8dadf`

## Known Stubs

None. All rendering primitives, key mappings, and widget behaviors are fully implemented with no placeholder code or mocked data.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: p-invoke | tui.ps1 (lines 32-48) | kernel32.dll P/Invoke for VT processing enable on PS 5.1 — scoped to `SetConsoleMode` only, caught in try/catch |

## Self-Check: PASSED

- [x] `tui.ps1` exists (776 lines, >400 min_lines)
- [x] Contains `TUI_RESET` (8 matches)
- [x] Contains `Initialize-Tui` function (3 matches)
- [x] Contains `Restore-Tui` function (3 matches)
- [x] Contains `Read-TuiKey` function (2 matches)
- [x] Contains `Show-TuiSelect` function (4 matches)
- [x] Contains `$PSVersionTable` reference (1 match)
- [x] Contains `VirtualTerminal` reference (1 match)
- [x] All 10 functions follow Verb-Noun PowerShell convention
- [x] All ANSI codes use `[char]27` (not backtick-e) for PS 5.1 compatibility
- [x] Commits f31dfd2, 13e060c, ff8dadf all verified in git log
- [x] No file deletions detected
