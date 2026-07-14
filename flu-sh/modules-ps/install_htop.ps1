# @name: Install htop
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command htop -ErrorAction SilentlyContinue) {
    Write-Host "htop already installed"
    exit 0
}

Write-Host "htop is a Linux utility and is not available natively on Windows."
Write-Host "Use Task Manager or Resource Monitor for similar functionality."
Write-Host "Alternatively, install via WSL: 'sudo apt install htop'."
exit 0
