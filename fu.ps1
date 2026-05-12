# ============================================================
# Title: fu.ps1
# Author: C-Fu
# Description: PowerShell equivalent of fu.sh for Windows
# Compatibility: Windows PowerShell 5.1+ / PowerShell 7+
# ============================================================

# Colors
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[0;34m"
$CYAN = "`e[0;36m"
$MAGENTA = "`e[0;35m"
$WHITE = "`e[1;37m"
$BOLD = "`e[1m"
$DIM = "`e[2m"
$NC = "`e[0m"
$BCYAN = "`e[1;36m"

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
    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_TR}${NC}"
    Write-Host "${BOX_V} ${WHITE}Architecture:${NC} $DETECTED_ARCH                        ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}OS:${NC} Windows                                   ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Package Mgr:${NC} $(Get-PackageManager)                            ${BOX_V}"
    Write-Host "${BOX_V} ${WHITE}Shell:${NC} PowerShell                               ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_BR}${NC}"
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
    $confirm = Read-Host "  Proceed? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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
    $confirm = Read-Host "  Proceed? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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

    $confirm = Read-Host "  Replace current fancy prompt? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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
    $confirm = Read-Host "  Remove fancy prompt? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
    }

    $target = "$env:USERPROFILE\.fancy-prompt.ps1"
    if (Test-Path $target) {
        Remove-Item -Force $target
    }

    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $cleaned = $content -replace "\r?\n?\s*\.\s*['\"]$([regex]::Escape($target))['\"]\s*", ""
            Set-Content -Path $profilePath -Value $cleaned -NoNewline
        }
    }

    Write-Host "${GREEN}  ✓ Fancy prompt removed${NC}"
}

# Avahi Install (Windows note)
function Install-Avahi {
    Write-Host "${CYAN}🌐  ${BOLD}Install Avahi Daemon${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Local network discovery (mDNS/NSS)${NC}"
    Write-Host ""
    Write-Host "  ${YELLOW}⚠ Avahi Daemon is a Linux service and is not available on Windows.${NC}"
    Write-Host "  ${YELLOW}  For mDNS on Windows, Bonjour/Apple Bonjour Print Services is the equivalent.${NC}"
    Write-Host "  ${YELLOW}  If using WSL2, run fu.sh inside the Linux distribution instead.${NC}"
}

# Avahi Remove (Windows note)
function Remove-Avahi {
    Write-Host "${RED}🗑️  ${BOLD}Remove Avahi Daemon${NC}"
    Write-Host ""
    Write-Host "  ${YELLOW}⚠ Avahi Daemon is a Linux service and is not installed on Windows.${NC}"
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

    Write-Host ""
    Write-Host "${GREEN}  ✓ Status check complete${NC}"
}

# Dev Tools Install
function Install-DevTools {
    Write-Host "${CYAN}${EMOJI_DEV}  ${BOLD}Install Dev Tools${NC}" -ForegroundColor Cyan
    Write-Host "${DIM}   Node.js, Python, Go, Rust, Bun, Yarn, uv${NC}"
    Write-Host ""

    Write-Host "${YELLOW}  → This will install: Node.js LTS, Python, Go, Rust, Bun, Yarn, uv${NC}"
    $confirm = Read-Host "  Proceed? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
    }

    $pkgMgr = Get-PackageManager

    if ($pkgMgr -eq "winget") {
        Write-Host "${CYAN}  Installing Node.js LTS via winget...${NC}"
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements

        Write-Host "${CYAN}  Installing Python via winget...${NC}"
        winget install Python.Python.3.11 --accept-source-agreements --accept-package-agreements

        Write-Host "${CYAN}  Installing Go via winget...${NC}"
        winget install GoLang.Go --accept-source-agreements --accept-package-agreements

        Write-Host "${CYAN}  Installing Rust via winget...${NC}"
        winget install Rustlang.Rust --accept-source-agreements --accept-package-agreements
    } elseif ($pkgMgr -eq "choco") {
        Write-Host "${CYAN}  Installing via chocolatey...${NC}"
        choco install nodejs-lts python go rust -y
    } else {
        Write-Host "${YELLOW}  No package manager found. Please install manually.${NC}"
    }

    # Install Bun
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Host "${GREEN}  ${EMOJI_CHECK} Bun already installed${NC}"
    } else {
        Write-Host "${CYAN}  Installing Bun...${NC}"
        powershell -c "irm bun.sh/install.ps1 | iex"
    }

    # Install Yarn
    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        Write-Host "${GREEN}  ${EMOJI_CHECK} Yarn already installed${NC}"
    } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}  Installing Yarn...${NC}"
        npm install -g yarn
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${YELLOW}  Yarn install failed${NC}"
        }
    } else {
        Write-Host "${YELLOW}  npm not found — install Node.js first${NC}"
    }

    # Install uv
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "${GREEN}  ${EMOJI_CHECK} uv already installed${NC}"
    } else {
        Write-Host "${CYAN}  Installing uv...${NC}"
        powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${YELLOW}  uv install failed${NC}"
        }
    }

    Write-Host ""
    Write-Host "${GREEN}  ✓ Dev tools installation complete${NC}"
}

# Dev Tools Uninstall
function Uninstall-DevTools {
    Write-Host "${RED}🗑️  ${BOLD}Uninstall Dev Tool${NC}"
    Write-Host ""
    Write-Host "  Enter tool to uninstall: node, python, go, rust, bun, yarn, uv"
    $tool = Read-Host "  Choice"

    $pkgMgr = Get-PackageManager

    switch ($tool.ToLower()) {
        "node" {
            if ($pkgMgr -eq "winget") {
                winget uninstall OpenJS.NodeJS.LTS
            } else {
                choco uninstall nodejs -y
            }
        }
        "python" {
            if ($pkgMgr -eq "winget") {
                winget uninstall Python.Python.3.11
            } else {
                choco uninstall python -y
            }
        }
        "go" {
            if ($pkgMgr -eq "winget") {
                winget uninstall GoLang.Go
            } else {
                choco uninstall go -y
            }
        }
        "rust" {
            if (Get-Command rustup -ErrorAction SilentlyContinue) {
                rustup self uninstall
            } else {
                Write-Host "${DIM}  Rustup not found${NC}"
            }
        }
        "bun" {
            $bunPath = "$env:USERPROFILE\.bun"
            if (Test-Path $bunPath) {
                Remove-Item -Recurse -Force $bunPath
                Write-Host "${GREEN}  ✓ Bun removed${NC}"
            } else {
                Write-Host "${DIM}  Bun not found${NC}"
            }
        }
        "yarn" {
            npm uninstall -g yarn
            if ($LASTEXITCODE -eq 0) {
                Write-Host "${GREEN}  ✓ Yarn removed${NC}"
            } else {
                Write-Host "${RED}  Yarn removal failed${NC}"
            }
        }
        "uv" {
            $uvPath = "$env:USERPROFILE\.local\bin\uv.exe"
            $uvData = "$env:USERPROFILE\.local\share\uv"
            if (Test-Path $uvPath) { Remove-Item -Force $uvPath }
            if (Test-Path $uvData) { Remove-Item -Recurse -Force $uvData }
            Write-Host "${GREEN}  ✓ uv removed${NC}"
        }
        default {
            Write-Host "${YELLOW}  Unknown tool: $tool${NC}"
        }
    }
}

# OpenCode + GSD Install
function Install-OpenCode {
    Write-Host "${MAGENTA}${EMOJI_GSD}  ${BOLD}Install OpenCode + GSD${NC}" -ForegroundColor Magenta
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
        $confirm = Read-Host "  Proceed? (y/n)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "${DIM}  Cancelled.${NC}"
            return
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

    Write-Host ""
    Write-Host "${GREEN}  ✓ OpenCode + GSD installed successfully${NC}"
}

# OpenCode Remove
function Remove-OpenCode {
    Write-Host "${RED}🗑️  ${BOLD}Remove OpenCode${NC}"
    $confirm = Read-Host "  Remove OpenCode? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
    }
    npm uninstall -g opencode-ai
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}  OpenCode removal failed${NC}"
        return
    }
    Write-Host "${GREEN}  ✓ OpenCode removed${NC}"
}

# GSD Remove
function Remove-GSD {
    Write-Host "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    $confirm = Read-Host "  Remove GSD? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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

    if (-not $upgraded) {
        Write-Host "  ${YELLOW}${EMOJI_ARROW} No installed tools found to upgrade. Install tools first (option 5).${NC}"
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
    $confirm = Read-Host "  Proceed? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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
    $confirm = Read-Host "  Remove PHP and Laravel? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "${DIM}  Cancelled.${NC}"
        return
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

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_TR}${NC}"
    Write-Host "${BOX_V} ${BOLD}${WHITE}Environment Setup Utility${NC}                  ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_BR}${NC}"
    Write-Host ""

    Write-Host "${WHITE}▸ Install/Configure:${NC}"
    Write-Host "${BOX_V} ${GREEN}1${NC}) ${EMOJI_DOCKER}  Install Docker"
    Write-Host "${BOX_V} ${GREEN}2${NC}) ✨  Create Fancy Prompt"
    Write-Host "${BOX_V} ${GREEN}3${NC}) 🌐  Install Avahi Daemon"
    Write-Host "${BOX_V} ${GREEN}4${NC}) ${EMOJI_STATUS}  Status Check"
    Write-Host "${BOX_V} ${GREEN}5${NC}) ${EMOJI_DEV}  Install Dev Tools"
    Write-Host "${BOX_V} ${GREEN}6${NC}) ${EMOJI_GSD}  Install OpenCode + GSD"
    Write-Host "${BOX_V} ${GREEN}7${NC}) 🐘  Install PHP + Laravel"
    Write-Host "${BOX_V} ${GREEN}8${NC}) ⬆️  Upgrade All Tools"
    Write-Host ""

    Write-Host "${WHITE}▸ Remove:${NC}"
    Write-Host "${BOX_V} ${RED}1a)${NC}       Remove Docker"
    Write-Host "${BOX_V} ${RED}2a)${NC}       Remove Fancy Prompt"
    Write-Host "${BOX_V} ${RED}3a)${NC}       Remove Avahi Daemon"
    Write-Host "${BOX_V} ${RED}5a)${NC}       Uninstall Dev Tool"
    Write-Host "${BOX_V} ${RED}6a)${NC}       Remove OpenCode"
    Write-Host "${BOX_V} ${RED}6b)${NC}       Remove GSD"
    Write-Host "${BOX_V} ${RED}7a)${NC}       Remove PHP + Laravel"
    Write-Host ""

    Write-Host "${CYAN}$BOX_TL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_TR}${NC}"
    Write-Host "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit              ${BOX_V}"
    Write-Host "${CYAN}$BOX_BL$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_BR}${NC}"

    Write-Host -NoNewline -ForegroundColor Cyan "▸ Choice: "
}

# Main loop
while ($true) {
    Show-PreflightStatus
    Show-Menu
    $choice = Read-Host
    Write-Host ""

    switch ($choice) {
        "1" { Install-Docker }
        "1a" { Remove-Docker }
        "2" { Install-FancyPrompt }
        "2a" { Remove-FancyPrompt }
        "3" { Install-Avahi }
        "3a" { Remove-Avahi }
        "4" { Get-StatusCheck }
        "5" { Install-DevTools }
        "5a" { Uninstall-DevTools }
        "6" { Install-OpenCode }
        "6a" { Remove-OpenCode }
        "6b" { Remove-GSD }
        "7" { Install-PHP }
        "7a" { Remove-PHP }
        "8" { Upgrade-All }
        "q" {
            Write-Host "${MAGENTA}Goodbye — stay productive! ${EMOJI_HEART}${NC}"
            break
        }
        default {
            Write-Host "${YELLOW}  Invalid choice, try again.${NC}"
        }
    }

    Write-Host ""
    $null = Read-Host "  Press Enter to continue..."
}