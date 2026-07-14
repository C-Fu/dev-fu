# @name: Install Bun
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: curl
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command bun -ErrorAction SilentlyContinue) {
    Write-Host "Bun already installed: $(bun --version 2>`$null)"
    exit 0
}

Write-Host "Installing Bun..."

# Use official PowerShell installer for Bun on Windows
$installScript = "$env:TEMP\bun-install.ps1"
Invoke-WebRequest -Uri "https://bun.sh/install.ps1" -OutFile $installScript -UseBasicParsing
& $installScript
Remove-Item $installScript -Force

# Refresh PATH
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ";" + [Environment]::GetEnvironmentVariable('Path', 'Machine')

if (Get-Command bun -ErrorAction SilentlyContinue) {
    Write-Host "Bun installed successfully: $(bun --version 2>`$null)"
    exit 0
} else {
    Write-Host "Bun install failed" >&2
    exit 1
}
