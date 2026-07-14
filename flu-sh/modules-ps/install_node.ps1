# @name: Install Node.js
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Node.js already installed: $(node --version 2>`$null)"
    exit 0
}

Write-Host "Installing Node.js..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id OpenJS.NodeJS --silent --accept-package-agreements
    }
    'choco' {
        choco install nodejs -y
    }
    'scoop' {
        scoop install nodejs
    }
    default {
        Write-Host "Node.js is not available through any supported Windows package manager."
        Write-Host "Visit https://nodejs.org/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Node.js installed successfully"
}
exit $LASTEXITCODE
