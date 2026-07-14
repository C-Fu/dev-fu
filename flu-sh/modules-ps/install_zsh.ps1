# @name: Install Zsh
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command zsh -ErrorAction SilentlyContinue) {
    Write-Host "Zsh already installed"
    exit 0
}

Write-Host "Zsh is available via WSL (Windows Subsystem for Linux)."
Write-Host "To install:"
Write-Host "1. Enable WSL: wsl --install"
Write-Host "2. In WSL, run: sudo apt install zsh"
Write-Host "Visit https://learn.microsoft.com/en-us/windows/wsl/ for more information."
exit 0
