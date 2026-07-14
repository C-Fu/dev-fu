# @name: Install Yarn
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command yarn -ErrorAction SilentlyContinue) {
    Write-Host "Yarn already installed: $(yarn --version 2>`$null)"
    exit 0
}

Write-Host "Installing Yarn..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Yarn.Yarn --silent --accept-package-agreements
    }
    'choco' {
        choco install yarn -y
    }
    'scoop' {
        scoop install yarn
    }
    default {
        Write-Host "Yarn is not available through any supported Windows package manager."
        Write-Host "Visit https://yarnpkg.com/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Yarn installed successfully"
}
exit $LASTEXITCODE
