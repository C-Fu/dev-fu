# @name: Install systemd-resolved
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# systemd-resolved is Linux-only, but check for WSL availability
if (Get-Command resolvectl -ErrorAction SilentlyContinue) {
    Write-Host "systemd-resolved is already available"
    exit 0
}

Write-Host "systemd-resolved is a Linux system service and is not available on Windows."
Write-Host "No action needed."
exit 0
