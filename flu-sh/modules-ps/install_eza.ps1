# @name: Install eza
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Write-Host "eza already installed: $(eza --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "eza is not available on Windows natively."
Write-Host "Install via WSL: 'sudo apt install eza' or 'brew install eza' in WSL."
Write-Host "Visit https://github.com/eza-community/eza for more information."
exit 0
