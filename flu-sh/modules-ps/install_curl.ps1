# @name: Install curl
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command curl -ErrorAction SilentlyContinue) {
    Write-Host "curl is built into Windows and already available at: $(Get-Command curl).Source"
    exit 0
}

Write-Host "curl is built into Windows 10 and later."
exit 0
