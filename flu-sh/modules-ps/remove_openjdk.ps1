# @name: Remove OpenJDK (Temurin 21)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "Java is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id EclipseAdoptium.Temurin.21.JDK --silent }
    'choco'  { choco uninstall temurin -y }
    'scoop'  { scoop uninstall temurin21-jdk }
    default  { Write-Host "Java not found via package manager — remove manually" }
}

Write-Host "OpenJDK removed successfully"
