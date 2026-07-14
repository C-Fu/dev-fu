# @name: Remove Tailscale
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Host "Tailscale is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Tailscale.Tailscale --silent }
    default  {
        Write-Host "Remove Tailscale from:"
        Write-Host "   Control Panel → Programs and Features → Tailscale"
    }
}

Write-Host "Tailscale removed successfully"
