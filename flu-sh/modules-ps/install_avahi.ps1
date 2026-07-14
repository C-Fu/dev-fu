# @name: Install Avahi
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Avahi is Linux-only, but check for WSL availability
if (Get-Command avahi-daemon -ErrorAction SilentlyContinue) {
    Write-Host "Avahi is already running"
    exit 0
}

Write-Host "Avahi is a Linux service (mDNS/DNS-SD) and is not available on Windows."
Write-Host "No action needed."
exit 0
