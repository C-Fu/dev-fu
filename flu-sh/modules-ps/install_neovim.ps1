# @name: Install Neovim
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Write-Host "Neovim already installed: $(nvim --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing Neovim..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Neovim.Neovim --silent --accept-package-agreements
    }
    'choco' {
        choco install neovim -y
    }
    'scoop' {
        scoop install neovim
    }
    default {
        Write-Host "Neovim is not available through any supported Windows package manager."
        Write-Host "Visit https://neovim.io/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Neovim installed successfully"
}
exit $LASTEXITCODE
