# @name: Remove Starship
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
    Write-Host "Starship is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Starship.Starship --silent }
    'choco'  { choco uninstall starship -y }
    'scoop'  { scoop uninstall starship }
    default  { Write-Host "Starship not found via package manager — remove manually" }
}

Write-Host "Starship removed successfully"
