# Phase 14: PowerShell Parity — Research

**Date:** 2026-07-14
**Status:** Complete

## Summary

Phase 14 ports all v1.1 + v2.0 features from flu.sh to flu.ps1, creating PowerShell-native .ps1 module scripts, adding caching/checksums/logging to the PowerShell module pipeline, implementing CLI batch mode, color themes, ASCII logo, and updating the fust Rust build for Windows cross-compilation.

## Patterns Discovered

### Existing flu.ps1 Architecture

```
flu.ps1 (497 lines)  → Main entry point, startup, CLI dispatch
tui.ps1 (1373+ lines) → TUI engine, widgets, keyboard input
menu.ps1 (485 lines)  → Menu DSL parser, navigation engine
modules.ps1 (672 lines) → Module fetch, metadata parse, execution
```

All four files are dot-sourced in dependency order: `tui.ps1 → menu.ps1 → modules.ps1` at lines 51-53 of flu.ps1.

### Pattern: PowerShell Module Scripts

Each .sh module script follows a contract:
- `#!/usr/bin/env sh` shebang
- `set -eu` strict mode
- `@name:`, `@params:`, `@platforms:`, `@version:`, `@deps:`, `@timeout:` comment headers
- `_maybe_sudo()` helper function
- `FLU_PKG_MGR` auto-detection (6 package managers)
- Idempotent guard: checks if tool already installed
- Exit code discipline (0 = success, non-zero = failure)

The .ps1 equivalent should:
- `$ErrorActionPreference = 'Stop'` instead of `set -eu`
- Same `@name:`, `@params:`, `@platforms:`, `@version:`, `@deps:`, `@timeout:` headers
- PowerShell-native package manager dispatch via `switch ($env:FLU_PKG_MGR)` (winget/choco/scoop)
- `Get-Command` for idempotent guards
- Same exit code discipline

### Pattern: Module Caching (from modules.sh)

```sh
FLU_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/flu.sh"
# Cache key: action ID
# TTL check: stat -c %Y vs current time
# Atomic write: write to .tmp then mv
```

PowerShell equivalent:
```powershell
$cacheDir = "$env:LOCALAPPDATA\flu-sh\cache"
# Cache key: action ID
# TTL check: (Get-Date) - (Get-Item $cacheFile).LastWriteTime
# Atomic write: Out-File to .tmp then Move-Item
```

### Pattern: SHA256 Checksums (from modules.sh)

```sh
expected=$(grep " $action" MANIFEST.sha256 | awk '{print $1}')
actual=$(printf '%s' "$content" | sha256sum | awk '{print $1}')
[ "$expected" = "$actual" ] || die "Checksum mismatch"
```

PowerShell equivalent:
```powershell
$expected = (Get-Content MANIFEST.sha256 | Select-String "$actionId " | ForEach-Object { $_ -split '\s+' | Select-Object -First 1 })
$actual = (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($content)))).Hash.ToLower()
```

### Pattern: Execution Logging (from modules.sh)

```sh
# TSV format: timestamp<tab>action_id<tab>operation<tab>result<tab>version<tab>duration_seconds
echo "timestamp\taction_id\t..." >> "${FLU_DATA_DIR}/execution.log"
```

PowerShell equivalent stores at `$env:APPDATA\flu-sh\execution.log`:
```powershell
"$timestamp`t$actionId`t$operation`t$result`t$version`t$duration" | Out-File -Encoding utf8 -Append $logFile
```

### Pattern: CLI Batch Mode (from flu.sh lines 90-168)

```sh
# Manual while/case parser for --flag value patterns
# --install <ids>, --remove <ids>, --list, --yes, --json, --help
# Dispatch: if --list → flu_batch_list; if --install/--remove → flu_batch_run
# Shell-based param binding for getopts limitation
```

PowerShell can use native `param()` binding:
```powershell
param(
    [string]$install,
    [string]$remove,
    [switch]$list,
    [switch]$yes,
    [switch]$json,
    [switch]$help
)
```

### Pattern: ASCII Logo (from flu.sh lines 236-301)

- 6-line ASCII art "dev-fu" LEGO-style block characters
- Magenta color via TUI_MAGENTA
- Rendered centered using `$termCols / 2 - $logoWidth / 2`
- Plain-text fallback when ANSI not available

The logo art is the same across platforms — identical string literal, just rendered via PowerShell's Write-Host or [Console]::SetCursorPosition.

### Pattern: Color Themes (new feature for both POSIX and PS)

D-17/D-18 define FLU_THEME env var with dark (default), light, monochrome.
Implementation approach:
- Define color palette arrays per theme at module load time
- Dark theme = current colors (TUI_CYAN=36, TUI_GREEN=32, etc.)
- Light theme = swap dark backgrounds (TUI_CYAN=94, TUI_GREEN=92, etc.)
- Monochrome = no ANSI colors (all reset to default)
- Apply at startup: `Apply-FluTheme` called after platform detection

## fust Cross-Compile

Current state:
- Cross.toml has only Linux ARM targets (no x86_64 or Windows)
- CI release.yml already has Windows targets:
  - `x86_64-pc-windows-msvc` on `windows-latest`
  - `aarch64-pc-windows-msvc` on `windows-latest`

Per D-13: keep only `x86_64-pc-windows-msvc`, remove `aarch64-pc-windows-msvc`.
Cross.toml needs `[target.x86_64-pc-windows-msvc]` section added (for local cross dev).

## Key Files

| File | Role | Changes Needed |
|------|------|----------------|
| `flu-sh/flu.ps1` | Main entry point | CLI batch mode, logo, startup, color theme init, registry pre-fetch |
| `flu-sh/tui.ps1` | TUI engine | Theme-aware color variables, `Apply-FluTheme`, logo render |
| `flu-sh/modules.ps1` | Module pipeline | Caching, checksums, logging, .ps1 resolution, community registry |
| `flu-sh/menu.ps1` | Menu navigation | No changes (menu.db is shared) |
| `flu-sh/modules-ps/` | New directory | 65+ .ps1 module scripts |
| `flu-sh/modules/MANIFEST.sha256` | Checksum manifest | Add entries for .ps1 module scripts |
| `fust/Cross.toml` | Cross-compile config | Add Windows x86_64 target |
| `.github/workflows/release.yml` | CI release | Already has Windows targets; remove aarch64 per D-13 |

## Risks

1. **PS 5.1 vs PS 7**: PS 5.1 has limited ANSI support and module resolution. All code must work on both.
2. **65+ module scripts**: Mechanical but tedious. Each ~30-60 lines of boilerplate with platform dispatch.
3. **Module caching on Windows**: %LOCALAPPDATA% path, Get-FileHash for checksums, atomic writes via Move-Item.
4. **Batch mode testing**: Hard to test without actual Windows CI runner. Core logic can be mocked.
5. **Color themes**: New feature for both platforms — no existing reference to copy from. Design from scratch.

## Recommendations

1. Split work into 3 plans: (a) modules.ps1 pipeline, (b) flu.ps1 CLI + tui.ps1 themes, (c) .ps1 module scripts + fust cross-compile
2. Use a template generator pattern for .ps1 module scripts — create one template, then instantiate for each .sh module
3. All Windows paths use `$env:LOCALAPPDATA` and `$env:APPDATA` per D-08/D-10
4. Default cache TTL: 6 hours on Windows (D-11), same TSV format (D-12)
