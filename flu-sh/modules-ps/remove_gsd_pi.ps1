# @name: Remove GSD for Pi
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 120

$ErrorActionPreference = 'Stop'

Write-Host "Removing GSD for Pi..."
npm uninstall -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "GSD for Pi removed successfully"
}
exit $LASTEXITCODE
