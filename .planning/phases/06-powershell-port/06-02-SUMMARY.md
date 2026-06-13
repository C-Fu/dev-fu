---
phase: 06-powershell-port
plan: 02
subsystem: tui-widgets
tags: [powershell, tui, checklist, radio, yesno, text-input, widgets]
requires:
  - 06-01 (tui.ps1 foundation)
provides:
  - Show-TuiChecklist
  - Show-TuiRadio
  - Show-TuiYesNo
  - Show-TuiTextInput
affects:
  - 06-03 (menu integration uses checklist/select widgets)
  - 06-04 (module parameter prompts use radio/text/yesno widgets)
tech-stack:
  added:
    - "System.Text.StringBuilder for text manipulation"
    - "Direct [Console]::ReadKey() decoding in text input widget"
  patterns:
    - "Inline box rendering with Write-TuiBox + Write-TuiAt override"
    - "$Script:TUI_RESULT as inter-widget communication channel"
    - "Fallback modes for non-TUI terminals in every widget"
key-files:
  created: []
  modified:
    - tui.ps1
decisions:
  - "Show-TuiTextInput does NOT cancel on 'q' (unlike other widgets) — users need to type all letters"
  - "Direct [Console]::ReadKey() used in Show-TuiTextInput (not Read-TuiKey) to avoid key double-consumption"
  - "Local $_renderCount used in checklist/radio rendering to avoid $visibleRows mutation drift between frames"
metrics:
  duration: "5m 15s"
  completed: "2026-05-25"
---

# Phase 6 Plan 2: Interactive Widgets Summary

Extended `tui.ps1` with four interactive widgets matching POSIX `tui.sh` behaviors exactly — multi-select checklist, radio single-select with dots, yes/no confirmation, and freeform text input — all using PowerShell idioms with `Write-TuiBox`, `Read-TuiKey`, and script-scoped `$Script:TUI_RESULT`.

## Completed Tasks

| # | Task | Commit | Description |
|---|------|--------|-------------|
| 1 | checklist widget | `8f6f5de` | Show-TuiChecklist with [x]/[ ] toggles, Space toggle, * select-all, - deselect-all, full navigation, fallback |
| 2 | radio and yesno widgets | `f39f820` | Show-TuiRadio with (•)/(○) dot indicators; Show-TuiYesNo with [ Yes ]/[ No ] highlight, word-wrapped message, fallback |
| 3 | text input widget | `02f552b` | Show-TuiTextInput with cursor movement, backspace/delete editing, scroll on overflow, direct key reading, fallback |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed $visibleRows mutation drift in checklist and radio rendering**
- **Found during:** Task 1 (checklist)
- **Issue:** Plan pseudocode decremented `$visibleRows` inside the render block when showing top scroll indicator, but `$visibleRows` was used for navigation bounds. After the first frame with scroll indicators, `$visibleRows` would stay reduced even after the scroll indicator disappeared, causing incorrect navigation bounds.
- **Fix:** Introduced local `$_renderCount` variable that is recalculated each frame. Navigation bounds continue to use the unmodified `$baseVisibleRows` (renamed from `$visibleRows`). Applied to both Show-TuiChecklist and Show-TuiRadio.
- **Files modified:** `tui.ps1`
- **Commit:** `8f6f5de`

**2. [Rule 1 - Bug] Fixed key double-consumption in Show-TuiTextInput**
- **Found during:** Task 3 (text input)
- **Issue:** Plan pseudocode called `Read-TuiKey` to detect navigation keys, then `Read-TuiChar` in the `TUI_KEY_UNKNOWN` branch to get the actual character. But `Read-TuiKey` consumes the keypress via `[Console]::ReadKey($true)`, leaving nothing for `Read-TuiChar` to read — the second call would block waiting for a new keypress (wrong character).
- **Fix:** Replaced `Read-TuiKey`/`Read-TuiChar` with direct `[Console]::ReadKey($true)` calls inside Show-TuiTextInput. Navigation keys decoded via `ConsoleKey` enum. Printable characters decoded via `KeyChar` (ASCII 32-126). Ctrl+A/Ctrl+E mapped to Home/End via modifier detection. This matches POSIX `tui_text_input()`'s approach of using `_tui_read_char` (raw bytes) instead of `_tui_read_key` (symbolic).
- **Files modified:** `tui.ps1`
- **Commit:** `02f552b`

**3. [Rule 1 - Bug] Removed 'q' cancel from Show-TuiTextInput**
- **Found during:** Task 3 post-commit review
- **Issue:** Plan included `$Script:TUI_KEY_Q` handler to cancel text input (following the pattern of other widgets). But users need to type the letter 'q' in text input — canceling on 'q' would prevent entering words containing that letter.
- **Fix:** Removed 'q' cancel handler. Only Esc cancels text input. Comment added explaining the design decision (Q is a printable letter unlike in selection widgets).
- **Files modified:** `tui.ps1`
- **Commit:** `02f552b`

## Known Stubs

None. All widget behaviors, keybindings, rendering, and fallback modes are fully implemented with no placeholder code or mocked data.

## Threat Flags

No new threat surface beyond what was documented in the plan's threat model:
- T-06-06 (textBuilder tampering) — accepted, user-entered text is inherently user-controlled
- T-06-07 (render loop DoS) — mitigated by `$needsRedraw` flag and blocking I/O
- T-06-08 (default value disclosure) — accepted, defaults are user-provided

## Self-Check: PASSED

- [x] `tui.ps1` contains all 5 widget functions: Show-TuiSelect, Show-TuiChecklist, Show-TuiRadio, Show-TuiYesNo, Show-TuiTextInput
- [x] Each widget uses Write-TuiBox for bordered box rendering (5 usages)
- [x] Each widget calls Initialize-Tui/Restore-Tui (7 pairs each)
- [x] Each widget sets $Script:TUI_RESULT with correct value format (31 assignments)
- [x] Checklist: Space toggle, * select-all, - deselect-all
- [x] Radio: (•)/(○) dot indicators, 0-based index result, -1 on cancel
- [x] YesNo: [ Yes ]/[ No ] highlight, Left/Right + Up/Down cycling, lowercase result
- [x] TextInput: cursor movement, backspace/delete, scroll, Esc-only cancel
- [x] All widgets have fallback modes via Read-Host
- [x] Commits 8f6f5de, f39f820, 02f552b all verified in git log
- [x] File grew from 776 to 1517 lines (741 new lines across 3 commits)
- [x] No file deletions detected
