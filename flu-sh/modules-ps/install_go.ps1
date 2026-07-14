# @name: Install Go
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command go -ErrorAction SilentlyContinue) {
    Write-Host "Go already installed: $(go version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing Go..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id GoLang.Go --silent --accept-package-agreements
    }
    'choco' {
        choco install golang -y
    }
    'scoop' {
        scoop install go
    }
    default {
        Write-Host "Go is not available through any supported Windows package manager."
        Write-Host "Visit https://go.dev/dl/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Go installed successfully"
}
exit $LASTEXITCODE
