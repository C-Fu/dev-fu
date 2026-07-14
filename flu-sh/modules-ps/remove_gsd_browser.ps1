# @name: Remove GSD Browser
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps: npm
# @timeout: 120

$ErrorActionPreference = 'Stop'

Write-Host "Removing GSD Browser..."
npm uninstall -g @gsd-build/sdk

if ($LASTEXITCODE -eq 0) {
    Write-Host "GSD Browser removed successfully"
}
exit $LASTEXITCODE
