# @name: Install GSD for Pi
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "npm is required. Install Node.js first." >&2
    exit 1
}

Write-Host "Installing GSD for Pi..."

npm install -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "GSD for Pi installed successfully"
}
exit $LASTEXITCODE
