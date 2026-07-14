# @name: Mouse Reporting (Disable)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 30

$ErrorActionPreference = 'Stop'

# Send escape sequence to disable mouse tracking (ConPTY-compatible)
[Console]::Write("`e[?1000l")

Write-Host "Mouse reporting DISABLED for this terminal session."
Write-Host "Normal terminal selection behavior restored."
Write-Host 'To re-enable, run "Mouse Reporting (Enable)" from the Settings menu.'
