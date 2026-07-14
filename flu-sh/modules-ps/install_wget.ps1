# @name: Install wget
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command wget -ErrorAction SilentlyContinue) {
    Write-Host "wget already installed: $(wget --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing wget..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id GNU.Wget --silent --accept-package-agreements
    }
    'choco' {
        choco install wget -y
    }
    'scoop' {
        scoop install wget
    }
    default {
        Write-Host "wget is not available through any supported Windows package manager."
        Write-Host "Visit https://www.gnu.org/software/wget/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "wget installed successfully"
}
exit $LASTEXITCODE
