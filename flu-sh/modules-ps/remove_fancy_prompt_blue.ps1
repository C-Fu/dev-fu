# @name: Remove Fancy Prompt (Blue)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 60

$ErrorActionPreference = 'Stop'

$profilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $profilePath)) {
    Write-Host "No PowerShell profile found. Fancy prompt not installed."
    exit 0
}

$content = Get-Content $profilePath -Raw
$markerStart = '# dev-fu blue prompt start'
$markerEnd = '# dev-fu blue prompt end'

if ($content -match "$markerStart.*?$markerEnd") {
    $newContent = $content -replace "$markerStart.*?$markerEnd", ''
    Set-Content -Path $profilePath -Value $newContent -Force
    Write-Host "Fancy Prompt (Blue) removed from PowerShell profile"
} else {
    Write-Host "Fancy Prompt (Blue) is not installed in PowerShell profile"
}

exit 0
