#!/usr/bin/env pwsh
# ============================================================
# flu.ps1 — Modular TUI Menu System (PowerShell Port)
# ============================================================
# Description: A zero-dependency, irm-iex-ready TUI menu
#   that fetches and executes modular install scripts on demand.
#   PowerShell port of flu.sh — full feature parity.
# Compatibility: PowerShell 5.1+ / PowerShell 7+
# Branch: main (source of truth), modules fetched from main/flu-sh/modules/
# ============================================================
# Deployment:
#   Local:  .\flu.ps1
#   Remote: irm https://raw.githubusercontent.com/C-Fu/dev-fu/main/flu-sh/flu.ps1 | iex
#   Requires: PowerShell 5.1+ (Windows) or PowerShell 7 (cross-platform)
#   Sibling files: tui.ps1, menu.ps1, modules.ps1, menu.db must be in same directory
# ============================================================

# ──────────────
# 📋 CLI Argument Parsing (matching flu.sh behavior — before TTY reattach)
# ──────────────
# D-05: Same CLI flags as flu.sh — --install, --remove, --list, --yes, --json, --help
# PowerShell param() binding provides native argument parsing.

param(
    [string]$install,
    [string]$remove,
    [switch]$list,
    [switch]$yes,
    [switch]$json,
    [switch]$help
)

# ──────────────
# 📋 Early CLI Detection (before TTY reattach — matching flu.sh behavior)
# ──────────────

$Script:_fluIsCli = $help -or $list -or $install -or $remove

if ($help) {
    Write-Host "Usage: flu.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --install <ids>  Install modules (comma-separated action IDs)"
    Write-Host "  --remove <ids>   Remove modules (comma-separated action IDs)"
    Write-Host "  --list           List available modules"
    Write-Host "  --yes            Skip confirmations (batch mode)"
    Write-Host "  --json           JSON output (with --list)"
    Write-Host "  --help           Show this help message"
    exit 0
}

if ($list) {
    # Source subsystems needed for listing
    $Script:FLU_SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $Script:FLU_SCRIPT_DIR) { $Script:FLU_SCRIPT_DIR = Get-Location }
    . "$Script:FLU_SCRIPT_DIR\tui.ps1"
    . "$Script:FLU_SCRIPT_DIR\modules.ps1"
    Get-FluPlatform
    Apply-FluTheme
    if ($json) {
        Invoke-FluBatchList -JsonMode
    } else {
        Invoke-FluBatchList
    }
    exit 0
}

if ($install -or $remove) {
    $Script:FLU_SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $Script:FLU_SCRIPT_DIR) { $Script:FLU_SCRIPT_DIR = Get-Location }
    . "$Script:FLU_SCRIPT_DIR\tui.ps1"
    . "$Script:FLU_SCRIPT_DIR\modules.ps1"
    Get-FluPlatform
    Apply-FluTheme

    $allActions = @()
    if ($install) { $allActions += ($install -split ',') | ForEach-Object { $_.Trim() } }
    if ($remove) { $allActions += ($remove -split ',') | ForEach-Object { $_.Trim() } }

    $flags = if ($yes) { "yes" } else { "" }

    $exitCode = Invoke-FluBatchRun -ActionIds $allActions -Flags $flags
    exit $exitCode
}

# Not in CLI mode — proceed normally (TTY reattach, etc.)
$Script:_fluIsCli = $false

# ──────────────
# 📡 TTY Reattachment (for irm | iex)
# ──────────────
# PowerShell equivalent of flu.sh's exec 0</dev/tty.
# When piped via Invoke-Expression (irm ... | iex), stdin is redirected.
# We need to re-attach to the console for interactive ReadKey.
# [Console]::OpenStandardInput() achieves this.
# If no console available, we fall through to fallback prompted mode.

if (-not $Script:_fluIsCli -and [Console]::IsInputRedirected) {
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
$Script:FLU_VERSION = "v3.0.0-alpha.6"

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
    Display startup screen with ASCII logo and platform info.
    PowerShell port of flu.sh startup display (lines 303-378) with logo.

    .DESCRIPTION
    Shows the ASCII dev-fu logo at top, then a bordered box with
    OS, Distro, Package Manager, Architecture, WSL status.
    Press any key to continue to the main menu.
    Matches flu.sh visual output exactly (logo + centered box).
    #>
    if ($Script:_tui_use_tui) {
        Initialize-Tui
        Clear-TuiScreen

        $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
        $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }

        # Render logo first (6 lines, top of screen)
        Show-FluLogo

        # Platform info box below logo
        $boxWidth = 50
        if ($boxWidth -gt ($termCols - 4)) { $boxWidth = $termCols - 4 }
        $boxHeight = 9
        $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
        $boxY = 7  # 6 logo lines + 1 gap

        Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight `
            -Title "$($Script:TUI_CYAN)flu.ps1 $($Script:FLU_VERSION)$($Script:TUI_RESET)"

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
        # Non-TUI: plain text logo
        Write-Host "=============================================="
        Write-Host "  dev-fu — Environment Setup Utility"
        Write-Host "=============================================="
        Write-Host ""
        Write-Host "flu.ps1 $($Script:FLU_VERSION)"
        Write-Host "OS: $($env:FLU_OS) | Distro: $($env:FLU_DISTRO)"
        Write-Host "Package Manager: $($env:FLU_PKG_MGR) | Arch: $($env:FLU_ARCH)"
        Write-Host ""
    }
}

# ──────────────
# 🩺 Error Recovery Mapping
# ──────────────
# Maps exit codes from Invoke-FluModuleExecute to actionable user hints.
# Called after module execution in the main loop.
# Each hint tells the user WHAT to do, not just what failed.

function Write-FluExitCodeHint {
    <#
    .SYNOPSIS
    Map module exit code to actionable recovery hint.
    PowerShell port of _flu_map_exit_code().

    .PARAMETER ExitCode
    Module exit code.
    .PARAMETER ActionId
    Action identifier for context in hints.

    .DESCRIPTION
    Displays human-readable recovery hints with → arrow prefix.
    Matching flu.sh _flu_map_exit_code() exit code mappings exactly.
    #>
    param([int]$ExitCode, [string]$ActionId)

    switch ($ExitCode) {
        0 { break }  # Success — no hint needed
        124 {
            Write-Host "$($Script:TUI_YELLOW)⏱ Timeout: The operation took too long.$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → Try again. If the issue persists, check your network speed or run during off-peak hours.$($Script:TUI_RESET)"
        }
        126 {
            Write-Host "$($Script:TUI_YELLOW)🔒 Permission denied: The module script could not be executed.$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → This may indicate a corrupted download. Try running the operation again.$($Script:TUI_RESET)"
        }
        127 {
            Write-Host "$($Script:TUI_YELLOW)❓ Command not found: A required dependency is missing.$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → Ensure all dependencies for `"$ActionId`" are installed before retrying.$($Script:TUI_RESET)"
        }
        1 {
            Write-Host "$($Script:TUI_RED)✗ Operation failed (exit code 1).$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → Check your internet connection if this was a network operation.$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → Try running the operation again.$($Script:TUI_RESET)"
        }
        default {
            Write-Host "$($Script:TUI_RED)✗ Operation exited with code $ExitCode.$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)   → An unexpected error occurred. Try running the operation again.$($Script:TUI_RESET)"
        }
    }
}

# ──────────────
# 🌀 Spinner Animation
# ──────────────
# Visual feedback during network/execution operations.
# Uses PowerShell Start-Job for async spinner rendering.
# Matches flu.sh flu_spinner_start() / flu_spinner_stop() behavior.

# Spinner state
$Script:_fluSpinnerJob = $null
$Script:_fluSpinnerRunning = $false
$Script:_fluSpinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')

function Start-FluSpinner {
    <#
    .SYNOPSIS
    Start rotating spinner animation in background.
    PowerShell port of flu_spinner_start().

    .DESCRIPTION
    Uses PowerShell Runspace for async spinner rendering.
    Renders rotating braille characters at bottom-right of terminal.
    Matching flu.sh spinner behavior: visible during network operations.
    #>
    if ($Script:_fluSpinnerRunning) { return }

    $Script:_fluSpinnerRunning = $true
    $Script:_fluSpinnerJob = Start-Job -ScriptBlock {
        $chars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
        $i = 0
        while ($true) {
            $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
            $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
            $msg = " $($chars[$i % $chars.Count]) Loading..."
            [Console]::SetCursorPosition($termCols - $msg.Length - 1, $termRows - 2)
            Write-Host $msg -NoNewline
            $i++
            Start-Sleep -Milliseconds 100
        }
    }
}

function Stop-FluSpinner {
    <#
    .SYNOPSIS
    Stop rotating spinner animation.
    PowerShell port of flu_spinner_stop().
    #>
    if (-not $Script:_fluSpinnerRunning) { return }

    $Script:_fluSpinnerRunning = $false
    if ($Script:_fluSpinnerJob) {
        Stop-Job -Job $Script:_fluSpinnerJob -ErrorAction SilentlyContinue
        Remove-Job -Job $Script:_fluSpinnerJob -ErrorAction SilentlyContinue
        $Script:_fluSpinnerJob = $null
    }

    # Clear spinner line
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    [Console]::SetCursorPosition(0, $termRows - 2)
    Write-Host (' ' * 20) -NoNewline
}

# ──────────────
# 🔄 Main Event Loop
# ──────────────
# Core interactive loop: menu navigation → action extraction → module execution
# → result display → error recovery. PowerShell port of flu.sh main loop.
# PowerShell port of flu.sh main loop (lines 209-285).

function Start-FluMainLoop {
    <#
    .SYNOPSIS
    Main interactive event loop.
    PowerShell port of flu.sh main loop (lines 209-285).

    .DESCRIPTION
    1. Menu Navigation → flu_menu_navigate(menu_file)
    2. Extract Action → flu_menu_get_action(TUI_RESULT)
    3. Module Execution → spinner + flu_module_execute(action) + result display
    4. Error Recovery → exit code hints
    Loop until user cancels at root menu.
    #>
    $menuFile = "$FLU_SCRIPT_DIR\menu.db"

    # Verify menu file exists (matching flu.sh line 201-206)
    if (-not (Test-Path $menuFile)) {
        Write-Error "Error: menu definition not found: $menuFile"
        return 1
    }

    $running = $true

    while ($running) {
        # --- Step 1: Menu Navigation ---
        # Show-FluMenuNavigate handles its own TUI lifecycle:
        #   - Calls Initialize-Tui() internally
        #   - Renders menu levels, handles keyboard input
        #   - Calls Restore-Tui() on exit (cancel at root) or before returning (leaf select)
        # Returns 0 on leaf selection (TUI_RESULT set to "L1|L2|L3" path)
        # Returns 1 on cancel at root level
        $navResult = Show-FluMenuNavigate -DslFile $menuFile

        if ($navResult -ne 0) {
            # User cancelled at root — exit cleanly
            $running = $false
            continue
        }

        # --- Step 2: Extract Action ID ---
        # TUI_RESULT is set by Show-FluMenuNavigate on leaf selection
        # Example: "Developer Tools|Languages|Python"
        $actionId = Get-FluMenuAction -Path $Script:TUI_RESULT

        if ([string]::IsNullOrEmpty($actionId)) {
            # No action defined for this path — return to menu
            continue
        }

        # --- Step 3: Module Execution with Spinner (INTG-01) ---
        # Start spinner BEFORE module execute so it's visible during network fetch.
        # The spinner renders via background PowerShell job.
        # Invoke-FluModuleExecute internally:
        #   1. Invoke-FluModuleFetch() — network call (spinner visible)
        #   2. ConvertFrom-FluModuleMetadata()
        #   3. Platform compatibility check
        #   4. Invoke-FluModuleCollectParams() — TUI prompts
        #   5. Execute module via WSL/bash
        # After execute, Write-FluModuleResult displays results.

        Start-FluSpinner
        $result = Invoke-FluModuleExecute -ActionId $actionId
        Stop-FluSpinner

        if ($null -eq $result) {
            # Module execution failed before producing a result
            Write-Host "$($Script:TUI_RED)✗ Module execution failed for: $actionId$($Script:TUI_RESET)"
            Write-Host "$($Script:TUI_DIM)Press any key to return to menu$($Script:TUI_RESET)"
            Read-TuiKey | Out-Null
            Clear-TuiScreen
            continue
        }

        # Display result in box-rendered modal
        Write-FluModuleResult -Result $result

        # --- Error Recovery (INTG-02) ---
        if (-not $result.Success) {
            # Module execution failed — display orchestrator-level recovery hint
            # This supplements the subsystem-level hints shown in the result modal
            Write-FluExitCodeHint -ExitCode $result.ExitCode -ActionId $actionId

            if ($Script:_tui_use_tui) {
                Write-Host "$($Script:TUI_DIM)Press any key to return to menu$($Script:TUI_RESET)"
                Read-TuiKey | Out-Null
            }
        }

        # --- Step 4: Post-Execution ---
        Clear-TuiScreen
    }
}

# ──────────────
# 🩺 Health Check
# ──────────────
# Self-test to verify all subsystems loaded correctly.

function Test-FluHealth {
    <#
    .SYNOPSIS
    Verify all subsystems are loaded and functional.
    #>
    $ok = $true

    # Check tui.ps1
    if (-not (Test-Path variable:Script:TUI_RESET)) {
        Write-Warning "tui.ps1 not loaded (TUI_RESET missing)"
        $ok = $false
    }

    # Check menu.ps1
    if (-not (Test-Path function:\Get-FluMenuChildren)) {
        Write-Warning "menu.ps1 not loaded (Get-FluMenuChildren missing)"
        $ok = $false
    }

    # Check modules.ps1
    if (-not (Test-Path function:\Invoke-FluModuleFetch)) {
        Write-Warning "modules.ps1 not loaded (Invoke-FluModuleFetch missing)"
        $ok = $false
    }

    # Check menu.db
    if (-not (Test-Path "$FLU_SCRIPT_DIR\menu.db")) {
        Write-Warning "menu.db not found"
        $ok = $false
    }

    if ($ok) {
        Write-Host "$($Script:TUI_GREEN)✓ flu.ps1 health check passed$($Script:TUI_RESET)"
    }
    return $ok
}

# ──────────────
# 🎨 Logo Art — ASCII "dev-fu" LEGO-style block characters (D-15, D-16)
# ──────────────
# Renders the branded dev-fu logo centered in the terminal.
# Uses $Script:TUI_MAGENTA for color matching flu.sh branding.
# Logo is 6 lines tall, ~62 chars wide.

function Show-FluLogo {
    <#
    .SYNOPSIS
    Render ASCII dev-fu logo centered on screen.
    PowerShell port of _flu_render_logo() from flu.sh.

    .DESCRIPTION
    Logo is 6 lines of UNICODE box-drawing art rendered in magenta.
    Plain text fallback when ANSI not available (D-16).
    #>
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    $logoWidth = 62
    $startCol = [Math]::Max(1, [Math]::Floor(($termCols - $logoWidth) / 2))

    if ($Script:FluAnsiSupported) {
        $color = $Script:TUI_MAGENTA
        $reset = $Script:TUI_RESET
    } else {
        $color = ''
        $reset = ''
    }

    $logoLines = @(
        "██████╗ ███████╗██╗   ██╗       ███████╗██╗  ██╗",
        "██╔══██╗██╔════╝██║   ██║       ██╔════╝██║  ██║",
        "██║  ██║█████╗  ██║   ██║       █████╗  ███████║",
        "██║  ██║██╔══╝  ╚██╗ ██╔╝       ██╔══╝  ██╔══██║",
        "██████╔╝███████╗ ╚████╔╝        ██║     ██║  ██║",
        "╚═════╝ ╚══════╝  ╚═══╝         ╚═╝     ╚═╝  ╚═╝"
    )

    for ($i = 0; $i -lt $logoLines.Count; $i++) {
        Write-TuiAt -Row (1 + $i) -Col $startCol
        Write-Host "$color$($logoLines[$i])$reset" -NoNewline
    }
}

# ──────────────
# 🚀 Main Entry Point
# ──────────────
# Main execution — called when flu.ps1 is run directly (not dot-sourced).

function Start-Flu {
    <#
    .SYNOPSIS
    Main entry point for flu.ps1.
    #>
    # Step 1: Detect platform
    Get-FluPlatform

    # Step 1.5: Apply color theme (D-17)
    if (Get-Command Apply-FluTheme -ErrorAction SilentlyContinue) {
        Apply-FluTheme
    }

    # Step 1.6: Registry pre-fetch (non-blocking)
    $Script:FLU_REGISTRY_CACHE = $null
    try {
        $regJson = Invoke-FluRegistryFetch -ErrorAction SilentlyContinue
        if ($regJson) {
            $Script:FLU_REGISTRY_CACHE = $regJson | ConvertFrom-Json
        }
    } catch { }

    # Step 1.7: Dynamic menu assembly (merged menu.db + community modules)
    $Script:FLU_MENU_FILE = "$Script:FLU_SCRIPT_DIR\menu.db"
    if ($Script:FLU_REGISTRY_CACHE -and $Script:FLU_REGISTRY_CACHE.Count -gt 0) {
        $mergedMenu = [System.IO.Path]::GetTempFileName() + '.db'
        Get-Content "$Script:FLU_SCRIPT_DIR\menu.db" | Set-Content $mergedMenu
        Add-Content $mergedMenu "`n# ── 🌐 Community Modules (from registry) ──"
        foreach ($entry in $Script:FLU_REGISTRY_CACHE) {
            Add-Content $mergedMenu "Community Modules|$($entry.category)|$($entry.name)|community/$($entry.action_id)"
        }
        $Script:FLU_MENU_FILE = $mergedMenu
    }

    # Step 2: Show startup display
    Show-FluStartup

    # Step 3: Run main menu loop
    Start-FluMainLoop

    # Step 4: Clean exit
    Write-Host "$($Script:TUI_GREEN)flu.ps1 — Goodbye!$($Script:TUI_RESET)"
}

# Only auto-run if this is the main script (not dot-sourced)
if ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -match '\.\s+.*flu\.ps1') {
    # Being dot-sourced — don't auto-run, just load functions
} else {
    Start-Flu
}
