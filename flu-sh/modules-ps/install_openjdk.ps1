# @name: Install OpenJDK (Temurin 21)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command java -ErrorAction SilentlyContinue) {
    Write-Host "Java already installed: $(java --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing OpenJDK 21 (Temurin)..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id EclipseAdoptium.Temurin.21.JDK --silent --accept-package-agreements
    }
    'choco' {
        choco install temurin -y
    }
    'scoop' {
        scoop install temurin21-jdk
    }
    default {
        Write-Host "OpenJDK is not available through any supported Windows package manager."
        Write-Host "Visit https://adoptium.net/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "OpenJDK 21 installed successfully"
}
exit $LASTEXITCODE
