# @name: Remove lazygit
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command lazygit -ErrorAction SilentlyContinue)) {
    Write-Host "lazygit is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id JesseDuffield.lazygit --silent }
    'choco'  { choco uninstall lazygit -y }
    'scoop'  { scoop uninstall lazygit }
    default  { Remove-Item "$env:ProgramFiles\lazygit\lazygit.exe" -Force -ErrorAction SilentlyContinue }
}

Write-Host "lazygit removed successfully"
