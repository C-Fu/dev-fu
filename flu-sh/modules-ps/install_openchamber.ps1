# @name: Install OpenChamber
# @params:
# @platforms: windows
# @version: 1.1.0
# @deps: npm
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "npm is required. Install Node.js first." >&2
    exit 1
}

if (Get-Command openchamber -ErrorAction SilentlyContinue) {
    Write-Host "OpenChamber already installed"
    exit 0
}

Write-Host "Installing OpenChamber..."

npm install -g @openchamber/web

if ($LASTEXITCODE -eq 0) {
    Write-Host "OpenChamber installed successfully"
}
exit $LASTEXITCODE
