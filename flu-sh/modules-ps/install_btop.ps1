# @name: Install btop
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command btop -ErrorAction SilentlyContinue) {
    Write-Host "btop already installed"
    exit 0
}

Write-Host "Installing btop..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id aristocratos.btop --silent --accept-package-agreements
    }
    'scoop' {
        scoop install btop
    }
    default {
        Write-Host "btop is not available through any supported Windows package manager."
        Write-Host "Visit https://github.com/aristocratos/btop for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "btop installed successfully"
}
exit $LASTEXITCODE
