# @name: Install GSD Core
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

if (npm list -g @gsd-build/sdk 2>`$null | Select-String -Pattern "@gsd-build/sdk") {
    Write-Host "GSD Core already installed"
    exit 0
}

Write-Host "Installing GSD Core..."

npm install -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "GSD Core installed successfully"
}
exit $LASTEXITCODE
