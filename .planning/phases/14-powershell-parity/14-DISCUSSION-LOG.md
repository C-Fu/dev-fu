# Phase 14: PowerShell Parity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 14-powershell-parity
**Areas discussed:** Module execution on Windows, CLI batch mode, Caching & checksums, Windows fust cross-compile, ASCII logo, Color themes, .ps1 module metadata, Platform dispatch

---

## Module Execution on Windows

| Option | Description | Selected |
|--------|-------------|----------|
| WSL/bash only (current) | Keep existing approach, modules run via WSL | |
| PowerShell-native module scripts | Create .ps1 versions of all 46+ modules alongside .sh | ✓ |
| Dual: .sh via WSL + .ps1 when available | Prefer .ps1 if available, fall back to .sh | |

**User's choice:** PowerShell-native module scripts

| Option | Description | Selected |
|--------|-------------|----------|
| One .ps1 per .sh module (full parity) | Create matching .ps1 for each of the 46+ modules | ✓ |
| Pilot with most common modules first | Start with most-used modules only | |
| Thin wrapper approach | Keep business logic in .sh, small .ps1 wrappers | |

**User's choice:** One .ps1 per .sh module (full parity)

| Option | Description | Selected |
|--------|-------------|----------|
| Same action_id, auto-detect by platform | flu.ps1 tries .ps1 first, falls back to .sh | ✓ |
| Separate action_ids | Different action_ids for PS modules | |

**User's choice:** Same action_id, auto-detect by platform

| Option | Description | Selected |
|--------|-------------|----------|
| Same directory: flu-sh/modules/ | .ps1 alongside .sh files | |
| Separate: flu-sh/modules-ps/ | Dedicated PS modules directory | ✓ |

**User's choice:** Separate: flu-sh/modules-ps/

---

## CLI Batch Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Same flags, PS param binding | --install/--remove/--list/--yes with PowerShell param() | ✓ |
| PowerShell-native flag style | -Install, -Remove, -List, -Confirm conventions | |

**User's choice:** Same flags, PS param binding

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same behavior | Continue on failure, print summary, exit 0/1 | ✓ |
| Strict mode: fail fast | Stop on first failure | |

**User's choice:** Yes, same behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Same as POSIX: reject with message | Modules with params rejected in --yes mode | ✓ |
| Allow param overrides via CLI | --param Name=Value syntax | |

**User's choice:** Same as POSIX: reject with message

---

## Caching & Checksums on Windows

| Option | Description | Selected |
|--------|-------------|----------|
| %LOCALAPPDATA%\flu-sh\cache | Standard Windows app data | ✓ |
| %TEMP%\flu-sh\cache | Ephemeral temp directory | |
| ~/.cache/flu.sh (same as POSIX) | Cross-platform path | |

**User's choice:** %LOCALAPPDATA%\flu-sh\cache

| Option | Description | Selected |
|--------|-------------|----------|
| Get-FileHash (PowerShell native) | Built-in SHA256 cmdlet | ✓ |
| certutil (legacy Windows) | Older Windows compatibility | |

**User's choice:** Get-FileHash (PowerShell native)

| Option | Description | Selected |
|--------|-------------|----------|
| %LOCALAPPDATA%\flu-sh\execution.log | Same base as cache | |
| %APPDATA%\flu-sh\execution.log | Roaming profile | ✓ |

**User's choice:** %APPDATA%\flu-sh\execution.log

| Option | Description | Selected |
|--------|-------------|----------|
| 24h (same as POSIX) | Same default TTL | |
| Shorter: 6h | Windows environments change more frequently | ✓ |

**User's choice:** Shorter: 6h

---

## Windows fust Cross-Compile

| Option | Description | Selected |
|--------|-------------|----------|
| x86_64-pc-windows-msvc only | 64-bit Intel/AMD Windows | ✓ |
| x86_64 + aarch64 MSVC | Both x86_64 and ARM64 Windows | |

**User's choice:** x86_64-pc-windows-msvc only

| Option | Description | Selected |
|--------|-------------|----------|
| Same release: bundled assets | Same version, same tag, new asset | ✓ |
| Separate Windows release track | Different versioning/cadence | |

**User's choice:** Same release: bundled assets

---

## ASCII dev-fu Logo

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same logo — magenta ANSI | Consistent branding across platforms | ✓ |
| Yes but Windows-adapted | Simplified for Windows terminals | |

**User's choice:** Yes, same logo — magenta ANSI

---

## Color Themes (FLU_THEME)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same FLU_THEME support | dark/light/monochrome, same env var | ✓ |
| Yes but with $env:FLU_THEME | Same feature, PS syntax | |

**User's choice:** Yes, same FLU_THEME support

---

## .ps1 Module Metadata Format

| Option | Description | Selected |
|--------|-------------|----------|
| Same @-prefixed comment headers as .sh | @name, @platforms, @deps, @timeout | ✓ |
| PowerShell comment-based help | .PARAMETER/.SYNOPSIS format | |

**User's choice:** Same @-prefixed comment headers

---

## Platform Dispatch in .ps1 Modules

| Option | Description | Selected |
|--------|-------------|----------|
| Same FLU_PKG_MGR pattern as .sh | $env:FLU_PKG_MGR with PS switch | ✓ |
| Native PowerShell detection | Each module detects its own | |

**User's choice:** Same FLU_PKG_MGR pattern

---

## OpenCode's Discretion

- Exact PowerShell implementation details for TUI updates
- ANSI color palette values for each theme
- Directory creation and permission handling for cache/log
- Function naming convention for new .ps1 module scripts
- CLI arg parsing implementation in flu.ps1
- Release workflow YAML changes for Windows cross-compile
- How existing subsystem files (tui.ps1, menu.ps1, modules.ps1) are updated

## Deferred Ideas

- ARM64 Windows fust target — future when ARM Windows adoption grows
- PowerShell registry for community modules — future phase
- Interactive @params support in batch mode (--param flag) — out of scope
- Automatic MANIFEST.sha256 generation for .ps1 modules — needs tooling update
- Progress bar for module downloads on PowerShell — Phase 10 deferred
- Color theme customization beyond dark/light/monochrome — future enhancement
