# @name: Upgrade All Tools
# @params:
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 900

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Upgrade All Tools"
Write-Host "================="
Write-Host ""

$upgraded = 0
$failures = 0

# ─── winget upgrade all ────────────
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Running winget upgrade..."
    winget upgrade --all --silent --accept-package-agreements 2>$null
    if ($LASTEXITCODE -eq 0) {
        $upgraded = 1
        Write-Host "  winget: upgrades applied"
    }
}

# ─── Rust ──────────────────────────
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Write-Host "Upgrading Rust..."
    rustup update 2>$null
    if ($LASTEXITCODE -eq 0) {
        $upgraded = 1
        Write-Host "  Rust: $(rustc --version 2>$null)"
    } else {
        Write-Host "  Rust upgrade failed" >&2
        $failures++
    }
}

# ─── Bun ───────────────────────────
if (Get-Command bun -ErrorAction SilentlyContinue) {
    Write-Host "Upgrading Bun..."
    bun upgrade 2>$null
    if ($LASTEXITCODE -eq 0) {
        $upgraded = 1
        Write-Host "  Bun: $(bun --version 2>$null)"
    } else {
        Write-Host "  Bun upgrade failed" >&2
        $failures++
    }
}

# ─── Yarn ──────────────────────────
if (Get-Command yarn -ErrorAction SilentlyContinue) {
    Write-Host "Upgrading Yarn..."
    npm update -g yarn 2>$null
    if ($LASTEXITCODE -eq 0) {
        $upgraded = 1
        Write-Host "  Yarn: $(yarn --version 2>$null)"
    } else {
        Write-Host "  Yarn upgrade failed" >&2
        $failures++
    }
}

# ─── GSD ───────────────────────────
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $gsdPkg = npm list -g @gsd-build/sdk 2>$null
    if ($gsdPkg -match "@gsd-build/sdk") {
        Write-Host "Upgrading GSD..."
        npm update -g @gsd-build/sdk 2>$null
        $upgraded = 1
    }
}

# ─── OpenChamber ───────────────────
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $ocPkg = npm list -g @openchamber/web 2>$null
    if ($ocPkg -match "@openchamber/web") {
        Write-Host "Upgrading OpenChamber..."
        npm update -g @openchamber/web 2>$null
        $upgraded = 1
    }
}

Write-Host ""
if ($upgraded -eq 0) {
    Write-Host "No installed tools found to upgrade."
    Write-Host "Install tools first from the Languages & Runtimes and Tools menus."
} elseif ($failures -eq 0) {
    Write-Host "All tools upgraded successfully."
} else {
    Write-Host "Upgrade complete with $failures failure(s)."
    Write-Host "Individual tools can be reinstalled from their menu entries."
}
