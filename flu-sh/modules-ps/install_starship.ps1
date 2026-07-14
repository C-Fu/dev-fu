# @name: Install Starship
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Host "Starship already installed: $(starship --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing Starship..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Starship.Starship --silent --accept-package-agreements
    }
    'scoop' {
        scoop install starship
    }
    default {
        Write-Host "Starship is not available through any supported Windows package manager."
        Write-Host "Visit https://starship.rs for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Starship installed successfully"
}
exit $LASTEXITCODE
