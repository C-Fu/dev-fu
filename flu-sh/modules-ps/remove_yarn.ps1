# @name: Remove Yarn
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) {
    Write-Host "Yarn is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Yarn.Yarn --silent }
    'choco'  { choco uninstall yarn -y }
    'scoop'  { scoop uninstall yarn }
    default  { Write-Host "Yarn not found via package manager — remove manually" }
}

Write-Host "Yarn removed successfully"
