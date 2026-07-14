# @name: Remove Rust
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Write-Host "Rust is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Rustlang.Rustup --silent }
    'choco'  { choco uninstall rust -y }
    'scoop'  { scoop uninstall rust }
    default  {
        Write-Host "Removing Rust via rustup..."
        $rustupPath = "$env:USERPROFILE\.cargo\bin\rustup-init.exe"
        if (Test-Path $rustupPath) {
            & $rustupPath --uninstall
        } else {
            Write-Host "Run 'rustup self uninstall' to remove Rust" >&2
            exit 1
        }
    }
}

Write-Host "Rust removed successfully"
