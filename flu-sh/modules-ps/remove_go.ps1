# @name: Remove Go
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "Go is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id GoLang.Go --silent }
    'choco'  { choco uninstall golang -y }
    'scoop'  { scoop uninstall go }
    default  { Write-Host "Go not found via package manager — remove manually" }
}

Write-Host "Go removed successfully"
