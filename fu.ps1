# ============================================================
# Title: fu.ps1
# Author: C-Fu
# Description: PowerShell equivalent of fu.sh for Windows
# Compatibility: Windows PowerShell 5.1+ / PowerShell 7+
# ============================================================

# Colors
$ESC = [char]27
$RED = "$ESC[0;31m"
$GREEN = "$ESC[0;32m"
$YELLOW = "$ESC[1;33m"
$BLUE = "$ESC[0;34m"
$CYAN = "$ESC[0;36m"
$MAGENTA = "$ESC[0;35m"
$WHITE = "$ESC[1;37m"
$BOLD = "$ESC[1m"
$DIM = "$ESC[2m"
$NC = "$ESC[0m"
$BCYAN = "$ESC[1;36m"

# Box Drawing
$BOX_TL = "┌"
$BOX_TR = "┐"
$BOX_BL = "└"
$BOX_BR = "┘"
$BOX_H = "─"
$BOX_V = "│"

# Emojis
$EMOJI_DOCKER = "🐳"
$EMOJI_STATUS = "🔍"
$EMOJI_DEV = "🛠️"
$EMOJI_GSD = "🚀"
$EMOJI_PHP = "🐘"
$EMOJI_CHECK = "✓"
$EMOJI_CROSS = "✗"
$EMOJI_ARROW = "➜"
$EMOJI_HEART = "💜"
$EMOJI_PROMPT = "✨"
$EMOJI_UPGRADE = "⬆️"
$EMOJI_NETWORK = "🌐"
$EMOJI_GO = "🐹"
$EMOJI_RUST = "☢️"
$EMOJI_PYTHON = "🐍"
$EMOJI_NODE = "📦"
$EMOJI_BUN = "🥟"
$EMOJI_BUN = "🥟"
$EMOJI_SPARKLE = "⚡"
$EMOJI_MOUSE = "🐁"

$MENU_LABELS = @(
    "Status Check"
    "Upgrade All Tools"
    "Install Docker"
    "Create Fancy Prompt"
    "Install Hostname Discovery (Linux only)"
    "Install Go"
    "Install Rust"
    "Install Python + Pip + UV + Pipx"
    "Install NVM + Node LTS"
    "Install Bun"
    "Install Yarn"
    "Disable Mouse Reporting in Terminal"
    "Install PHP + Laravel"
    "Install OpenCode + GSD (Rokicool) + OpenChamber"
)
$MENU_EMOJIS = @($EMOJI_STATUS, $EMOJI_UPGRADE, $EMOJI_DOCKER, $EMOJI_PROMPT, $EMOJI_NETWORK, $EMOJI_GO, $EMOJI_RUST, $EMOJI_PYTHON, $EMOJI_NODE, $EMOJI_BUN, $EMOJI_SPARKLE, $EMOJI_MOUSE, $EMOJI_PHP, $EMOJI_GSD)
$MENU_INSTALL_FN = @("Get-StatusCheck", "Upgrade-All", "Install-Docker", "Install-FancyPrompt", "Install-Avahi", "Install-Go", "Install-Rust", "Install-Python", "Install-NvmNode", "Install-Bun", "Install-Yarn", "Disable-MouseReporting", "Install-PHP", "Install-OpenCode")
$MENU_REMOVE_FN = @("", "", "Remove-Docker", "Remove-FancyPrompt", "Remove-Avahi", "Remove-Go", "Remove-Rust", "Remove-Python", "Remove-NvmNode", "Remove-Bun", "Remove-Yarn", "Enable-MouseReporting", "Remove-PHP", "Remove-OpenCode")
$MENU_SINGLE_SELECT = @(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1)
$Script:BATCH_MODE = $false

# Detect OS and Architecture
function Get-DetectOs {
    if ($IsWindows) { return "windows" }
    return "windows"
}

function Get-DetectArch {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { return "arm" }
    return "x86"
}

$DETECTED_OS = Get-DetectOs
$DETECTED_ARCH = Get-DetectArch

# Detect Package Manager
function Get-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return "winget"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return "choco"
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return "scoop"
    }
    return "winget"
}

# System Info Display
function Show-PreflightStatus {
    Write-Host ""
    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V} ${WHITE}Architecture:${NC} $DETECTED_ARCH                        ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}OS:${NC} Windows                                   ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Package Mgr:${NC} $(Get-PackageManager)                            ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Shell:${NC} PowerShell                               ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"
    Write-Host ""
}

# Docker Install
function Install-Docker {
    Write-Host "${BLUE}${EMOJI_DOCKER}  ${BOLD}Install Docker${NC}" -ForegroundColor Blue
    Write-Host "${DIM}   Docker Desktop for Windows${NC}"
    Write-Host ""

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $version = docker --version 2>$null
        if ($version) {
            Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Docker already installed: $version"
            return
        }
    }

    Write-Host "${YELLOW}  → This will install: Docker Desktop${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Docker via winget...${NC}"
        winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Docker via chocolatey...${NC}"
        choco install docker-desktop -y
    } else {
        Write-Host "${YELLOW}  Please install Docker from: https://www.docker.com/products/docker-desktop/${NC}"
    }
    Write-Host "${GREEN}  ✓ Docker installation initiated${NC}"
}

# Docker Remove
function Remove-Docker {
    Write-Host "${RED}🗑️  ${BOLD}Remove Docker${NC}"
    Write-Host ""

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "${DIM}  Docker is not installed${NC}"
        return
    }

    Write-Host "${YELLOW}  → This will remove Docker${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Removing Docker via winget...${NC}"
        winget uninstall Docker.DockerDesktop
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  Docker removal failed${NC}"
            return
        }
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Removing Docker via chocolatey...${NC}"
        choco uninstall docker-desktop -y
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  Docker removal failed${NC}"
            return
        }
    }

    Write-Host "${GREEN}  ✓ Docker removed${NC}"
}

# Fancy Prompt Install
function Install-FancyPrompt {
    Write-Host "${MAGENTA}✨  ${BOLD}Create Fancy Prompt${NC}" -ForegroundColor Magenta
    Write-Host ""

    $target = "$env:USERPROFILE\.fancy-prompt.ps1"
    $url = "https://raw.githubusercontent.com/jonathan-scholbach/fancy-prompt/refs/heads/master/prompt.sh"

    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Replace current fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    try {
        Invoke-WebRequest -Uri $url -OutFile $target -ErrorAction Stop
    } catch {
        Write-Host "${RED}  Download failed${NC}"
        return
    }

    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $sourceLine = ". '$target'"
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($sourceLine)) {
        Add-Content -Path $profilePath -Value $sourceLine
    }

    . $target
    Write-Host "${GREEN}  ✓ Fancy prompt replaced${NC}"
}

# Fancy Prompt Remove
function Remove-FancyPrompt {
    Write-Host "${RED}➜ Remove Fancy Prompt${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove fancy prompt? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $target = "$env:USERPROFILE\.fancy-prompt.ps1"
    if (Test-Path $target) {
        Remove-Item -Force $target
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "\r?\n?\s*\.\s*['""]$([regex]::Escape($target))['""]\s*", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }

    Write-Host "${GREEN}  ✓ Fancy prompt removed${NC}"
}

# Avahi Install (Windows note)
function Install-Avahi {
    Write-Host "${CYAN}🌐  ${BOLD}Install Hostname Discovery${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   avahi-daemon (mDNS/NSS) + systemd-resolved (DNS)${NC}"
    Write-Host ""
    Write-Host "  ${RED}${EMOJI_CROSS}${NC} ${RED}This option is not available on Windows.${NC}"
    Write-Host "  ${YELLOW}  Avahi Daemon and systemd-resolved are Linux-only services.${NC}"
    Write-Host "  ${YELLOW}  Windows uses Bonjour for mDNS and has its own DNS resolver.${NC}"
    Write-Host "  ${YELLOW}  If using WSL2, run fu.sh inside the Linux distribution instead.${NC}"
}

# Avahi Remove (Windows note)
function Remove-Avahi {
    Write-Host "${RED}🗑️  ${BOLD}Remove Hostname Discovery${NC}"
    Write-Host ""
    Write-Host "  ${RED}${EMOJI_CROSS}${NC} ${RED}This option is not available on Windows.${NC}"
    Write-Host "  ${YELLOW}  Avahi Daemon and systemd-resolved are Linux-only services.${NC}"
    Write-Host "  ${YELLOW}  If using WSL2, run fu.sh inside the Linux distribution instead.${NC}"
}

# Status Check
function Get-StatusCheck {
    Write-Host "${CYAN}${EMOJI_STATUS}  ${BOLD}Status Check${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Checking developer tools...${NC}"
    Write-Host ""

    $tools = @(
        @{Name = "Docker"; Cmd = "docker"; Args = "--version"; VersionCmd = $true},
        @{Name = "Go"; Cmd = "go"; Args = "version"; VersionCmd = $true},
        @{Name = "Rustc"; Cmd = "rustc"; Args = "--version"; VersionCmd = $true},
        @{Name = "Cargo"; Cmd = "cargo"; Args = "--version"; VersionCmd = $true},
        @{Name = "Bun"; Cmd = "bun"; Args = "--version"; VersionCmd = $true},
        @{Name = "Node.js"; Cmd = "node"; Args = "--version"; VersionCmd = $true},
        @{Name = "Python"; Cmd = "python"; Args = "--version"; VersionCmd = $true},
        @{Name = "PHP"; Cmd = "php"; Args = "--version"; VersionCmd = $true},
        @{Name = "Yarn"; Cmd = "yarn"; Args = "--version"; VersionCmd = $true},
        @{Name = "uv"; Cmd = "uv"; Args = "--version"; VersionCmd = $true}
    )

    foreach ($tool in $tools) {
        try {
            $result = & $tool.Cmd $tool.Args 2>$null
            if ($LASTEXITCODE -eq 0 -or $result) {
                $ver = if ($result) { ($result -split "`n")[0] } else { "installed" }
                Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} $($tool.Name.PadRight(12)) : ${GREEN}$ver${NC}"
            } else {
                Write-Host "  ${RED}${EMOJI_CROSS}${NC} $($tool.Name.PadRight(12)) : ${RED}NOT installed${NC}"
            }
        } catch {
            Write-Host "  ${RED}${EMOJI_CROSS}${NC} $($tool.Name.PadRight(12)) : ${RED}NOT installed${NC}"
        }
    }

    # Check NVM
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} NVM          : ${GREEN}installed${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} NVM          : ${RED}NOT installed${NC}"
    }

    # Check OpenCode
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        $ocVer = opencode --version 2>$null
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}$ocVer${NC}"
    } elseif ((npm list -g opencode-ai 2>$null) -match "opencode-ai") {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}(npm global)${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} OpenCode     : ${RED}NOT installed${NC}"
    }

    # Check GSD
    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} GSD          : ${GREEN}installed${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} GSD          : ${RED}NOT available${NC}"
    }

    # Check OpenChamber
    if (Get-Command openchamber -ErrorAction SilentlyContinue) {
        $ocVer = openchamber --version 2>$null
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenChamber  : ${GREEN}$ocVer${NC}"
    } elseif (npm list -g @openchamber/web 2>$null) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenChamber  : ${GREEN}(npm global)${NC}"
    } else {
        Write-Host "  ${RED}${EMOJI_CROSS}${NC} OpenChamber  : ${RED}NOT installed${NC}"
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ Status check complete${NC}"
}

function Install-Go {
    Write-Host "${CYAN}${EMOJI_GO}  ${BOLD}Install Go${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Go programming language${NC}"
    Write-Host ""

    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Go already installed: $(go version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Go${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Go via winget...${NC}"
        winget install GoLang.Go --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Go via chocolatey...${NC}"
        choco install go -y
    }
    Write-Host "${GREEN}  ✓ Go installed${NC}"
}

function Remove-Go {
    Write-Host "${RED}🗑️  ${BOLD}Remove Go${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Go? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall GoLang.Go
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall go -y
    }
    Write-Host "${GREEN}  ✓ Go removed${NC}"
}

function Install-Rust {
    Write-Host "${CYAN}${EMOJI_RUST}  ${BOLD}Install Rust${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Rust programming language via rustup${NC}"
    Write-Host ""

    if (Get-Command rustc -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Rust already installed: $(rustc --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Rust (rustup, rustc, cargo)${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Rust via winget...${NC}"
        winget install Rustlang.Rust --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Rust via chocolatey...${NC}"
        choco install rust -y
    }
    Write-Host "${GREEN}  ✓ Rust installed${NC}"
}

function Remove-Rust {
    Write-Host "${RED}🗑️  ${BOLD}Remove Rust${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Rust? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        rustup self uninstall -y
    } else {
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget uninstall Rustlang.Rust
        } elseif ($pkgMgr -eq "choco") {
            choco uninstall rust -y
        }
    }
    Write-Host "${GREEN}  ✓ Rust removed${NC}"
}

function Install-Python {
    Write-Host "${CYAN}${EMOJI_PYTHON}  ${BOLD}Install Python + Pip + UV + Pipx${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Python 3 with pip, uv package manager, and pipx${NC}"
    Write-Host ""

    $needInstall = $false
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { $needInstall = $true }
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { $needInstall = $true }

    if (-not $needInstall) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Python + UV already installed"
        return
    }

    Write-Host "${YELLOW}  → This will install: Python 3, pip, uv, pipx${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        if ($pkgMgr -eq "winget") {
            Write-Host "${CYAN}  Installing Python via winget...${NC}"
            winget install Python.Python.3.11 --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            Write-Host "${CYAN}  Installing Python via chocolatey...${NC}"
            choco install python -y
        }
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "${CYAN}  Installing uv...${NC}"
        powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
    }

    Write-Host "${GREEN}  ✓ Python + Pip + UV + Pipx installed${NC}"
}

function Remove-Python {
    Write-Host "${RED}🗑️  ${BOLD}Remove Python + Pip + UV + Pipx${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Python, pip, uv, and pipx? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall Python.Python.3.11
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall python -y
    }

    $uvPath = "$env:USERPROFILE\.local\bin\uv.exe"
    $uvData = "$env:USERPROFILE\.local\share\uv"
    if (Test-Path $uvPath) { Remove-Item -Force $uvPath }
    if (Test-Path $uvData) { Remove-Item -Recurse -Force $uvData }
    Write-Host "${GREEN}  ✓ Python + Pip + UV + Pipx removed${NC}"
}

function Install-NvmNode {
    Write-Host "${CYAN}${EMOJI_NODE}  ${BOLD}Install NVM + Node LTS${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Node Version Manager with latest LTS${NC}"
    Write-Host ""

    if ((Get-Command nvm -ErrorAction SilentlyContinue) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} NVM + Node already installed: $(node --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: NVM + Node.js LTS${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Node.js LTS via winget...${NC}"
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing Node.js LTS via chocolatey...${NC}"
        choco install nodejs-lts -y
    }

    Write-Host "${GREEN}  ✓ NVM + Node LTS installed${NC}"
}

function Remove-NvmNode {
    Write-Host "${RED}🗑️  ${BOLD}Remove NVM + Node${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove NVM and Node.js? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall OpenJS.NodeJS.LTS
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall nodejs -y
    }
    Write-Host "${GREEN}  ✓ NVM + Node removed${NC}"
}

# Bun Install
function Install-Bun {
    Write-Host "${CYAN}${EMOJI_BUN}  ${BOLD}Install Bun${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Fast JavaScript runtime & package manager${NC}"
    Write-Host ""

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Bun already installed: $(bun --version)"
        return
    }

    Write-Host "${YELLOW}  → This will install: Bun${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Write-Host "${CYAN}  Installing Bun...${NC}"
    powershell -c "irm bun.sh/install.ps1 | iex"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  Bun install failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ Bun installed${NC}"
}

# Bun Remove
function Remove-Bun {
    Write-Host "${RED}🗑️  ${BOLD}Remove Bun${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Bun? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $bunPath = "$env:USERPROFILE\.bun"
    if (Test-Path $bunPath) {
        Remove-Item -Recurse -Force $bunPath
    }
    Write-Host "${GREEN}  ✓ Bun removed${NC}"
}

# Yarn Install
function Install-Yarn {
    Write-Host "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Install Yarn${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Fast, reliable dependency management${NC}"
    Write-Host ""

    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Yarn already installed: $(yarn --version)"
        return
    }

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "  ${RED}${EMOJI_CROSS} npm missing - install NVM + Node LTS first (option 9)${NC}"
        return
    }

    Write-Host "${YELLOW}  → This will install: Yarn${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    Write-Host "${CYAN}  Installing Yarn...${NC}"
    npm install -g yarn
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  Yarn install failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ Yarn installed${NC}"
}

# Yarn Remove
function Remove-Yarn {
    Write-Host "${RED}🗑️  ${BOLD}Remove Yarn${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove Yarn? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    npm uninstall -g yarn 2>$null
    Write-Host "${GREEN}  ✓ Yarn removed${NC}"
}

# Disable Mouse Reporting
function Disable-MouseReporting {
    Write-Host "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Disable Mouse Reporting in Terminal${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Prevents terminal mouse events from interfering with CLI tools${NC}"
    Write-Host ""

    $profilePath = $PROFILE
    $mouseLine = 'Write-Host "$([char]27)[?1000l$([char]27)[?1002l$([char]27)[?1003l$([char]27)[?1006l" -NoNewline'

    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match '\?\s*1000l.*\?\s*1002l.*\?\s*1006l') {
            Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} Mouse reporting already disabled in profile"
            return
        }
    }

    Write-Host "${YELLOW}  → This will add mouse disable commands to your PowerShell profile${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    Add-Content -Path $profilePath -Value $mouseLine
    Write-Host "${GREEN}  ✓ Mouse reporting disabled${NC}"
}

# Enable Mouse Reporting
function Enable-MouseReporting {
    Write-Host "${RED}🗑️  ${BOLD}Re-enable Mouse Reporting${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Re-enable mouse reporting? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "(?m)^\s*Write-Host.*\?\s*1000l.*\?\s*1006l.*-NoNewline\s*\r?\n?", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }
    Write-Host "${GREEN}  ✓ Mouse reporting re-enabled${NC}"
}

# OpenCode + GSD Install
function Install-OpenCode {
    Write-Host "${MAGENTA}${EMOJI_GSD}  ${BOLD}Install OpenCode + GSD (Rokicool) + OpenChamber${NC}" -ForegroundColor Magenta
    Write-Host "${DIM}   AI-powered development environment${NC}"
    Write-Host ""

    $opencodeInstalled = $false
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode already installed"
        $opencodeInstalled = $true
    } else {
        Write-Host "${YELLOW}  → OpenCode will be installed${NC}"
    }

    if (-not $opencodeInstalled) {
        if (-not $Script:BATCH_MODE) {
            $confirm = Read-Host "  Proceed? (y/n)"
            if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
        }
    }

    Write-Host "${CYAN}  Installing OpenCode...${NC}"
    npm install -g opencode-ai
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenCode install failed${NC}"
        return
    }

    Write-Host "${CYAN}  Installing GSD...${NC}"
    npx gsd-opencode@latest
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  GSD install failed${NC}"
        return
    }

    Write-Host "${CYAN}  Installing OpenChamber...${NC}"
    npm install -g @openchamber/web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenChamber install failed${NC}"
        return
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ OpenCode + GSD + OpenChamber installed successfully${NC}"
}

# OpenCode Remove
function Remove-OpenCode {
    Write-Host "${RED}🗑️  ${BOLD}Remove OpenCode${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove OpenCode? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }
    npm uninstall -g opencode-ai @openchamber/web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenCode removal failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ OpenCode removed${NC}"
}

# GSD Remove
function Remove-GSD {
    Write-Host "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove GSD? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }
    if (Get-Command gsd-opencode -ErrorAction SilentlyContinue) {
        gsd-opencode uninstall
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  GSD removal failed${NC}"
            return
        }
    } else {
        Write-Host "${YELLOW}  GSD not found${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ GSD removed${NC}"
}

# Upgrade All Tools
function Upgrade-All {
    Write-Host "${BCYAN}⬆️  ${BOLD}Upgrade All Tools${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Updating installed developer tools...${NC}"
    Write-Host ""

    $upgraded = $false

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Docker...${NC}"
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget upgrade Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            choco upgrade docker-desktop -y
        }
        $upgraded = $true
    }

    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Rust...${NC}"
        rustup update
        $upgraded = $true
    }

    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Node.js...${NC}"
        if (Get-Command nvm -ErrorAction SilentlyContinue) {
            nvm install latest
            nvm use latest
        } else {
            Write-Host "${YELLOW}  NVM not found — consider installing it to manage Node versions${NC}"
        }
        $upgraded = $true
    }

    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Bun...${NC}"
        powershell -c "irm bun.sh/install.ps1 | iex"
        $upgraded = $true
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading Yarn...${NC}"
        npm upgrade -g yarn
        $upgraded = $true
    }

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading uv...${NC}"
        uv self update
        $upgraded = $true
    }

    if (Get-Command php -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Upgrading PHP...${NC}"
        $pkgMgr = Get-PackageManager
        if ($pkgMgr -eq "winget") {
            winget upgrade PHP.PHP --accept-source-agreements --accept-package-agreements
        } elseif ($pkgMgr -eq "choco") {
            choco upgrade php -y
        }
        $upgraded = $true
    }

    if ((Get-Command opencode -ErrorAction SilentlyContinue) -or ((npm list -g opencode-ai 2>$null) -match "opencode-ai")) {
        Write-Host "${CYAN}  Upgrading OpenCode...${NC}"
        npm upgrade -g opencode-ai
        $upgraded = $true
    }

    if ((Get-Command openchamber -ErrorAction SilentlyContinue) -or ((npm list -g @openchamber/web 2>$null) -match "openchamber")) {
        Write-Host "${CYAN}  Upgrading OpenChamber...${NC}"
        npm upgrade -g @openchamber/web
        $upgraded = $true
    }

    if (-not $upgraded) {
        Write-Host "  ${YELLOW}${EMOJI_ARROW} No installed tools found to upgrade. Install tools first (options 6-11).${NC}"
    } else {
        Write-Host ""
        Write-Host "${GREEN}  ✓ Upgrade complete${NC}"
    }
}

# PHP + Laravel Install
function Install-PHP {
    Write-Host "${MAGENTA}🐘  ${BOLD}Install PHP + Laravel${NC}" -ForegroundColor Magenta
    Write-Host "${DIM}   PHP 8.x with Laravel installer${NC}"
    Write-Host ""

    if (Get-Command php -ErrorAction SilentlyContinue) {
        $version = php --version 2>$null | Select-Object -First 1
        Write-Host "  ${GREEN}${EMOJI_CHECK}${NC} PHP already installed: $version"
        return
    }

    Write-Host "${YELLOW}  → This will install: PHP 8.x, Composer, Laravel installer${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing PHP via winget...${NC}"
        winget install PHP.PHP --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing PHP via chocolatey...${NC}"
        choco install php -y
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ PHP installed${NC}"
}

# PHP Remove
function Remove-PHP {
    Write-Host "${RED}🗑️  ${BOLD}Remove PHP + Laravel${NC}"
    if (-not $Script:BATCH_MODE) {
        $confirm = Read-Host "  Remove PHP and Laravel? (y/n)"
        if ($confirm -notin @('y','Y')) { Write-Host "${DIM}  Cancelled.${NC}"; return }
    }

    $pkgMgr = Get-PackageManager
    if ($pkgMgr -eq "winget") {
        winget uninstall PHP.PHP
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  PHP removal failed${NC}"
            return
        }
    } elseif ($pkgMgr -eq "choco") {
        choco uninstall php -y
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}  PHP removal failed${NC}"
            return
        }
    }

    Write-Host "${GREEN}  ✓ PHP and Laravel removed${NC}"
}

# Show Menu
function Show-Menu {
    Clear-Host

    Write-Host "${MAGENTA}"
    Write-Host "  ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗"
    Write-Host " ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║"
    Write-Host " ╚═╝ ██╔╝██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║"
    Write-Host " ██╔╝██╔╝ ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║"
    Write-Host " ╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝"
    Write-Host "     ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝"
    Write-Host "${NC}"

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V} ${BOLD}${WHITE}Environment Setup Utility${NC}                  ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"
    Write-Host ""

    for ($i = 0; $i -lt $MENU_LABELS.Count; $i++) {
        $num = $i + 1
        $pad = if ($num -lt 10) { " " } else { "" }
        if ($i -eq 4) {
            Write-Host "${BOX_V} ${GREEN}${DIM}$num${NC}${DIM})${pad} $($MENU_EMOJIS[$i])  $($MENU_LABELS[$i])${NC}"
        } else {
            Write-Host "${BOX_V} ${GREEN}$num${NC})${pad} $($MENU_EMOJIS[$i])  $($MENU_LABELS[$i])"
        }
    }
    Write-Host ""
    Write-Host "${DIM}  Enter your selected options, split by commas or spaces (1,2 3 4)${NC}"
    Write-Host "${DIM}  Enter -N to remove (e.g. -3 removes Docker)${NC}"
    Write-Host ""

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_TR}${NC}"
    Write-Host "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit              ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H${BOX_BR}${NC}"

    Write-Host -NoNewline -ForegroundColor Cyan "▸ Choice: "
}

function Parse-Input {
    param([string]$RawInput)

    $Script:InstallIndices = @()
    $Script:RemoveIndices = @()

    if ([string]::IsNullOrWhiteSpace($RawInput)) {
        Write-Host "${YELLOW}No selection made. Enter numbers (1-14) or 'q' to quit.${NC}"
        return $false
    }

    $tokens = $RawInput -split '[,\s]+' | Where-Object { $_ -ne '' }

    if ($tokens.Count -eq 0) {
        Write-Host "${YELLOW}No selection made. Enter numbers (1-14) or 'q' to quit.${NC}"
        return $false
    }

    $candidates = @()
    $errors = @()
    foreach ($token in $tokens) {
        if ($token -match '^-?[1-9]$' -or $token -match '^-?1[0-4]$') {
            $candidates += $token
        } else {
            $errors += $token
        }
    }

    if ($errors.Count -gt 0) {
        if ($errors.Count -eq 1) {
            Write-Host "${RED}Invalid: '$($errors[0])' is not a valid option (1-14)${NC}"
        } else {
            $errorStr = ($errors | ForEach-Object { "'$_'" }) -join ', '
            Write-Host "${RED}Invalid: $errorStr are not valid options (1-14)${NC}"
        }
        return $false
    }

    $seen = @{}
    $unique = @()
    foreach ($token in $candidates) {
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $unique += $token
        }
    }

    $addIndices = @()
    $rmIndices = @()
    foreach ($token in $unique) {
        if ($token.StartsWith('-')) {
            $num = $token.TrimStart('-')
            $rmIndices += [int]$num - 1
        } else {
            $addIndices += [int]$token - 1
        }
    }

    foreach ($ridx in $rmIndices) {
        if ($addIndices -contains $ridx) {
            $clabel = $MENU_LABELS[$ridx] -replace '^(Install|Create) ',''
            Write-Host "${RED}Cannot both install and remove $clabel${NC}"
            return $false
        }
    }

    $totalCount = $addIndices.Count + $rmIndices.Count
    if ($totalCount -gt 1) {
        foreach ($idx in $addIndices) {
            if ($MENU_SINGLE_SELECT[$idx] -eq 1) {
                Write-Host "${RED}Option $($idx + 1) ($($MENU_LABELS[$idx])) must be used alone${NC}"
                return $false
            }
        }
        foreach ($idx in $rmIndices) {
            if ($MENU_SINGLE_SELECT[$idx] -eq 1) {
                Write-Host "${RED}Option $($idx + 1) ($($MENU_LABELS[$idx])) must be used alone${NC}"
                return $false
            }
        }
    }

    foreach ($idx in $rmIndices) {
        if ($MENU_REMOVE_FN[$idx] -eq '') {
            $rlabel = $MENU_LABELS[$idx] -replace '^(Install|Create) ',''
            Write-Host "${RED}Cannot remove $rlabel — no remove operation available${NC}"
            return $false
        }
    }

    $Script:InstallIndices = $addIndices
    $Script:RemoveIndices = $rmIndices
    return $true
}

function Show-ConfirmationScreen {
    $total = $Script:InstallIndices.Count + $Script:RemoveIndices.Count

    if ($total -eq 0) { return $false }
    if ($total -eq 1) { return $true }

    Write-Host "${BOLD}${WHITE}Operations to execute:${NC}"

    $boxInner = 54
    $border = "${BOX_TL}" + ($BOX_H * $boxInner) + "${BOX_TR}"
    Write-Host "${CYAN}${border}${NC}"

    $num = 1
    foreach ($idx in $Script:InstallIndices) {
        $label = "$($MENU_EMOJIS[$idx])  $($MENU_LABELS[$idx])"
        $padded = $label.PadRight($boxInner - 5).Substring(0, $boxInner - 5)
        Write-Host "${BOX_V} ${GREEN}${num}) ${padded}${NC} ${BOX_V}"
        $num++
    }
    foreach ($idx in $Script:RemoveIndices) {
        $label = "$($MENU_EMOJIS[$idx])  $($MENU_LABELS[$idx])"
        $padded = $label.PadRight($boxInner - 6).Substring(0, $boxInner - 6)
        Write-Host "${BOX_V} ${RED}-${num}) ${padded}${NC} ${BOX_V}"
        $num++
    }

    $bottom = "${BOX_BL}" + ($BOX_H * $boxInner) + "${BOX_BR}"
    Write-Host "${CYAN}${bottom}${NC}"

    Write-Host "${YELLOW}Run ${total} operations? (y/n)${NC}"
    $confirm = Read-Host "  ▸"
    if ($confirm -notin @('y','Y')) {
        Write-Host "${DIM}  Cancelled.${NC}"
        return $false
    }
    return $true
}

# Main loop
while ($true) {
    Show-PreflightStatus
    Show-Menu
    $choice = Read-Host
    Write-Host ""

    if ($choice -eq "q" -or $choice -eq "Q") {
        Write-Host "${MAGENTA}Goodbye — stay productive! ${EMOJI_HEART}${NC}"
        break
    }

    if ($choice -eq "u" -or $choice -eq "U") {
        Upgrade-All
    } else {
        if (Parse-Input $choice) {
            if (Show-ConfirmationScreen) {
                if ($Script:InstallIndices -contains 4) {
                    Write-Host "${YELLOW}Hostname Discovery is not available on Windows${NC}"
                    $Script:InstallIndices = @($Script:InstallIndices | Where-Object { $_ -ne 4 })
                }
                $Script:BATCH_MODE = $true
                foreach ($idx in $Script:InstallIndices) {
                    & $MENU_INSTALL_FN[$idx]
                }
                foreach ($idx in $Script:RemoveIndices) {
                    & $MENU_REMOVE_FN[$idx]
                }
                $Script:BATCH_MODE = $false
            }
        }
    }

    Write-Host ""
    $null = Read-Host "  Press Enter to continue..."
}