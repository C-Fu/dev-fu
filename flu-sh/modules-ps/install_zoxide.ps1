# @name: Install zoxide
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Write-Host "zoxide already installed: $(zoxide --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing zoxide..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id ajeetdsouza.zoxide --silent --accept-package-agreements
    }
    'scoop' {
        scoop install zoxide
    }
    default {
        Write-Host "zoxide is not available through any supported Windows package manager."
        Write-Host "Visit https://github.com/ajeetdsouza/zoxide for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "zoxide installed successfully"
}
exit $LASTEXITCODE
