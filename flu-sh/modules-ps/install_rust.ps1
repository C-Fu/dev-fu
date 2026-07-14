# @name: Install Rust
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command rustc -ErrorAction SilentlyContinue) {
    Write-Host "Rust already installed: $(rustc --version 2>`$null)"
    exit 0
}

Write-Host "Installing Rust via rustup..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id Rustlang.Rustup --silent --accept-package-agreements
    }
    'choco' {
        choco install rust -y
    }
    'scoop' {
        scoop install rust
    }
    default {
        Write-Host "Installing Rust via rustup installer..."
        $url = "https://win.rustup.rs/x86_64"
        $installerPath = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing
        Start-Process -FilePath $installerPath -ArgumentList '-y' -Wait
        Remove-Item $installerPath -Force
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ";" + [Environment]::GetEnvironmentVariable('Path', 'Machine')
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Rust installed successfully"
}
exit $LASTEXITCODE
