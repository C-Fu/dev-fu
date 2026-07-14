# @name: Status Check (Compare)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Status Check (Compare) — Developer Tools"
Write-Host "=========================================="
Write-Host ""

if (-not (Test-Path "$env:USERPROFILE\.config\dev-fu\status-cache.txt")) {
    Write-Host "No previous status snapshot found."
    Write-Host "Run a regular Status Check first to create a baseline."
    exit 0
}

$previous = Get-Content "$env:USERPROFILE\.config\dev-fu\status-cache.txt"

function Check-CmdVersion {
    param($Name, $Cmd, $Flag)

    $padded = $Name.PadRight(12)
    $cmdInfo = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($cmdInfo) {
        try {
            $ver = & $Cmd $Flag 2>$null | Select-Object -First 1
            Write-Host "  [OK]   $padded : $ver"
        } catch {
            Write-Host "  [OK]   $padded : installed"
        }
    } else {
        Write-Host "  [MISS] $padded : NOT installed"
    }
}

# Save current state for next comparison
$cacheDir = Split-Path "$env:USERPROFILE\.config\dev-fu\status-cache.txt" -Parent
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}
# Quick status dump
@(Get-Command go,rustc,node,python,docker,git -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name): $(& $_.Name --version 2>$null | Select-Object -First 1)" }) | Set-Content "$env:USERPROFILE\.config\dev-fu\status-cache.txt"

Write-Host "--- Languages & Runtimes ---"
Check-CmdVersion -Name "Go" -Cmd "go" -Flag "version"
Check-CmdVersion -Name "Rustc" -Cmd "rustc" -Flag "--version"
Check-CmdVersion -Name "Node.js" -Cmd "node" -Flag "--version"
Check-CmdVersion -Name "Python" -Cmd "python" -Flag "--version"

Write-Host ""
Write-Host "--- Tools ---"
Check-CmdVersion -Name "Docker" -Cmd "docker" -Flag "--version"
Check-CmdVersion -Name "git" -Cmd "git" -Flag "--version"
Check-CmdVersion -Name "Starship" -Cmd "starship" -Flag "--version"

Write-Host ""
Write-Host "Note: Compare with previous snapshot in:"
Write-Host "  $env:USERPROFILE\.config\dev-fu\status-cache.txt"
