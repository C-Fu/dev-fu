#!/usr/bin/env pwsh
# ============================================================
# flu.ps1 — Modular TUI Menu System (PowerShell Port)
# ============================================================
# Description: A zero-dependency, irm-iex-ready TUI menu
#   that fetches and executes modular install scripts on demand.
#   PowerShell port of flu.sh — full feature parity.
# Compatibility: PowerShell 5.1+ / PowerShell 7+
# Branch: flu.sh (development), merged to main when stable
# ============================================================

# ──────────────
# 📡 TTY Reattachment (for irm | iex)
# ──────────────
# PowerShell equivalent of flu.sh's exec 0</dev/tty.
# When piped via Invoke-Expression (irm ... | iex), stdin is redirected.
# We need to re-attach to the console for interactive ReadKey.
# [Console]::OpenStandardInput() achieves this.
# If no console available, we fall through to fallback prompted mode.

if ([Console]::IsInputRedirected) {
    try {
        # Attempt to reattach to console stdin
        $stdin = [Console]::OpenStandardInput()
        # This works for irm | iex scenarios — Console.ReadKey will now read from console
    } catch {
        # No console available — TUI fallback mode will be used
    }
}

# ──────────────
# 📦 Subsystem Sourcing (per D-02)
# ──────────────
# Resolve script directory for dot-sourcing sibling files
$FLU_SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $FLU_SCRIPT_DIR) {
    $FLU_SCRIPT_DIR = Get-Location
}

# Source subsystems in dependency order (matching flu.sh D-01 order):
#   tui.ps1 first (TUI primitives)
#   menu.ps1 second (needs TUI_RESET)
#   modules.ps1 third (needs TUI_RESET + widgets)
. "$FLU_SCRIPT_DIR\tui.ps1"
. "$FLU_SCRIPT_DIR\menu.ps1"
. "$FLU_SCRIPT_DIR\modules.ps1"

# ──────────────
# 🛡 Signal-Safe Cleanup
# ──────────────
# Orchestrator-level safety net: ensures terminal is always restored.
# Matches flu.sh _flu_cleanup_exit() pattern.

function global:Exit-FluCleanup {
    # Restore terminal (idempotent — safe to call even if already restored)
    try { Restore-Tui } catch {}
    # Stop any running spinner
    try { Stop-FluSpinner } catch {}
    Write-Host "`nflu.ps1 — Goodbye!"
    exit 130
}

# Register Ctrl-C handler
[Console]::CancelKeyPress += {
    $eventArgs = $_.EventArgs
    $eventArgs.Cancel = $true  # Prevent immediate termination
    Exit-FluCleanup
}

# ──────────────
# 🔍 Platform Detection (per D-02, D-03)
# ──────────────
# Detect Windows platform, package manager, architecture, and WSL availability.
# Sets environment variables matching flu.sh flu_module_set_env().

function Get-FluPlatform {
    <#
    .SYNOPSIS
    Detect platform context and set FLU_* environment variables.
    PowerShell port of flu_module_set_env() adapted for Windows.

    .DESCRIPTION
    Sets: FLU_OS, FLU_DISTRO, FLU_PKG_MGR, FLU_ARCH,
          FLU_IS_WSL, FLU_IS_TERMUX, FLU_IS_ROOT (admin)
    #>
    # FLU_OS — always "windows" on flu.ps1 (PowerShell port target)
    $env:FLU_OS = "windows"

    # FLU_DISTRO — Windows version info
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $env:FLU_DISTRO = "$($osInfo.Caption) $($osInfo.Version)"
    } catch {
        $env:FLU_DISTRO = "Windows"
    }

    # FLU_PKG_MGR — detect available package manager
    $pkgMgr = "none"
    if (Get-Command winget -ErrorAction SilentlyContinue) { $pkgMgr = "winget" }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) { $pkgMgr = "choco" }
    elseif (Get-Command scoop -ErrorAction SilentlyContinue) { $pkgMgr = "scoop" }
    $env:FLU_PKG_MGR = $pkgMgr

    # FLU_ARCH — CPU architecture
    $env:FLU_ARCH = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM') { "arm64" } else { "x86_64" }

    # FLU_IS_WSL — detect WSL environment
    try {
        $wslCheck = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue)
        if ($wslCheck) { $env:FLU_IS_WSL = "1" } else { $env:FLU_IS_WSL = "0" }
    } catch {
        $env:FLU_IS_WSL = "0"
    }

    # WSL binary check (separate from FLU_IS_WSL — this is about wsl.exe availability)
    $Script:_fluHasWsl = $false
    try {
        if (Get-Command wsl.exe -ErrorAction SilentlyContinue) { $Script:_fluHasWsl = $true }
    } catch {}

    # FLU_IS_TERMUX — not applicable on Windows
    $env:FLU_IS_TERMUX = "0"

    # FLU_IS_ROOT — admin check
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    $env:FLU_IS_ROOT = if ($isAdmin) { "1" } else { "0" }

    # Also set for internal use
    $Script:FluPsVersion = $PSVersionTable.PSVersion
    $Script:FluIsWindows = $true
}

# ──────────────
# 🖥 Startup Platform Display
# ──────────────
# Show detected platform info before entering menu.
# PowerShell port of flu.sh startup display (lines 73-137).

function Show-FluStartup {
    <#
    .SYNOPSIS
    Display startup screen with detected platform info.
    PowerShell port of flu.sh startup display (lines 73-137).

    .DESCRIPTION
    Shows a bordered box with OS, Distro, Package Manager, Architecture.
    Press any key to continue to the main menu.
    Matches flu.sh visual output exactly (centered box, platform rows).
    #>
    if ($Script:_tui_use_tui) {
        Initialize-Tui
        Clear-TuiScreen

        $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
        $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }

        $boxWidth = 50
        if ($boxWidth -gt ($termCols - 4)) { $boxWidth = $termCols - 4 }
        $boxHeight = 9
        $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
        $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))

        Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight `
            -Title "$($Script:TUI_CYAN)flu.ps1 v0.1.0$($Script:TUI_RESET)"

        $infoX = $boxX + 3
        $row = $boxY + 3

        Write-TuiAt -Row $row -Col $infoX
        Write-Host "$($Script:TUI_BOLD)OS: $($env:FLU_OS)$($Script:TUI_RESET)" -NoNewline

        $row++
        Write-TuiAt -Row $row -Col $infoX
        Write-Host "$($Script:TUI_GREEN)Distro: $($env:FLU_DISTRO)$($Script:TUI_RESET)" -NoNewline

        $row++
        Write-TuiAt -Row $row -Col $infoX
        Write-Host "$($Script:TUI_YELLOW)Package Manager: $($env:FLU_PKG_MGR)$($Script:TUI_RESET)" -NoNewline

        $row++
        Write-TuiAt -Row $row -Col $infoX
        Write-Host "$($Script:TUI_CYAN)Architecture: $($env:FLU_ARCH)$($Script:TUI_RESET)" -NoNewline

        $row++
        Write-TuiAt -Row $row -Col $infoX
        $wslStatus = if ($Script:_fluHasWsl) { "Available" } else { "Not installed" }
        Write-Host "$($Script:TUI_CYAN)WSL: $wslStatus$($Script:TUI_RESET)" -NoNewline

        # Footer
        $footerRow = $boxY + 7
        Write-TuiAt -Row $footerRow -Col ($boxX + 3)
        Write-Host "$($Script:TUI_DIM)Press any key to continue...$($Script:TUI_RESET)" -NoNewline

        Read-TuiKey | Out-Null
        Restore-Tui
    } else {
        # Non-TUI: plain text
        Write-Host "flu.ps1 v0.1.0"
        Write-Host "OS: $($env:FLU_OS) | Distro: $($env:FLU_DISTRO)"
        Write-Host "Package Manager: $($env:FLU_PKG_MGR) | Arch: $($env:FLU_ARCH)"
        Write-Host ""
    }
}
