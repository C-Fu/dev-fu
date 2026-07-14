# @name: Fancy Prompt (Blue)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$profilePath = $PROFILE.CurrentUserAllHosts
$markerStart = '# dev-fu blue prompt start'
$markerEnd = '# dev-fu blue prompt end'

# Idempotent guard
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    if ($content -match "$markerStart") {
        Write-Host "Fancy Prompt (Blue) is already installed in PowerShell profile"
        exit 0
    }
}

Write-Host "Installing Fancy Prompt (Blue)..."

$promptBlock = @"

$markerStart
# Fancy Prompt (Blue) — installed by flu.sh

function prompt {
    local:exitCode = `$LASTEXITCODE
    `$host.UI.RawUI.ForegroundColor = 'White'
    `$host.UI.RawUI.BackgroundColor = 'Black'

    `$user = [Environment]::UserName
    `$computer = [Environment]::MachineName
    `$path = (Get-Location).Path.Replace(`$HOME, '~')

    Write-Host "`n" -NoNewline
    Write-Host " $user@$computer " -NoNewline -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host " $path " -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "`n" -NoNewline
    return "> "
}
$markerEnd
"@

Add-Content -Path $profilePath -Value $promptBlock -Force

Write-Host "Fancy Prompt (Blue) installed in PowerShell profile"
Write-Host "Run: . `$PROFILE   (or open a new terminal)"
