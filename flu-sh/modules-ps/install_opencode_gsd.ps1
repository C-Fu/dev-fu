# @name: Install OpenCode (GSD Bundle)
# @params:
# @platforms: windows
# @version: 1.2.0
# @deps:
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Host "OpenCode already installed"
    exit 0
}

Write-Host "Installing OpenCode (GSD Bundle)..."

switch ($env:FLU_PKG_MGR) {
    'winget' {
        winget install --id OpenCode.OpenCode --silent --accept-package-agreements
    }
    default {
        Write-Host "Installing OpenCode via official installer..."
        $installScript = "$env:TEMP\opencode-install.ps1"
        Invoke-WebRequest -Uri "https://opencode.ai/install" -OutFile $installScript -UseBasicParsing
        & $installScript
        Remove-Item $installScript -Force
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "OpenCode (GSD Bundle) installed successfully"
}
exit $LASTEXITCODE
