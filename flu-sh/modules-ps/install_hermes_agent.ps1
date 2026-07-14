# @name: Install Hermes Agent
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: curl
# @timeout: 300

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command hermes-agent -ErrorAction SilentlyContinue) {
    Write-Host "Hermes Agent already installed"
    exit 0
}

Write-Host "Installing Hermes Agent..."
Write-Host "Hermes Agent from NousResearch requires Node.js."
Write-Host "Visit https://github.com/NousResearch/hermes-agent for Windows installation instructions."
exit 0
