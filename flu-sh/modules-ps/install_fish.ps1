# @name: Install Fish Shell
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command fish -ErrorAction SilentlyContinue) {
    Write-Host "Fish Shell already installed: $(fish --version 2>`$null)"
    exit 0
}

Write-Host "Installing Fish Shell..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Fish.Fish --silent --accept-package-agreements
    }
    'choco' {
        choco install fish -y
    }
    'scoop' {
        scoop install fish
    }
    default {
        Write-Host "Fish Shell is not available through any supported Windows package manager."
        Write-Host "Visit https://fishshell.com/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Fish Shell installed successfully"
}
exit $LASTEXITCODE
