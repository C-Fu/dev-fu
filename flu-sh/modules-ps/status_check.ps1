# @name: Status Check
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 120

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Check-CmdVersion {
    param($Name, $Cmd, $Flag)

    $padded = $Name.PadRight(12)
    $cmdInfo = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($cmdInfo) {
        try {
            $ver = & $Cmd $Flag 2>$null | Select-Object -First 1
            Write-Host "  [OK]   $padded : $ver"
        } catch {
            Write-Host "  [OK]   $padded : installed"
        }
    } else {
        Write-Host "  [MISS] $padded : NOT installed"
    }
}

Write-Host "Status Check — Developer Tools"
Write-Host "==============================="
Write-Host ""

# System info
Write-Host "  System:  Windows $([Environment]::OSVersion.Version) | $env:PROCESSOR_ARCHITECTURE"
Write-Host ""

# Languages & Runtimes
Write-Host "--- Languages & Runtimes ---"
Check-CmdVersion -Name "Go" -Cmd "go" -Flag "version"
Check-CmdVersion -Name "Rustc" -Cmd "rustc" -Flag "--version"
Check-CmdVersion -Name "Cargo" -Cmd "cargo" -Flag "--version"
Check-CmdVersion -Name "Bun" -Cmd "bun" -Flag "--version"

$nvmPadded = "NVM".PadRight(12)
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    Write-Host "  [OK]   $nvmPadded : installed"
} else {
    Write-Host "  [MISS] $nvmPadded : NOT installed"
}

Check-CmdVersion -Name "Node.js" -Cmd "node" -Flag "--version"
Check-CmdVersion -Name "Python" -Cmd "python" -Flag "--version"
Check-CmdVersion -Name "PHP" -Cmd "php" -Flag "-v"
Check-CmdVersion -Name "Yarn" -Cmd "yarn" -Flag "--version"

Write-Host ""
Write-Host "--- Tools ---"
Check-CmdVersion -Name "Docker" -Cmd "docker" -Flag "--version"
Check-CmdVersion -Name "curl" -Cmd "curl" -Flag "--version"
Check-CmdVersion -Name "wget" -Cmd "wget" -Flag "--version"
Check-CmdVersion -Name "git" -Cmd "git" -Flag "--version"
Check-CmdVersion -Name "Neovim" -Cmd "nvim" -Flag "--version"
Check-CmdVersion -Name "Starship" -Cmd "starship" -Flag "--version"
Check-CmdVersion -Name "zoxide" -Cmd "zoxide" -Flag "--version"

# OpenCode
$ocPadded = "OpenCode".PadRight(12)
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    $ocVer = opencode --version 2>$null
    Write-Host "  [OK]   $ocPadded : $ocVer"
} else {
    Write-Host "  [MISS] $ocPadded : NOT installed"
}

Write-Host ""
Write-Host "==============================="
Write-Host "Status check complete."
