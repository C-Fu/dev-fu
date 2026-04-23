#!/usr/bin/env bash
# ============================================================
# setup-fu.sh — Environment Setup Utility
# ============================================================
# Description: Prepares OS/environment for development
#   - Docker, Go, Rust, Node, Bun, Python, PHP, Laravel
# Compatibility: WSL2, Linux (LXC), macOS, Windows
# For Miiii and U 💜
# ============================================================

# -------------
# 🎨 Enhanced Color Palette
# -------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"

# Bright variants
BRED="\033[1;31m"
BGREEN="\033[1;32m"
BYELLOW="\033[1;33m"
BCYAN="\033[1;36m"
BMAGENTA="\033[1;35m"
WHITE="\033[1;37m"

# Styles
BOLD="\033[1m"
DIM="\033[2m"
ITALIC="\033[3m"
UNDERLINE="\033[4m"

NC="\033[0m"

# ──────────────
# ┌─ Box Drawing
# ──────────────
BOX_TL="┌"  # Top-left
BOX_TR="┐"  # Top-right
BOX_BL="└"  # Bottom-left
BOX_BR="┘"  # Bottom-right
BOX_H="─"   # Horizontal
BOX_V="│"   # Vertical
BOX_VR="├"   # Vertical right
BOX_VL="┤"   # Vertical left
BOX_HD="┬"   # Horizontal down
BOX_HU="┴"  # Horizontal up
BOX_CROSS="┼" # Cross

# ──────────────
# 🧬 Emojis (no external deps)
# ──────────────
EMOJI_DOCKER="🐳"
EMOJI_PROMPT="✨"
EMOJI_STATUS="🔍"
EMOJI_DEV="🛠️"
EMOJI_GSD="🚀"
EMOJI_GO="🐹"
EMOJI_RUST="🦀"
EMOJI_NODE="📦"
EMOJI_PYTHON="🐍"
EMOJI_BUN="🥟"
EMOJI_CHECK="✓"
EMOJI_CROSS="✗"
EMOJI_ARROW="➜"
EMOJI_SPARKLE="⚡"
EMOJI_HEART="💜"

# ──────────────
# ┌─ Helpers
# ──────────────
detect_rc_file() {
    [[ -n "$ZSH_VERSION" ]] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc"
}

append_rc_if_missing() {
    local rc="$1"
    local line="$2"
    local pattern=$(echo "$line" | sed 's/\[/\\[/g; s/\]/\\]/g')
    grep -F -- "$line" "$rc" >/dev/null 2>&1 || grep -F -- "$pattern" "$rc" >/dev/null 2>&1 || printf "%s\n" "$line" >> "$rc"
}

# ──────────────
# ⚠ Error Handling
# ──────────────
handle_error() {
    local exit_code=$?
    echo -e "${RED}⚠ Error: $1 (exit code: $exit_code)${NC}" >&2
    echo -e "${YELLOW}→ Hint: $2${NC}" >&2
    exit $exit_code
}

die() {
    echo -e "${RED}⚠ Error: $1${NC}" >&2
    exit ${2:-1}
}

# ──────────────
# 🔄 Retry Logic
# ──────────────
retry_network() {
    local max_attempts=${1:-3}
    local delay=${2:-2}
    shift 2
    local cmd="$@"
    
    for i in $(seq 1 $max_attempts); do
        if eval "$cmd"; then
            return 0
        fi
        if [ $i -lt $max_attempts ]; then
            echo -e "${YELLOW}↻ Attempt $i/$max_attempts failed. Retrying in ${delay}s...${NC}" >&2
            sleep $delay
        fi
    done
    return 1
}

# ──────────────
# 🔍 Platform Detection
# ──────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/platform-detect.sh" ]; then
    source "$SCRIPT_DIR/platform-detect.sh"
fi

get_pkg_manager() {
    case "$DETECTED_OS" in
        linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "apt"
            elif command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            elif command -v pacman >/dev/null 2>&1; then
                echo "pacman"
            elif command -v zypper >/dev/null 2>&1; then
                echo "zypper"
            else
                echo "apt"
            fi
            ;;
        darwin)
            echo "brew"
            ;;
        windows)
            if command -v winget >/dev/null 2>&1; then
                echo "winget"
            elif command -v choco >/dev/null 2>&1; then
                echo "choco"
            else
                echo "winget"
            fi
            ;;
        *)
            echo "apt"
            ;;
    esac
}

# ──────────────
# 📊 System Status Display
# ──────────────
preflight_status() {
    echo -e "${CYAN}╭───────────────── System Info ─────────────────${NC}"
    echo -e "${BOX_V} ${WHITE}Architecture:${NC} $(uname -m)"
    echo -e "${BOX_V} ${WHITE}OS:${NC} ${DETECTED_OS:-$(uname -s)}"
    echo -e "${BOX_V} ${WHITE}Package Mgr:${NC} $(get_pkg_manager)"
    echo -e "${BOX_V} ${WHITE}Shell:${NC} ${ZSH_VERSION:-bash}"
    echo -e "${CYAN}╰────────────────────────────────────────────${NC}"
    echo
}

# ──────────────
# 📋 Pre-Install Summary
# ──────────────
pre_install_summary() {
    local tool_name="$1"
    local tool_cmd="$2"
    local tool_version_flag="${3:-}"
    
    if command -v "$tool_cmd" >/dev/null 2>&1; then
        local version
        if [ -n "$tool_version_flag" ]; then
            version=$($tool_cmd $tool_version_flag 2>/dev/null | head -n1)
        else
            version=$($tool_cmd --version 2>/dev/null | head -n1)
        fi
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} ${BOLD}$tool_name${NC} ${GREEN}installed${NC}: ${DIM}$version${NC}"
        return 1
    else
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} ${BOLD}$tool_name${NC} ${YELLOW}will be installed${NC}"
        return 0
    fi
}

# ──────────────
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🐳 Option 1: Install Docker
# ──────────────
install_docker() {
    echo -e "${BLUE}${EMOJI_DOCKER}  ${BOLD}Install Docker${NC}"
    echo -e "${DIM}   Docker is a containerization platform${NC}"
    echo
    
    if command -v docker >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Docker already installed: $(docker --version | cut -d, -f1)"
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will install: Docker (latest)${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Downloading Docker install script...${NC}"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh || die "Docker download failed" 1
    sudo sh /tmp/get-docker.sh || die "Docker install failed" 1
    rm -f /tmp/get-docker.sh
    
    echo -e "${GREEN}  ✓ Docker installed successfully${NC}"
}

# 🗑️ Option 1a: Remove Docker
# ──────────────
remove_docker() {
    echo -e "${RED}🗑️  ${BOLD}Remove Docker${NC}"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "  ${DIM}Docker is not installed${NC}"
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will remove Docker completely${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Removing Docker...${NC}"
    sudo apt-get purge -y docker.io docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    sudo rm -rf /var/lib/docker /etc/docker
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    
    echo -e "${GREEN}  ✓ Docker removed successfully${NC}"
}

# 🌐 Option 3: Install Avahi Daemon
# ──────────────
install_avahi() {
    echo -e "${CYAN}🌐  ${BOLD}Install Avahi Daemon${NC}"
    echo -e "${DIM}   Local network discovery (mDNS/NSS)${NC}"
    echo
    
    if command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon already installed"
        if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon is running"
        else
            echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Avahi Daemon is not running - starting..."
            sudo systemctl enable avahi-daemon
            sudo systemctl start avahi-daemon
        fi
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will install: avahi-daemon${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Installing Avahi Daemon...${NC}"
    sudo apt-get update || die "apt-get update failed" $?
    sudo apt-get install -y avahi-daemon avahi-utils || die "avahi-daemon install failed" $?
    sudo systemctl enable avahi-daemon || die "enable avahi-daemon failed" $?
    sudo systemctl start avahi-daemon || die "start avahi-daemon failed" $?
    
    echo -e "${GREEN}  ✓ Avahi Daemon installed and started${NC}"
}

# 🗑️ Option 3a: Remove Avahi Daemon
# ──────────────
remove_avahi() {
    echo -e "${RED}🗑️  ${BOLD}Remove Avahi Daemon${NC}"
    
    if ! command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "  ${DIM}Avahi Daemon is not installed${NC}"
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will remove Avahi Daemon completely${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Removing Avahi Daemon...${NC}"
    sudo systemctl stop avahi-daemon 2>/dev/null || true
    sudo systemctl disable avahi-daemon 2>/dev/null || true
    sudo apt-get purge -y avahi-daemon avahi-utils || true
    sudo apt-get autoremove -y
    
    echo -e "${GREEN}  ✓ Avahi Daemon removed successfully${NC}"
}

# ──────────────
# ✨ Option 2: Fancy Prompt
# ──────────────
create_fancy_prompt() {
    echo -e "${MAGENTA}${EMOJI_PROMPT}  ${BOLD}Create Fancy Prompt${NC}"
    echo
    
    local rc_file=$(detect_rc_file)
    local target="$HOME/.fancy-prompt.sh"
    local url="https://raw.githubusercontent.com/jonathan-scholbach/fancy-prompt/refs/heads/master/prompt.sh"

    read -rp "  Replace current fancy prompt? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    curl -fsSL "$url" -o "$target" || die "Download failed" 1
    chmod +x "$target"
    append_rc_if_missing "$rc_file" "source ~/.fancy-prompt.sh"
    source "$target" 2>/dev/null || true
    source "$rc_file" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Fancy prompt replaced${NC}"
}

remove_fancy_prompt() {
    echo -e "${RED}➜ Remove Fancy Prompt${NC}"
    read -rp "  Remove fancy prompt? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    rm -f "$HOME/.fancy-prompt.sh"
    sed -i.bak '/source ~\/.fancy-prompt.sh/d' "$(detect_rc_file)" 2>/dev/null || true
    unset PROMPT_COMMAND
    export PS1="\u@\h:\w\$ "
    echo -e "${GREEN}  ✓ Fancy prompt removed${NC}"
}

# ──────────────
# 🔍 Option 4: Status Check
# ──────────────
status_check() {
    echo -e "${CYAN}${EMOJI_STATUS}  ${BOLD}Status Check${NC}"
    echo -e "${DIM}   Checking developer tools...${NC}"
    echo

    check_cmd_version() {
        local name="$1"; local cmd="$2"; local flag="$3"
        if command -v "$cmd" >/dev/null 2>&1; then
            ver=$($cmd $flag 2>/dev/null | head -n1 | tr -s ' ')
            printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "$name" "$ver"
        else
            printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "$name"
        fi
    }

    [[ -s "$HOME/.nvm/nvm.sh" ]] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    check_cmd_version "Docker" "docker" "--version"
    check_cmd_version "Go" "go" "version"
    check_cmd_version "Rustc" "rustc" "--version"
    check_cmd_version "Cargo" "cargo" "--version"
    check_cmd_version "Bun" "bun" "--version"
    
    if command -v nvm >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} NVM           : ${GREEN}installed${NC}"
    else
        echo -e "  ${RED}${EMOJI_CROSS}${NC} NVM           : ${RED}NOT installed${NC}"
    fi
    
    check_cmd_version "Node.js" "node" "--version"
    check_cmd_version "Python" "python3" "--version"
    check_cmd_version "pip" "pip3" "--version"
    check_cmd_version "pipx" "pipx" "--version"
    check_cmd_version "uv" "uv" "--version"
    check_cmd_version "PHP" "php" "-v"
    check_cmd_version "Yarn" "yarn" "--version"
    check_cmd_version "Composer" "composer" "--version"

    echo
    if command -v opencode >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}$(opencode --version 2>/dev/null || echo 'installed')${NC}"
    elif npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode     : ${GREEN}(npm global)${NC}"
    else
        echo -e "  ${RED}${EMOJI_CROSS}${NC} OpenCode     : ${RED}NOT installed${NC}"
    fi

    if command -v gsd-opencode >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} GSD          : ${GREEN}installed${NC}"
    else
        echo -e "  ${RED}${EMOJI_CROSS}${NC} GSD          : ${RED}NOT available${NC}"
    fi
    
    echo
    echo -e "${GREEN}  ✓ Status check complete${NC}"
}

# ──────────────
# 🛠️ Option 5: Install Dev Tools
# ──────────────
install_dev_tools() {
    echo -e "${CYAN}${EMOJI_DEV}  ${BOLD}Install Dev Tools${NC}"
    echo -e "${DIM}   Go, Rust, Bun, Node LTS, Python, Yarn${NC}"
    echo
    
    local need_install=0
    local install_list=""
    
    command -v go >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Go will be installed"; need_install=1; }
    command -v rustc >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Rust will be installed"; need_install=1; }
    command -v bun >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Bun will be installed"; need_install=1; }
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
    command -v node >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Node.js will be installed"; need_install=1; }
    command -v python3 >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Python will be installed"; need_install=1; }
    command -v yarn >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Yarn will be installed"; need_install=1; }
    
    if [ $need_install -eq 0 ]; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} All dev tools already installed${NC}"
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will install: Go, Rust, Bun, Node LTS, Python, Yarn, uv, pipx${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    echo -e "${CYAN}  Installing system packages...${NC}"
    sudo apt-get update || die "apt-get update failed" $?
    sudo apt-get install -y unzip golang-go python3 python3-pip python3-venv pipx || die "apt-get install failed" $?

    echo -e "${CYAN}  Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || die "Rust install failed" 1
    source "$HOME/.cargo/env"

    echo -e "${CYAN}  Installing Bun...${NC}"
    curl -fsSL https://bun.sh/install | bash || die "Bun install failed" 1
    export PATH="$HOME/.bun/bin:$PATH"

    echo -e "${CYAN}  Installing NVM + Node.js LTS...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || die "nvm install failed" 1
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts || die "Node LTS install failed" 1

    echo -e "${CYAN}  Installing Yarn...${NC}"
    npm install -g yarn || die "Yarn install failed" 1

    echo -e "${CYAN}  Installing uv...${NC}"
    pipx install uv || die "uv install failed" 1
    
    echo
    echo -e "${GREEN}  ✓ Dev tools installation complete${NC}"
}

# ──────────────
# 🗑️ Option 5a: Uninstall Dev Tool
# ──────────────
uninstall_dev_tool() {
    echo -e "${RED}🗑️  ${BOLD}Uninstall Dev Tool${NC}"
    read -rp "  Enter tool to uninstall (rust, node, bun, python, go, pipx, uv): " tool
    case "$tool" in
        rust) rustup self uninstall -y ;;
        node) nvm uninstall --lts ;;
        bun) rm -rf ~/.bun ;;
        python) sudo apt-get remove -y python3 python3-pip python3-venv ;;
        go) sudo apt-get remove -y golang-go ;;
        pipx) sudo apt-get remove -y pipx ;;
        uv) pipx uninstall uv ;;
        *) echo "  ${YELLOW}Unknown tool: $tool${NC}" ;;
    esac
}

# ──────────────
# 🚀 Option 6: OpenCode + GSD
# ──────────────
install_opencode_gsd() {
    echo -e "${MAGENTA}${EMOJI_GSD}  ${BOLD}Install OpenCode + GSD${NC}"
    echo -e "${DIM}   AI-powered development environment${NC}"
    echo
    
    local opencode_installed=0
    if command -v opencode >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode already installed"
        opencode_installed=1
    elif npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode installed (npm global)"
        opencode_installed=1
    else
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} OpenCode will be installed"
    fi
    
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    command -v nvm >/dev/null || { echo "  ${RED}${EMOJI_CROSS} NVM missing - install Dev Tools first (option 5)${NC}"; return; }
    command -v node >/dev/null || { echo "  ${RED}${EMOJI_CROSS} Node missing - install Dev Tools first (option 5)${NC}"; return; }
    
    if [ $opencode_installed -eq 0 ]; then
        echo -e "${BYELLOW}  → This will install: OpenCode + GSD${NC}"
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    echo -e "${CYAN}  Installing OpenCode...${NC}"
    curl -fsSL https://opencode.ai/install | bash || npm i -g opencode-ai || die "OpenCode install failed" 1

    echo -e "${CYAN}  Installing GSD...${NC}"
    npx gsd-opencode@latest || die "GSD install failed" 1

    # Disable mouse reporting
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
    append_rc_if_missing "$(detect_rc_file)" "printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'"
    
    echo
    echo -e "${GREEN}  ✓ OpenCode + GSD installed successfully${NC}"
}

# ──────────────
# 🗑️ Option 6a: Remove OpenCode
# ──────────────
remove_opencode() {
    echo -e "${RED}🗑️  ${BOLD}Remove OpenCode${NC}"
    read -rp "  Remove OpenCode? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    npm uninstall -g opencode-ai || echo -e "  ${YELLOW}OpenCode not found${NC}"
}

# ──────────────
# 🗑️ Option 6b: Remove GSD
# ──────────────
remove_gsd() {
    echo -e "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    read -rp "  Remove GSD? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    gsd-opencode uninstall || echo "  GSD not found"
}

# ──────────────
# 🐘 Option 7: Install PHP + Laravel
# ──────────────
install_php_laravel() {
    echo -e "${MAGENTA}🐘  ${BOLD}Install PHP + Laravel${NC}"
    echo -e "${DIM}   PHP 8.x with Laravel installer${NC}"
    echo
    
    if command -v php >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} PHP already installed: $(php -v | head -n1)"
        if command -v laravel >/dev/null 2>&1; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Laravel installer available"
        else
            echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Laravel installer not found — run: composer global require laravel/installer"
        fi
        return
    fi
    
    echo -e "${BYELLOW}  → This will install: PHP 8.x, Composer, Laravel installer${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    local pkg_manager=$(get_pkg_manager)
    case "$pkg_manager" in
        apt)
            echo -e "${CYAN}  Installing PHP via apt...${NC}"
            sudo apt-get update
            sudo apt-get install -y php-cli php-xml php-mbstring php-curl php-json php-composer
            ;;
        brew)
            echo -e "${CYAN}  Installing PHP via Homebrew...${NC}"
            brew install php
            ;;
        dnf)
            sudo dnf install -y php php-cli php-xml php-mbstring
            ;;
        pacman)
            sudo pacman -S --noconfirm php
            ;;
        *)
            echo -e "  ${RED}${EMOJI_CROSS} Unsupported package manager: $pkg_manager${NC}"
            return
            ;;
    esac

    if command -v composer >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Laravel installer...${NC}"
        composer global require laravel/installer
        append_rc_if_missing "$(detect_rc_file)" 'export PATH="$HOME/.composer/vendor/bin:$PATH"'
        export PATH="$HOME/.composer/vendor/bin:$PATH"
    else
        echo -e "  ${YELLOW}⚠ Composer not found — install Composer first to enable Laravel installer${NC}"
        echo "    Download: https://getcomposer.org/download/"
    fi

    echo
    echo -e "${GREEN}  ✓ PHP installed: $(php -v | head -n1)${NC}"
}

# ──────────────
# 🗑️ Option 7a: Uninstall PHP + Laravel
# ──────────────
uninstall_php_laravel() {
    echo -e "${RED}🗑️  ${BOLD}Uninstall PHP + Laravel${NC}"
    read -rp "  Remove PHP and Laravel? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    local pkg_manager=$(get_pkg_manager)
    case "$pkg_manager" in
        apt)
            sudo apt-get remove -y php-cli php-xml php-mbstring php-curl php-json php-common 2>/dev/null || true
            sudo apt-get autoremove -y
            ;;
        brew)
            brew uninstall php
            ;;
        dnf)
            sudo dnf remove -y php php-cli php-xml php-mbstring
            ;;
        pacman)
            sudo pacman -R --noconfirm php
            ;;
    esac

    rm -rf "$HOME/.composer/vendor/laravel"
    rm -rf "$HOME/.composer/vendor/bin/laravel" 2>/dev/null

    echo -e "${GREEN}  ✓ PHP and Laravel removed${NC}"
}

# ──────────────
# ─────────────────────────────────────────────
# ╔════════════════════════════════════════╗
# ║          menu display                  ║
# ╚════════════════════════════════════════╝
# ─────────────────────────────────────────────
show_menu() {
    clear
    
    # ╭──────────────────────────────────────────╮
    # │        ASCII Art Header                  │
    # ╰──────────────────────────────────────────╯
    echo -e "${MAGENTA}"
    cat << 'EOF'
        ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗
 ██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║
 ╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║
 ██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║
 ╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝
    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝ 
EOF
    echo -e "${NC}"
    
    # ╭──────────────────────────────────────────╮
    # │  Subtitle                                │
    # ╰──────────────────────────────────────────╯
    echo -e "${CYAN}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${NC}"
    echo -e "${BOX_V} ${BOLD}${WHITE}Environment Setup Utility${NC}${DIM}      ${BOX_V}"
    echo -e "${CYAN}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${NC}"
    echo
    
    # ╭──────────────────────────────────────────╮
    # │        Main Menu Options                 │
    # ╰──────────────────────────────────────────╯
    echo -e "${WHITE}▸ Install/Configure:${NC}"
    echo -e "${BOX_V} ${GREEN}1${NC}) ${EMOJI_DOCKER}  Install Docker"
    echo -e "${BOX_V} ${GREEN}2${NC}) ${EMOJI_PROMPT}  Create Fancy Prompt"
    echo -e "${BOX_V} ${GREEN}3${NC}) 🌐  Install Avahi Daemon"
    echo -e "${BOX_V} ${GREEN}4${NC}) ${EMOJI_STATUS}  Status Check"
    echo -e "${BOX_V} ${GREEN}5${NC}) ${EMOJI_DEV}  Install Dev Tools - Go, Rust, Bun, Python+UV+PIPX, NVM+Node LTS"
    echo -e "${BOX_V} ${GREEN}6${NC}) ${EMOJI_GSD}  Install OpenCode + GSD"
    echo -e "${BOX_V} ${GREEN}7${NC}) 🐘  Install PHP + Laravel"
    echo
    
    echo -e "${WHITE}▸ Remove:${NC}"
    echo -e "${BOX_V} ${RED}1a)${NC}       Remove Docker"
    echo -e "${BOX_V} ${RED}2a)${NC}       Remove Fancy Prompt"
    echo -e "${BOX_V} ${RED}3a)${NC}       Remove Avahi Daemon"
    echo -e "${BOX_V}"
    echo -e "${BOX_V} ${RED}5a)${NC}       Uninstall Dev Tool"
    echo -e "${BOX_V} ${RED}6a)${NC}       Remove OpenCode"
    echo -e "${BOX_V} ${RED}6b)${NC}       Remove GSD"
    echo -e "${BOX_V} ${RED}7a)${NC}       Uninstall PHP + Laravel"
    echo
    
    # ╭──────────────────────────────────────────╮
    # │        Footer                            │
    # ╰──────────────────────────────────────────╯
    echo -e "${CYAN}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${NC}"
    echo -e "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit          ${BOX_V}"
    echo -e "${CYAN}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${NC}"
    
    echo -n -e "${BCYAN}▸ Choice: ${NC}"
}

# ─────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────
while true; do
    preflight_status
    show_menu
    read -r choice
    echo
case "$choice" in
        1) install_docker ;;
        1a) remove_docker ;;
        2) create_fancy_prompt ;;
        2a) remove_fancy_prompt ;;
        3) install_avahi ;;
        3a) remove_avahi ;;
        4) status_check ;;
        5) install_dev_tools ;;
        5a) uninstall_dev_tool ;;
        6) install_opencode_gsd ;;
        6a) remove_opencode ;;
        6b) remove_gsd ;;
        7) install_php_laravel ;;
        7a) uninstall_php_laravel ;;
        q|Q)
            echo -e "${MAGENTA}Goodbye — stay productive! ${EMOJI_HEART}${NC}"
            break
            ;;
        *) 
            echo -e "${YELLOW}  Invalid choice, try again.${NC}"
            ;;
    esac
    echo
    read -n1 -r -p "  Press any key to continue... " _
done
