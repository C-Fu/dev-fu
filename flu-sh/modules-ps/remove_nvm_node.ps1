# @name: Remove NVM + Node LTS
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    Write-Host "NVM is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id CoreyButler.NVMforWindows --silent }
    'choco'  { choco uninstall nvm -y }
    'scoop'  { scoop uninstall nvm }
    default  {
        Write-Host "Remove NVM for Windows from:"
        Write-Host "   Control Panel → Programs and Features → NVM for Windows"
    }
}

Write-Host "NVM removed successfully"
