# @name: Install Tailscale
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    Write-Host "Tailscale already installed: $(tailscale version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing Tailscale..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Tailscale.Tailscale --silent --accept-package-agreements
    }
    default {
        Write-Host "Tailscale is not available through any supported Windows package manager."
        Write-Host "Visit https://tailscale.com/download/windows for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Tailscale installed successfully"
}
exit $LASTEXITCODE
