# @name: Remove All GSD Packages
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 120

$ErrorActionPreference = 'Stop'

Write-Host "Removing all GSD packages..."
npm uninstall -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "All GSD packages removed successfully"
}
exit $LASTEXITCODE
