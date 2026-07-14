# @name: Remove OpenCode
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Host "OpenCode is not installed"
    exit 0
}

switch ($env:FLU_PKG_MGR) {
    'winget' { winget uninstall --id OpenCode.OpenCode --silent }
    default  {
        $officialDir = "$env:USERPROFILE\.opencode"
        if (Test-Path $officialDir) {
            Remove-Item $officialDir -Recurse -Force
            Write-Host "Removed OpenCode from $officialDir"
        }
    }
}

if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Host "OpenCode may still be available — check PATH or npm global packages"
} else {
    Write-Host "OpenCode removed successfully"
}
