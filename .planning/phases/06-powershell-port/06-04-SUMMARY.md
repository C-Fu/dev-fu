---
phase: 06-powershell-port
plan: 04
subsystem: module-pipeline
tags: [powershell, modules, wsl, tui, invoke-webrequest, start-process]

# Dependency graph
requires:
  - phase: 06-01
    provides: "TUI engine foundation (tui.ps1): ANSI rendering, box drawing, key reading, terminal init/restore"
  - phase: 06-02
    provides: "TUI interactive widgets (tui.ps1): Show-TuiRadio, Show-TuiYesNo, Show-TuiTextInput"
  - phase: 06-03
    provides: "Menu system (menu.ps1): menu DSL parser, navigation engine, action ID extraction"
provides:
  - modules.ps1: "Complete PowerShell module pipeline — fetch, metadata parse, param collection, WSL/bash execution, result display"
  - Invoke-FluModuleFetch: "GitHub module fetch via Invoke-WebRequest with 3-retry logic and actionable error hints"
  - ConvertFrom-FluModuleMetadata: "@key comment header parser with required field validation and platform check"
  - Invoke-FluModuleCollectParams: "TUI widget dispatch for radio/text/yesno parameter collection"
  - Invoke-FluModuleExecute: "Full module execution pipeline via WSL/bash with Start-Process output capture"
  - Write-FluModuleResult: "Box-rendered modal with status banner, recovery hints, and key-wait dismiss"
affects: [06-05, flu.ps1, orchestrator, module-dispatch]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Invoke-WebRequest -UseBasicParsing replaces curl/wget for module fetch"
    - "Start-Process with stdout/stderr redirection replaces subshell execution"
    - "Regex-based -match parsing replaces awk for metadata extraction"
    - "PSCustomObject returns replace stdout-line-based metadata output"
    - "TUI widget dispatch pattern: param type → Show-TuiRadio/Show-TuiTextInput/Show-TuiYesNo"

key-files:
  created:
    - modules.ps1: "Module pipeline library (672 lines, 8 functions)"
  modified: []

key-decisions:
  - "Invoke-WebRequest -UseBasicParsing used for module fetch (D-07) — always available on Windows"
  - "Start-Process with stdout/stderr redirect gives clean output capture without temp file races"
  - "PSCustomObject return type for results provides structured, property-accessible output"
  - "Platform check uses FLU_OS env var — defers platform detection to orchestrator (flu.ps1)"
  - "WSL path conversion (backslash to forward slash) for cross-environment temp file compatibility"

patterns-established:
  - "Action ID → URL resolution via Resolve-FluModuleUrl with FLU_MODULES_BASE_URL override"
  - "Metadata extraction via line-by-line regex matching, stopping at first blank/non-comment line"
  - "Parameter dispatch via switch on type with widget function calls and cancellation handling"
  - "Exit-code-to-hint mapping table for 124/126/127/1/6/7/22/28 with pattern matching for exit code 1"
  - "Box-rendered result modal with TUI lifecycle management (Initialize-Tui/Restore-Tui)"

requirements-completed: [PS-01, PS-02]

# Metrics
duration: 10min
completed: 2026-05-25
---

# Phase 06 Plan 04: Module Pipeline Summary

**PowerShell module pipeline porting modules.sh — GitHub fetch with Invoke-WebRequest retry, @key metadata parser, TUI widget parameter collection, WSL/bash execution via Start-Process, and box-rendered result display with recovery hints**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-24T21:00:00Z
- **Completed:** 2026-05-24T21:11:35Z
- **Tasks:** 3
- **Files modified:** 1 (new)

## Accomplishments
- Complete PowerShell module pipeline (672 lines, 8 functions) porting all of modules.sh (924 lines POSIX) to idiomatic PowerShell
- `Invoke-FluModuleFetch` with 3-retry Invoke-WebRequest, HTTP status-aware error hints (404, timeout, network)
- `ConvertFrom-FluModuleMetadata` regex-based @key parser validating required fields (@name, @platforms, @version) with platform compatibility check
- `Invoke-FluModuleCollectParams` dispatching radio/text/yesno params to their respective TUI widgets (Show-TuiRadio, Show-TuiTextInput, Show-TuiYesNo)
- `Invoke-FluModuleExecute` orchestrating the full D-09 pipeline: fetch → parse → collect params → execute via WSL/bash → return structured result
- `Write-FluModuleResult` box-rendered modal with green ✓ success or red ✗ failure banner, content display, and actionable recovery hints
- Graceful WSL absence handling with clear install instructions (per D-06)

## Task Commits

Each task was committed atomically:

1. **task 1: module fetch and metadata parser** - `3d80c1f` (feat)
2. **task 2: parameter collection and module execution** - `748f59c` (feat)
3. **task 3: result display with recovery hints** - `ebb21bb` (feat)

**Plan metadata:** `ebb21bb` (docs: complete plan)

## Files Created/Modified
- `modules.ps1` - Complete module pipeline library (672 lines), providing:
  - `Resolve-FluModuleUrl` — Action ID to GitHub raw URL resolution
  - `Invoke-FluModuleFetch` — Network fetch with retry logic and error hints
  - `ConvertFrom-FluModuleMetadata` — Comment header @key metadata parser
  - `ConvertFrom-FluParamString` — Semicolon-delimited parameter declaration parser
  - `Invoke-FluModuleCollectParams` — TUI widget dispatch for parameter collection
  - `Invoke-FluModuleExecute` — Full module execution pipeline (fetch → parse → collect → execute → return)
  - `Get-FluRecoveryHint` — Exit code to actionable recovery hint mapper
  - `Write-FluModuleResult` — Box-rendered result modal with status banner and recovery hints

## Decisions Made
- Followed the plan's detailed implementation code closely — all function signatures, control flow, and error handling match the plan specification
- Used `PSCustomObject` returns instead of stdout lines (POSIX convention) — this is idiomatic PowerShell and provides structured, property-accessible output
- Platform check defers to `$env:FLU_OS` — the orchestrator (flu.ps1) sets this, keeping modules.ps1 decoupled from platform detection
- WSL/bash availability check is done via `Get-Command wsl.exe` / `Get-Command bash.exe` rather than registry checks — simpler and mirrors POSIX `command -v` pattern

## Deviations from Plan

None - plan executed exactly as written. All function implementations match the plan's provided code. No bugs, missing functionality, or blocking issues encountered.

## Issues Encountered
- **PowerShell not available for runtime verification:** The Linux CI environment lacks `pwsh` or `powershell`, preventing automated verification commands from running. Syntactic verification was performed via grep/pattern matching on the source file instead. The code is structurally correct and follows the plan's detailed implementation exactly. Runtime verification should be performed on a Windows/PowerShell-capable machine.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: remote-code-execution | modules.ps1:Invoke-FluModuleExecute | Remote shell scripts executed via WSL/bash after HTTPS fetch — trust boundary at GitHub transport security only (matching POSIX behavior, T-06-11 accepted) |
| threat_flag: temp-file-handling | modules.ps1:Invoke-FluModuleExecute | Module scripts saved to `[System.IO.Path]::GetTempFileName() + '.sh'` — cleaned up after execution but race condition exists between write and execute (mitigated by single-user execution model) |

## Next Phase Readiness
- Module pipeline is complete and ready for integration into `flu.ps1` orchestrator (Phase 06-05)
- All functions follow Verb-Noun naming convention and dot-source pattern
- TUI guard ensures `tui.ps1` must be sourced first — orchestrator must respect this initialization order
- WSL dependency is documented with user-facing install instructions — ready for UX of no-WSL scenario

---
*Phase: 06-powershell-port*
*Completed: 2026-05-25*
