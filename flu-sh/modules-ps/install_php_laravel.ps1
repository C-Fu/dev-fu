# @name: Install PHP + Laravel
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ((Get-Command php -ErrorAction SilentlyContinue) -and (Get-Command composer -ErrorAction SilentlyContinue)) {
    Write-Host "PHP already installed: $(php -v 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing PHP..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id PHP.PHP --silent --accept-package-agreements
    }
    'choco' {
        choco install php -y
    }
    'scoop' {
        scoop install php
    }
    default {
        Write-Host "PHP is not available through any supported Windows package manager."
        Write-Host "Visit https://windows.php.net/download/ for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "PHP installed successfully"
}

# Install Composer
if (-not (Get-Command composer -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Composer..."
    $composerScript = "$env:TEMP\composer-setup.php"
    Invoke-WebRequest -Uri "https://getcomposer.org/installer" -OutFile $composerScript -UseBasicParsing
    php $composerScript -- --install-dir="$env:ProgramFiles\composer" --filename=composer
    Remove-Item $composerScript -Force
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ";" + [Environment]::GetEnvironmentVariable('Path', 'Machine')
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "PHP + Laravel dependencies installed successfully"
}
exit $LASTEXITCODE
