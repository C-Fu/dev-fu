---
phase: 14-powershell-parity
plan: 03
subsystem: powershell-parity
tags: [powershell, windows, module-scripts, cross-compile, fust]

requires:
  - phase: 14-powershell-parity
    plan: 02
    provides: CLI batch mode, ASCII logo, color themes for flu.ps1
provides:
  - .ps1 module script library with 67 scripts covering all install/remove/config operations
  - Windows x86_64 cross-compile target for fust Rust binary
  - Single Windows target (x86_64 only) in CI release workflow

tech-stack:
  added:
    - PowerShell module scripts for Windows package managers (winget/choco/scoop)
    - SHA256 checksum manifest for .ps1 modules
  patterns:
    - .ps1 module contract: @name/@platforms/@version/@timeout headers + $ErrorActionPreference + idempotent guard + platform dispatch
    - $env:FLU_PKG_MGR switch statement for winget/choco/scoop dispatch
    - Direct download pattern for GitHub releases (lazygit, etc.)

key-files:
  created:
    - flu-sh/modules-ps/*.ps1 (67 files)
    - flu-sh/modules-ps/MANIFEST.sha256
  modified:
    - fust/Cross.toml
    - .github/workflows/release.yml

key-decisions:
  - "Windows-only modules use @platforms: windows; Linux-only modules (avahi, systemd-resolved, eza, htop) use @platforms: linux with informational WSL message"
  - "Remove scripts follow winget/choco/scoop uninstall pattern with manual removal fallback"
  - "GSD packages installed via npm install -g @gsd-build/sdk (all variants install same package)"
  - "Direct download tools (lazygit) use GitHub releases with Invoke-WebRequest/Expand-Archive"
  - "fust CI builds Windows x86_64 only per D-13; aarch64-pc-windows-msvc removed"
  - "remove_node.ps1 added as extra module (no .sh counterpart) matching install_nvm_node"

requirements-completed:
  - PS-01

duration: 8m
completed: 2026-07-14
---

# Phase 14 Plan 03: PowerShell Module Scripts + fust Windows Cross-Compile

**67 .ps1 module scripts at flu-sh/modules-ps/ mirroring all .sh modules, with SHA256 manifest; fust builds Windows x86_64 via cross and CI**

## Performance

- **Duration:** 8 min
- **Tasks:** 2 of 2 completed
- **Files modified:** 69 (67 created + 2 modified)

## Accomplishments

- Created `flu-sh/modules-ps/` directory with 67 .ps1 module scripts covering every .sh module
- Every .ps1 script follows the contract: `# @name:`, `# @params:`, `# @platforms:`, `# @version:`, `# @timeout:` headers, `$ErrorActionPreference = 'Stop'`, idempotent guard, exit code discipline
- Platform dispatch via `$env:FLU_PKG_MGR` switch statement supporting winget/choco/scoop
- Generated `MANIFEST.sha256` with SHA256 checksums for all 67 .ps1 files (mitigates T-14-03-01)
- Added Linux-only informative scripts (avahi, systemd-resolved, eza, htop) that exit gracefully with WSL guidance
- Added `remove_node.ps1` as extra module (no .sh counterpart) for Node.js removal via NVM
- Updated `fust/Cross.toml` with `[target.x86_64-pc-windows-msvc]` section for local cross-compilation
- Removed `aarch64-pc-windows-msvc` from release.yml matrix — single Windows x86_64 target per D-13
- Verified Windows packaging steps (Compress-Archive, Get-FileHash) intact in release workflow

## Task Commits

Each task was committed atomically:

1. **task 1: Create .ps1 module scripts directory with all module scripts** - `a7caf9f` (feat)
2. **task 2: Update fust Cross.toml and release workflow for Windows x86_64** - `465661c` (feat)

## Files Created/Modified

### Created (flu-sh/modules-ps/)
- `install_lazygit.ps1` through `install_zoxide.ps1` (38 install scripts)
- `remove_lazygit.ps1` through `remove_php_laravel.ps1` (23 remove scripts + 1 extra)
- `create_fancy_prompt.ps1`, `create_fancy_prompt_blue.ps1`
- `configure_mouse_disable.ps1`, `configure_mouse_enable.ps1`
- `set_github_token.ps1`, `status_check.ps1`, `status_check_compare.ps1`, `upgrade_all.ps1`
- `MANIFEST.sha256` (67 SHA256 entries)

### Modified
- `fust/Cross.toml` — Added Windows x86_64 target section
- `.github/workflows/release.yml` — Removed aarch64-pc-windows-msvc, single x86_64 target

## Decisions Made

- **PS module naming:** File names match .sh counterparts exactly (e.g., `install_go.ps1` for `install_go.sh`)
- **Platform dispatch:** Used `switch ($env:FLU_PKG_MGR)` pattern matching winget/choco/scoop for all package-managed tools
- **Direct downloads:** GitHub release downloads use Invoke-WebRequest + Expand-Archive for zip archives
- **npm-based tools:** GSD packages all install `@gsd-build/sdk`; OpenChamber installs `@openchamber/web`
- **Linux-only modules:** Provide informational messages pointing to WSL installation — `@platforms: linux`
- **Windows CI target:** Single `x86_64-pc-windows-msvc` without aarch64 to match plan decision D-13

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Threat Surface

The threat model specified:
- T-14-03-01 (SHA256 checksums): Mitigated via MANIFEST.sha256 generation
- T-14-03-02 (Cross-compile binary): Accepted — binary built from trusted source in CI

No new threat surface introduced beyond what's in the plan's threat model.

## Stub Tracking

No stubs found. All scripts have real idempotent guards and meaningful content. Linux-only informational scripts (avahi, systemd-resolved, eza, htop, zsh) provide clear user guidance.

## Next Phase Readiness

- Complete .ps1 module library ready for integration with `flu.ps1` module pipeline
- fust build system supports Windows x86_64 cross-compilation for CI releases
- SHA256 manifest enables integrity verification in `flu.ps1` module fetching pipeline (future plan)
- Next: wire module resolution in flu.ps1 to use the .ps1 module scripts from `flu-sh/modules-ps/`

---
*Phase: 14-powershell-parity*
*Plan: 03*
*Completed: 2026-07-14*
