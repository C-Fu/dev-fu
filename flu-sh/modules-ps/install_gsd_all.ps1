# @name: Install All GSD Packages
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "npm is required. Install Node.js first." >&2
    exit 1
}

Write-Host "Installing all GSD packages..."

npm install -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "All GSD packages installed successfully"
}
exit $LASTEXITCODE
