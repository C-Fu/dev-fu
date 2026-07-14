# @name: Remove Bun
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "Bun is not installed"
    exit 0
}

$bunDir = "$env:USERPROFILE\.bun"
if (Test-Path $bunDir) {
    Remove-Item $bunDir -Recurse -Force
    Write-Host "Removed Bun from $bunDir"
}

Write-Host "Bun removed successfully"
