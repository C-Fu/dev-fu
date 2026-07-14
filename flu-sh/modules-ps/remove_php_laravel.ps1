# @name: Remove PHP + Laravel
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command php -ErrorAction SilentlyContinue)) {
    Write-Host "PHP is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id PHP.PHP --silent }
    'choco'  { choco uninstall php -y }
    'scoop'  { scoop uninstall php }
    default  { Write-Host "PHP not found via package manager — remove manually" }
}

# Remove Laravel installer
if (Get-Command composer -ErrorAction SilentlyContinue) {
    composer global remove laravel/installer 2>$null
}

Write-Host "PHP + Laravel removed successfully"
