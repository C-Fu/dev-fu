# @name: Install NVM + Node LTS
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command nvm -ErrorAction SilentlyContinue) {
    Write-Host "NVM already installed"
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Host "Node.js: $(node --version 2>`$null)"
    }
    exit 0
}

Write-Host "Installing NVM for Windows..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id CoreyButler.NVMforWindows --silent --accept-package-agreements
    }
    'choco' {
        choco install nvm -y
    }
    'scoop' {
        scoop install nvm
    }
    default {
        Write-Host "NVM is not available through any supported Windows package manager."
        Write-Host "Visit https://github.com/coreybutler/nvm-windows for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "NVM for Windows installed successfully"
    Write-Host "Open a new terminal and run: nvm install lts"
}
exit $LASTEXITCODE
