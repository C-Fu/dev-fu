# Phase 14: PowerShell Parity - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Windows and PowerShell users get all v1.1 + v2.0 features in flu.ps1 — expanded menu, .ps1 module scripts, SHA256 checksums, module caching, CLI batch mode, color themes, modern CLI tools, and ASCII dev-fu logo. Cross-compile fust Rust binary for Windows x86_64 targets.

**Requirements:** PS-01

**Success Criteria:**
1. User running flu.ps1 sees the same expanded menu with all v1.1 + v2.0 tool entries as flu.sh
2. User running flu.ps1 benefits from SHA256 checksum verification and module caching during script fetching
3. User running flu.ps1 can use CLI batch mode (`flu.ps1 --install ... --yes`) and color themes (`$env:FLU_THEME`)
4. User running flu.ps1 can install/remove the four modern CLI tools (lazygit, starship, zoxide, eza) where platform-appropriate

</domain>

<decisions>
## Implementation Decisions

### Module Execution on Windows
- **D-01:** PowerShell-native .ps1 module scripts — one .ps1 per .sh module, full parity (46+ modules)
- **D-02:** Same action_id across platforms — flu.ps1 tries .ps1 first, falls back to .sh via WSL if no .ps1 exists
- **D-03:** .ps1 modules live in `flu-sh/modules-ps/` — separate directory from .sh modules
- **D-04:** Module resolution auto-detects by platform — extension is not part of action_id

### CLI Batch Mode for PowerShell
- **D-05:** Same CLI flags as flu.sh — `--install`, `--remove`, `--list`, `--yes` — using PowerShell param() binding
- **D-06:** Same batch behavior — continue on failure, collect results, print summary, exit 0 if all succeed / 1 if any fail
- **D-07:** Modules with @params rejected in --yes mode with clear message (same as POSIX)

### Caching & Checksums on Windows
- **D-08:** Cache directory: `%LOCALAPPDATA%\flu-sh\cache`
- **D-09:** Checksum verification via `Get-FileHash -Algorithm SHA256` (PowerShell native)
- **D-10:** Execution log: `%APPDATA%\flu-sh\execution.log` (roaming app data)
- **D-11:** Default cache TTL: 6 hours on Windows (shorter than POSIX 24h)
- **D-12:** Same TSV log format as POSIX: timestamp, action_id, operation, result, version, duration

### Windows fust Cross-Compile
- **D-13:** Target: `x86_64-pc-windows-msvc` only (64-bit Intel/AMD)
- **D-14:** Bundled in same GitHub release as Linux/macOS — same version, same tag, new release asset

### ASCII Logo & Branding
- **D-15:** Same magenta ASCII dev-fu logo as flu.sh on startup — consistent branding
- **D-16:** Logo renders in ANSI color when terminal supports it, plain text fallback otherwise

### Color Themes
- **D-17:** Same `FLU_THEME` env var support as flu.sh — dark (default), light, monochrome
- **D-18:** PowerShell adapts ANSI color palette per theme, same visual output

### Module Script Format
- **D-19:** .ps1 modules use same @-prefixed comment headers as .sh — `@name`, `@platforms`, `@deps`, `@timeout`
- **D-20:** Platform dispatch via `$env:FLU_PKG_MGR` with PowerShell switch statement — same pattern as .sh but PowerShell syntax
- **D-21:** .ps1 modules follow same contract: idempotent guards, exit codes, timeout enforcement

### OpenCode's Discretion
- Exact PowerShell implementation of each TUI render function update
- ANSI color palette values for each theme
- Directory creation and permission handling for cache/log dirs
- Function naming convention (Verb-Noun) for new .ps1 module scripts
- How existing tui.ps1/menu.ps1/modules.ps1 are updated to support new features
- Exact CLI arg parsing implementation in flu.ps1
- Release workflow YAML changes for Windows cross-compile

</decisions>

<specifics>
## Specific Ideas

- flu.ps1 should feel like a natural PowerShell evolution — same visual output as flu.sh, PowerShell-native under the hood
- Module caching and checksums should be transparent to the user (auto-handled)
- CLI batch mode summary: "3 succeeded, 1 failed" with individual results listed — same format as POSIX
- Windows fust binary should be `fust-x86_64-pc-windows-msvc.zip` in release assets
- The existing `flu.ps1` is the entry point — subsystem files (tui.ps1, menu.ps1, modules.ps1) need updating too

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Requirements
- `.planning/ROADMAP.md` — Phase 14 goal, success criteria, PS-01 requirement
- `.planning/REQUIREMENTS.md` — PS-01: flu.ps1 mirrors all v1.1 + v2.0 features

### Existing PowerShell Implementation
- `flu-sh/flu.ps1` — Main entry point (497 lines). Needs CLI batch mode, logo, startup changes
- `flu-sh/tui.ps1` — TUI rendering subsystem. Needs color theme support, logo rendering
- `flu-sh/menu.ps1` — Menu navigation subsystem. Likely no changes (menu.db is shared)
- `flu-sh/modules.ps1` — Module fetch/execute pipeline. Needs .ps1 module support, caching, checksums, logging

### POSIX Reference (behavioral parity target)
- `flu.sh` — POSIX orchestrator (reference for CLI batch mode behavior, logo, startup flow)
- `tui.sh` — POSIX TUI engine (reference for color theme implementation)
- `modules.sh` — POSIX module pipeline (reference for cache/checksum/log patterns)
- `menu.db` — Shared menu DSL definition (no changes needed)
- `flu-sh/modules/MANIFEST.sha256` — Checksum manifest format reference

### Prior Phase Context
- `.planning/phases/06-powershell-port/06-CONTEXT.md` — Original PS port decisions (PS 5.1 + PS 7, ANSI detection, WSL fallback)
- `.planning/phases/10-module-pipeline-hardening/10-CONTEXT.md` — Cache/checksum/log decisions for POSIX (adapted for Windows here)
- `.planning/phases/11-modern-cli-tools/11-CONTEXT.md` — 8 module script patterns for lazygit/starship/zoxide/eza
- `.planning/phases/12-advanced-module-system/12-CONTEXT.md` — CLI batch mode flag design, registry architecture

### fust (Rust Binary)
- `fust/Cargo.toml` — Current deps, separate reqwest TLS for unix vs windows
- `fust/Cross.toml` — Cross-compile config, needs Windows target added
- `fust/src/main.rs` — Main entry point

### Constraints
- `.planning/PROJECT.md` — PowerShell parity constraint (flu.ps1 mirrors flu.sh features)
- `.planning/codebase/ARCHITECTURE.md` — System overview, data flow

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `flu.ps1` (497 lines): Main entry point. Structure to extend: function-by-function additions for batch mode, logo, color themes
- `fu.ps1` (2002 lines): Legacy PowerShell script. Reference for: package manager detection (winget/choco/scoop), Windows-native install patterns, Get-FileHash usage
- `tui.ps1` / `menu.ps1` / `modules.ps1` — Subsystem files that need parallel updates
- `fust/Cargo.toml` — Already has conditional deps for windows (default-tls vs rustls-tls)
- `.github/workflows/release.yml` — CI release workflow, needs Windows target added

### Established Patterns
- Subsystem sourcing in dependency order: tui.ps1 → menu.ps1 → modules.ps1
- FLU_* env var naming convention for configuration
- Platform detection via Get-FluPlatform() sets $env:FLU_* variables
- Module execution via Invoke-FluModuleExecute() — 7-step pipeline
- [Console]::ReadKey() for keyboard input, Start-Job for async spinner
- `irm ... | iex` equivalent pattern for remote execution

### Integration Points
- `flu.ps1:474-490` — Start-Flu function, main entry point. CLI arg parsing needs to go before Get-FluPlatform or after
- `flu.ps1:334-425` — Start-FluMainLoop, main event loop. Batch mode intercepts before this
- `modules.ps1` — Invoke-FluModuleFetch() needs caching + checksum integration
- `modules.ps1` — Invoke-FluModuleExecute() needs logging integration and .ps1 module resolution
- `tui.ps1` — TUI color variables need theme support (TUI_CYAN → theme-aware)
- `fust/Cross.toml` — Add [target.x86_64-pc-windows-msvc] section
- `.github/workflows/release.yml` — Add Windows cross-compile step

### Windows-Specific Considerations
- PS 5.1: Built into Windows, no ANSI support natively, limited module support
- PS 7: Cross-platform, full ANSI support, richer module system
- Cache dir: %LOCALAPPDATA% (not XDG)
- Package managers: winget (Windows 10+), choco, scoop
- Get-FileHash instead of sha256sum
- Log dir: %APPDATA% (roaming)

</code_context>

<deferred>
## Deferred Ideas

- ARM64 Windows fust target — future when ARM Windows adoption grows
- PowerShell registry for community modules — Phase 14 focuses on parity, registry will come later
- Interactive @params support in batch mode (--param flag) — out of scope for this phase
- Automatic MANIFEST.sha256 generation for .ps1 modules — needs tooling update
- Progress bar for module downloads on PowerShell — Phase 10 deferred, same for PS
- Color theme customization beyond dark/light/monochrome — future enhancement

</deferred>

---

*Phase: 14-powershell-parity*
*Context gathered: 2026-07-14*
