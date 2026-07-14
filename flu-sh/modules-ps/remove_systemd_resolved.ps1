# @name: Remove systemd-resolved
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

Write-Host "systemd-resolved is a Linux system service and is not available on Windows."
Write-Host "No action needed."
exit 0
