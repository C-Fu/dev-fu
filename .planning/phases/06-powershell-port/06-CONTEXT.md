# Phase 6: PowerShell Port - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `flu.ps1` — a PowerShell port of `flu.sh` delivering full feature parity on Windows and cross-platform PowerShell. Same TUI, menus, widgets, module pipeline. Works on both PowerShell 5.1 (Windows built-in) and PowerShell 7 (cross-platform).

**Scope anchor:** Pure porting — no new features. All UX decisions are locked by the POSIX implementation (Phases 1-5). The task is adapting shell patterns to PowerShell idioms.

**Requirements:** PS-01, PS-02, PS-03
</domain>

<decisions>
## Implementation Decisions

### Port strategy
- **D-01:** New `flu.ps1` written from scratch, following the structure and patterns of `flu.sh`. `fu.ps1` is a reference only — not modified, not refactored.
- **D-02:** Same architecture as flu.sh: source subsystems → platform detect → TUI init → menu loop → module dispatch → result display. PowerShell-native implementation of each step.

### PowerShell version support
- **D-03:** Support both PowerShell 5.1 and PowerShell 7 with runtime feature detection. PS 5.1 is the baseline (lowest common denominator). PS 7 features used when available.
- **D-04:** ANSI escape code detection at startup. PS 5.1 does not support ANSI natively — enable via `[Console]::OutputEncoding` and VT processing mode, or fall back to ASCII rendering if PS version < 5.1 or Virtual Terminal not available.
- **D-05:** `flu.ps1` detects the PowerShell version at startup via `$PSVersionTable.PSVersion` and adapts capabilities. UTF-8 box drawing, Unicode glyphs, and rich ANSI only used when the terminal supports it.

### Module execution
- **D-06:** Same GitHub module repo (`flu-modules`). Flu.ps1 fetches the same `.sh` modules and executes them via WSL/bash on Windows. On systems without WSL, the module execution path is gracefully unavailable with a clear message.
- **D-07:** Module pipeline adapted for PowerShell: `Invoke-WebRequest` replaces curl, `Start-Process` replaces subshell execution, module output captured via PowerShell's native stream handling.

### UI parity
- **D-08:** TUI rendering mirrors flu.sh exactly: full-screen boxes, reverse-video highlight, scroll indicators, breadcrumb, status line, help footer. Same visual language, different implementation.
- **D-09:** Keyboard input via `[Console]::ReadKey()` — PowerShell's native single-keypress API. Arrow keys, PgUp/PgDn, Home/End, Enter, Esc, Space all mapped to consistent constants.
- **D-10:** Widget parity: single-select, checklist, radio, yesno, text input — all match the POSIX behavior from flu.sh's tui.sh widgets.

### OpenCode's Discretion
- Exact PowerShell implementation of each TUI render function
- ANSI sequence encoding in PowerShell (backtick-e vs `[char]0x1B`)
- Platform detection for Windows (OS version, package manager availability: winget, choco, scoop)
- Function naming convention (PowerShell Verb-Noun vs shell function names)
- How WSL/bash is invoked for module execution (which distro, error handling)
- Signal handling in PowerShell (trap vs try/catch/finally)
</decisions>

<specifics>
## Specific Ideas

- flu.ps1 should feel like a natural PowerShell script — PowerShell users shouldn't feel like they're running a bash script through a translator
- The TUI should look identical to flu.sh — same box borders, same highlight, same breadcrumb
- On PS 5.1 without ANSI support, the experience should still be usable via ASCII fallback — even if less pretty
</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 6 goal, success criteria, requirements (PS-01, PS-02, PS-03)
- `.planning/REQUIREMENTS.md` — PS-01 (same TUI), PS-02 (same modules with adapted args), PS-03 (PS 5.1 + PS 7)

### POSIX implementation (behavioral reference)
- `flu.sh` (285 lines) — Main entry point, TTY reattach, menu loop, module dispatch. The PowerShell port mirrors this structure.
- `tui.sh` (2130+ lines) — Full TUI engine: all 5 widgets, box rendering, key reading, fallback mode, spinner. PowerShell port reimplements this natively.
- `menu.sh` (780 lines) — Menu navigation, breadcrumb, DSL parsing. PowerShell port replicates this.
- `modules.sh` (924 lines) — Module fetch, parse, prompt, execute, display pipeline. PowerShell port adapts for Windows.
- `menu.db` (16 lines) — Menu DSL definition. Shared unchanged — same file used by both flu.sh and flu.ps1.

### Prior context
- `.planning/phases/01-tui-engine-core/01-CONTEXT.md` — TUI visual decisions (box rendering, highlight, scroll indicators, footer, fallback)
- `.planning/phases/02-interactive-widgets/02-CONTEXT.md` — Widget UX decisions (checklist, radio, yesno, text_input behavior and return conventions)
- `.planning/phases/03-menu-system/03-01-SUMMARY.md` — Menu DSL format and tree query API
- `.planning/phases/04-module-architecture/04-CONTEXT.md` — Module pipeline decisions (D-09 flow, platform env vars, result display)
- `.planning/phases/05-integration-&-orchestrator/05-CONTEXT.md` — Orchestrator flow, error recovery, signal safety

### Pattern reference
- `fu.ps1` (1971 lines) — Existing PowerShell utility. Reference for: platform detection, package manager detection (winget/choco/scoop), version comparison patterns. Pattern reference ONLY — do NOT copy or refactor.
- `.planning/codebase/ARCHITECTURE.md` — fu.ps1 structure, layer breakdown
- `.planning/codebase/INTEGRATIONS.md` — winget, choco, scoop integration patterns

### Constraints
- `.planning/PROJECT.md` — PowerShell parity constraint
- `.planning/codebase/CONVENTIONS.md` — PowerShell naming conventions
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `flu.sh` (285 lines): Complete POSIX orchestrator. Reference for main loop structure, initialization order, error handling flow.
- `fu.ps1` (1971 lines): Existing PowerShell script. Reference for: platform detection, package manager detection (winget, choco, scoop), GitHub API interaction, version comparison, `Write-Host` color patterns.
- `menu.db` (16 lines): Menu definition — used unchanged by both flu.sh and flu.ps1.
- `flu-modules` repo (external): Same module scripts fetched by both POSIX and PowerShell ports.

### Established Patterns (from flu.sh)
- Source subsystems → platform detect → TUI init → menu loop → module dispatch → result display
- TTY reattachment for curl-pipe-bash equivalent (`irm ... | iex`)
- Spinner during network operations
- Exit code → recovery message mapping
- Signal-safe terminal restoration

### Integration Points
- Same `menu.db` file — PowerShell port parses the same DSL format
- Same `flu-modules` GitHub repo — PowerShell fetches same action_id → URL
- Separate file (`flu.ps1`) — no sharing with flu.sh beyond the DSL file and module repo
- `irm ... | iex` equivalent pattern to curl-pipe-bash for PowerShell

### Platform-Specific Considerations (from ROADMAP/REQUIREMENTS)
- PS 5.1: Built into Windows, no ANSI support natively, limited module support
- PS 7: Cross-platform (Windows, macOS, Linux), full ANSI support, richer module system
- Package managers: winget (Windows 10+), choco, scoop
- Module execution: WSL/bash for POSIX modules, winget/choco for native Windows
</code_context>

<deferred>
## Deferred Ideas

- CLI batch mode for PowerShell — INTG-06 (v2)
- PowerShell module caching with TTL — MODL-07 (v2)
- SHA256 checksum verification for modules — MODL-08 (v2)
- Color themes via FLU_THEME env var — INTG-07 (v2)
</deferred>

---

*Phase: 06-powershell-port*
*Context gathered: 2026-05-25*
