# @name: Remove zoxide
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    Write-Host "zoxide is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id ajeetdsouza.zoxide --silent }
    'choco'  { choco uninstall zoxide -y }
    'scoop'  { scoop uninstall zoxide }
    default  { Write-Host "zoxide not found via package manager — remove manually" }
}

Write-Host "zoxide removed successfully"
