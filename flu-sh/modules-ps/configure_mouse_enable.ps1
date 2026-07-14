# @name: Mouse Reporting (Enable)
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 30

$ErrorActionPreference = 'Stop'

# Send escape sequence to enable mouse tracking (ConPTY-compatible)
[Console]::Write("`e[?1000h")

Write-Host "Mouse reporting ENABLED for this terminal session."
Write-Host "Click events will be sent to the terminal application."
Write-Host 'To disable, run "Mouse Reporting (Disable)" from the Settings menu.'
