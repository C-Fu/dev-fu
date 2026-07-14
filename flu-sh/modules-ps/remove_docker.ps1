# @name: Remove Docker Desktop
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id Docker.DockerDesktop --silent }
    'choco'  { choco uninstall docker-desktop -y }
    default  {
        Write-Host "Remove Docker Desktop from:"
        Write-Host "   Control Panel → Programs and Features → Docker Desktop"
    }
}

Write-Host "Docker Desktop removed. You may need to restart your computer."
