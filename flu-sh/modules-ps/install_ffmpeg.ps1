# @name: Install FFmpeg
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "FFmpeg already installed: $(ffmpeg --version 2>`$null | Select-Object -First 1)"
    exit 0
}

Write-Host "Installing FFmpeg..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id FFmpeg.FFmpeg --silent --accept-package-agreements
    }
    'choco' {
        choco install ffmpeg -y
    }
    'scoop' {
        scoop install ffmpeg
    }
    default {
        Write-Host "FFmpeg is not available through any supported Windows package manager."
        Write-Host "Visit https://ffmpeg.org/download.html for manual installation instructions."
        exit 1
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "FFmpeg installed successfully"
}
exit $LASTEXITCODE
