# @name: Install Python
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command python3 -ErrorAction SilentlyContinue) {
    Write-Host "Python already installed: $(python3 --version 2>`$null)"
    exit 0
}
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "Python already installed: $(python --version 2>`$null)"
    exit 0
}

Write-Host "Installing Python..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Python.Python.3.12 --silent --accept-package-agreements
    }
    'choco' {
        choco install python -y
    }
    'scoop' {
        scoop install python
    }
    default {
        Write-Host "Python is not available through any supported Windows package manager."
        Write-Host "Visit https://python.org/downloads/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Python installed successfully"
}
exit $LASTEXITCODE
