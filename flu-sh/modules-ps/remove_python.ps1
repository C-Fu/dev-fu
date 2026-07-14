# @name: Remove Python
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    Write-Host "Python is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Python.Python.3.12 --silent }
    'choco'  { choco uninstall python -y }
    'scoop'  { scoop uninstall python }
    default  { Write-Host "Python not found via package manager — remove manually" }
}

Write-Host "Python removed successfully"
