# @name: Install lazygit
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Write-Host "lazygit already installed"
    exit 0
}

Write-Host "Installing lazygit..."

# Detect architecture
$arch = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { 'arm64' } else { 'x86_64' }

# Download latest release
$url = "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${env:FLU_OS}_${arch}.zip"
$zipPath = "$env:TEMP\lazygit.zip"

Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\lazygit" -Force
$installDir = "$env:ProgramFiles\lazygit"
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
Move-Item "$env:TEMP\lazygit\lazygit.exe" "$installDir\lazygit.exe" -Force
Remove-Item $zipPath, "$env:TEMP\lazygit" -Recurse -Force

# Add to PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ";" + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host "lazygit installed successfully"
