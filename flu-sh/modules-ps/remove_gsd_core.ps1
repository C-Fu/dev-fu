# @name: Remove GSD Core
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 120

$ErrorActionPreference = 'Stop'

Write-Host "Removing GSD Core..."
npm uninstall -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "GSD Core removed successfully"
}
exit $LASTEXITCODE
