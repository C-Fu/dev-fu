# @name: Install Docker Desktop
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "Docker already installed: $(docker --version 2>`$null)"
    exit 0
}

Write-Host "Installing Docker Desktop..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Docker.DockerDesktop --silent --accept-package-agreements
    }
    'choco' {
        choco install docker-desktop -y
    }
    default {
        Write-Host "Docker Desktop is not available through any supported Windows package manager."
        Write-Host "Visit https://docs.docker.com/desktop/setup/install/windows-install/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker Desktop installed. You may need to log out and back in for group membership to take effect."
}
exit $LASTEXITCODE
