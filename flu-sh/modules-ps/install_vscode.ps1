# @name: Install VS Code
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "VS Code already installed"
    exit 0
}

Write-Host "Installing VS Code..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Microsoft.VisualStudioCode --silent --accept-package-agreements
    }
    'choco' {
        choco install vscode -y
    }
    'scoop' {
        scoop install vscode
    }
    default {
        Write-Host "VS Code is not available through any supported Windows package manager."
        Write-Host "Visit https://code.visualstudio.com/Download for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "VS Code installed successfully"
}
exit $LASTEXITCODE
