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
# 📡 Terminal Check (for curl | bash)
# ──────────────
# If stdin is not a TTY (e.g. curl | bash), reattach to /dev/tty
# so interactive read/prompt commands work correctly
if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec 0</dev/tty
elif [ ! -t 0 ]; then
    echo "Error: This script requires an interactive terminal." >&2
    echo "Try running: bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)" >&2
    exit 1
fi

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
EMOJI_UPGRADE="⬆️"
EMOJI_NETWORK="🌐"
EMOJI_PHP="🐘"

MENU_LABELS=(
    "Status Check"
    "Upgrade All Tools"
    "Install Docker"
    "Create Fancy Prompt"
    "Install Hostname Discovery (Linux only)"
    "Install Dev Tools - Go, Rust, Bun, Python+UV+PIPX, NVM+Node LTS"
    "Install OpenCode + GSD + OpenChamber"
    "Install PHP + Laravel"
)
MENU_EMOJIS=("$EMOJI_STATUS" "$EMOJI_UPGRADE" "$EMOJI_DOCKER" "$EMOJI_PROMPT" "$EMOJI_NETWORK" "$EMOJI_DEV" "$EMOJI_GSD" "$EMOJI_PHP")
MENU_INSTALL_FN=("status_check" "upgrade_all" "install_docker" "create_fancy_prompt" "install_avahi" "install_dev_tools" "install_opencode_gsd" "install_php_laravel")
MENU_REMOVE_FN=("" "" "remove_docker" "remove_fancy_prompt" "remove_avahi" "uninstall_dev_tool" "remove_opencode" "uninstall_php_laravel")
MENU_SINGLE_SELECT=(0 0 0 0 1 0 1 0)

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
detect_platform() {
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        linux*)     echo "linux" ;;
        darwin*)    echo "darwin" ;;
        msys*|cygwin*|mingw*) echo "windows" ;;
        *)          echo "linux" ;;
    esac
}

DETECTED_OS="$(detect_platform)"

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
# 📦 Package Manager Abstractions
# ──────────────
pkg_update() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  sudo apt-get update ;;
        dnf)  sudo dnf check-update || true ;;
        pacman) sudo pacman -Sy ;;
        zypper) sudo zypper refresh ;;
        brew) brew update ;;
        *) echo -e "${YELLOW}⚠ No update command for $pm${NC}" >&2 ;;
    esac
}

pkg_install() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  sudo apt-get install -y "$@" ;;
        dnf)  sudo dnf install -y "$@" ;;
        pacman) sudo pacman -S --noconfirm "$@" ;;
        zypper) sudo zypper install -y "$@" ;;
        brew) brew install "$@" ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_remove() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  sudo apt-get remove -y "$@" ;;
        dnf)  sudo dnf remove -y "$@" ;;
        pacman) sudo pacman -R --noconfirm "$@" ;;
        zypper) sudo zypper remove -y "$@" ;;
        brew) brew uninstall "$@" || true ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_purge() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  sudo apt-get purge -y "$@" ;;
        dnf)  sudo dnf remove -y "$@" ;;
        pacman) sudo pacman -Rns --noconfirm "$@" ;;
        zypper) sudo zypper remove -y "$@" ;;
        brew) brew uninstall --force "$@" || true ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_autoremove() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  sudo apt-get autoremove -y ;;
        dnf)  sudo dnf autoremove -y ;;
        pacman) sudo pacman -Sc --noconfirm || true ;;
        zypper) sudo zypper clean || true ;;
        brew) brew cleanup || true ;;
        *) true ;;
    esac
}

# ──────────────
# 🔒 Sudo Validation
# ──────────────
ensure_sudo() {
    if [ "$DETECTED_OS" = "darwin" ] || [ "$DETECTED_OS" = "windows" ]; then
        return 0
    fi
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}🔒 This script requires sudo privileges for system package installation.${NC}"
        if ! sudo -v; then
            die "sudo access is required. Please run with a user that has sudo privileges." 1
        fi
    fi
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
        if [ -d /mnt/wsl/docker-desktop ] || readlink -f "$(command -v docker)" 2>/dev/null | grep -q docker-desktop; then
            echo -e "  ${BYELLOW}⚠  Managed by Docker Desktop — upgrade via Docker Desktop on Windows${NC}"
        fi
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will install: Docker (latest)${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Downloading Docker install script...${NC}"
    retry_network 3 5 "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh" || die "Docker download failed" 1
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

    if [ -d /mnt/wsl/docker-desktop ] || readlink -f "$(command -v docker)" 2>/dev/null | grep -q docker-desktop; then
        echo -e "${BYELLOW}  ⚠  Docker is managed by Docker Desktop — uninstall via Docker Desktop on Windows${NC}"
        return 0
    fi
    
    echo -e "${BYELLOW}  → This will remove Docker completely${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    
    echo -e "${CYAN}  Removing Docker...${NC}"
    pkg_purge docker.io docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    sudo rm -rf /var/lib/docker /etc/docker
    sudo rm -f /etc/apt/sources.list.d/docker.list
    pkg_update || true
    
    echo -e "${GREEN}  ✓ Docker removed successfully${NC}"
}

# 🌐 Option 3: Install Linux Hostname Discovery (avahi-daemon + systemd-resolved)
# ──────────────
install_avahi() {
    echo -e "${CYAN}🌐  ${BOLD}Install Linux Hostname Discovery${NC}"
    echo -e "${DIM}   avahi-daemon (mDNS/NSS) + systemd-resolved (DNS)${NC}"
    echo

    if [ "$DETECTED_OS" != "linux" ]; then
        echo -e "  ${BYELLOW}⚠  This option is only available on Linux.${NC}"
        echo -e "  ${DIM}macOS uses mDNSResponder; Windows uses Bonjour/WSL.${NC}"
        return 0
    fi

    local already_done=1

    if command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon already installed"
        if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon is running"
        else
            echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Avahi Daemon is not running - starting..."
            sudo systemctl enable avahi-daemon
            sudo systemctl start avahi-daemon
        fi
    else
        already_done=0
    fi

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} systemd-resolved is running"
    else
        already_done=0
    fi

    if [ $already_done -eq 1 ]; then
        echo -e "${GREEN}  ✓ Hostname discovery already configured${NC}"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: avahi-daemon, systemd-resolved${NC}"
    echo -e "${BYELLOW}  → DNS will be swapped to systemd-resolved${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    if ! command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Avahi Daemon...${NC}"
        pkg_update || die "package update failed" $?
        pkg_install avahi-daemon avahi-utils || die "avahi-daemon install failed" $?
        sudo systemctl enable avahi-daemon || die "enable avahi-daemon failed" $?
        sudo systemctl start avahi-daemon || die "start avahi-daemon failed" $?
    fi

    if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "${CYAN}  Installing systemd-resolved...${NC}"
        pkg_install systemd-resolved || die "systemd-resolved install failed" $?
        echo -e "${CYAN}  Enabling systemd-resolved...${NC}"
        sudo systemctl enable --now systemd-resolved || die "enable systemd-resolved failed" $?
    fi

    echo -e "${CYAN}  Swapping DNS to systemd-resolved...${NC}"
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || die "DNS symlink failed" $?

    echo -e "${GREEN}  ✓ Hostname discovery installed and configured${NC}"
}

# 🗑️ Option 3a: Remove Hostname Discovery (Avahi + systemd-resolved)
# ──────────────
remove_avahi() {
    echo -e "${RED}🗑️  ${BOLD}Remove Hostname Discovery${NC}"
    echo -e "${DIM}   Removes avahi-daemon and systemd-resolved${NC}"

    if [ "$DETECTED_OS" != "linux" ]; then
        echo -e "  ${BYELLOW}⚠  This option is only available on Linux.${NC}"
        return 0
    fi

    if ! command -v avahi-daemon >/dev/null 2>&1 && ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "  ${DIM}Hostname discovery is not installed${NC}"
        return 0
    fi

    echo -e "${BYELLOW}  → This will remove: avahi-daemon, systemd-resolved${NC}"
    echo -e "${BYELLOW}  → DNS will be restored to default resolv.conf${NC}"
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return

    echo -e "${CYAN}  Restoring default DNS...${NC}"
    if [ -L /etc/resolv.conf ]; then
        sudo rm -f /etc/resolv.conf
        echo -e "${CYAN}  Restoring /etc/resolv.conf...${NC}"
        sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf && echo "nameserver 8.8.4.4" >> /etc/resolv.conf'
    fi

    echo -e "${CYAN}  Stopping systemd-resolved...${NC}"
    sudo systemctl stop systemd-resolved 2>/dev/null || true
    sudo systemctl disable systemd-resolved 2>/dev/null || true

    echo -e "${CYAN}  Removing Avahi Daemon...${NC}"
    sudo systemctl stop avahi-daemon 2>/dev/null || true
    sudo systemctl disable avahi-daemon 2>/dev/null || true
    pkg_purge avahi-daemon avahi-utils || true
    pkg_autoremove || true

    echo -e "${GREEN}  ✓ Hostname discovery removed successfully${NC}"
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

    retry_network 3 5 "curl -fsSL '$url' -o '$target'" || die "Download failed" 1
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

    # GSD detection: direct command, npm global, npx cache, or common paths
    local gsd_found=0
    local gsd_version=""
    if command -v gsd-opencode >/dev/null 2>&1; then
        gsd_found=1
        gsd_version=$(gsd-opencode --version 2>/dev/null | head -n1 || echo "installed")
    elif npm list -g gsd-opencode >/dev/null 2>&1; then
        gsd_found=1
        gsd_version="npm global"
    elif npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
        gsd_found=1
        gsd_version="npx cache"
    else
        # Check common paths that may not be in PATH on Chromebooks/containers
        for gsd_path in "$HOME/.npm/bin/gsd-opencode" "$HOME/.nvm/versions/node"/*/bin/gsd-opencode; do
            if [ -x "$gsd_path" ]; then
                gsd_found=1
                gsd_version="$gsd_path"
                break
            fi
        done
    fi
    if [ $gsd_found -eq 1 ]; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} GSD          : ${GREEN}${gsd_version}${NC}"
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

    # Rollback tracking: record successful steps for diagnostic output on partial failure
    local rollback_log=""
    _record_step() { rollback_log="${rollback_log}${rollback_log:+, }$1"; }

    echo -e "${CYAN}  Installing system packages...${NC}"
    ensure_sudo
    pkg_update || die "package update failed" $?
    pkg_install unzip golang-go python3 python3-pip python3-venv pipx || die "package install failed" $?
    _record_step "system packages"

    echo -e "${CYAN}  Installing Rust...${NC}"
    retry_network 3 5 "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh" || die "Rust download failed" 1
    sh /tmp/rustup.sh -y || die "Rust install failed" 1
    rm -f /tmp/rustup.sh
    source "$HOME/.cargo/env"
    _record_step "Rust"

    echo -e "${CYAN}  Installing Bun...${NC}"
    retry_network 3 5 "curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh" || die "Bun download failed" 1
    bash /tmp/bun-install.sh || die "Bun install failed" 1
    rm -f /tmp/bun-install.sh
    export PATH="$HOME/.bun/bin:$PATH"
    _record_step "Bun"

    echo -e "${CYAN}  Installing NVM + Node.js LTS...${NC}"
    retry_network 3 5 "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh -o /tmp/nvm-install.sh" || die "NVM download failed" 1
    bash /tmp/nvm-install.sh || die "nvm install failed" 1
    rm -f /tmp/nvm-install.sh
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts || die "Node LTS install failed" 1
    _record_step "NVM + Node LTS"

    echo -e "${CYAN}  Installing Yarn...${NC}"
    npm install -g yarn || die "Yarn install failed" 1
    _record_step "Yarn"

    echo -e "${CYAN}  Installing uv...${NC}"
    # Use official standalone installer — more reliable than pipx on Chromebooks/containers
    retry_network 3 5 "curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh" || die "uv download failed" 1
    sh /tmp/uv-install.sh || die "uv install failed" 1
    rm -f /tmp/uv-install.sh
    export PATH="$HOME/.local/bin:$PATH"
    _record_step "uv"
    append_rc_if_missing "$(detect_rc_file)" 'export PATH="$HOME/.local/bin:$PATH"'
    
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
        rust) rustup self uninstall -y || die "Rust uninstall failed" $? ;;
        node) nvm uninstall --lts || die "Node uninstall failed" $? ;;
        bun) rm -rf ~/.bun ;;
        python) pkg_remove python3 python3-pip python3-venv || die "Python uninstall failed" $? ;;
        go) pkg_remove golang-go || die "Go uninstall failed" $? ;;
        pipx) pkg_remove pipx || die "pipx uninstall failed" $? ;;
        uv) rm -rf "$HOME/.local/bin/uv" "$HOME/.local/share/uv" || die "uv uninstall failed" $? ;;
        *) echo "  ${YELLOW}Unknown tool: $tool${NC}" ;;
    esac
}

# ──────────────
# ⬆️ Option 8: Upgrade All Tools
# ──────────────
upgrade_all() {
    echo -e "${BCYAN}⬆️  ${BOLD}Upgrade All Tools${NC}"
    echo -e "${DIM}   Updating installed developer tools...${NC}"
    echo

    local upgraded=0

    if command -v docker >/dev/null 2>&1; then
        if [ -d /mnt/wsl/docker-desktop ] || readlink -f "$(command -v docker)" 2>/dev/null | grep -q docker-desktop; then
            echo -e "${CYAN}  Docker ($(docker --version | cut -d, -f1))${NC}"
            echo -e "${BYELLOW}  ⚠  Managed by Docker Desktop — upgrade via Docker Desktop on Windows${NC}"
        else
            echo -e "${CYAN}  Upgrading Docker...${NC}"
            retry_network 3 5 "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh" || echo -e "${YELLOW}  Docker download failed, skipping${NC}"
            if [ -f /tmp/get-docker.sh ]; then
                sudo sh /tmp/get-docker.sh || echo -e "${YELLOW}  Docker upgrade failed${NC}"
                rm -f /tmp/get-docker.sh
            fi
        fi
        upgraded=1
    fi

    if command -v rustup >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Rust...${NC}"
        rustup update || echo -e "${YELLOW}  Rust upgrade failed${NC}"
        upgraded=1
    fi

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        if command -v nvm >/dev/null 2>&1; then
            echo -e "${CYAN}  Upgrading NVM...${NC}"
            retry_network 3 5 "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh -o /tmp/nvm-install.sh" || echo -e "${YELLOW}  NVM download failed, skipping${NC}"
            if [ -f /tmp/nvm-install.sh ]; then
                bash /tmp/nvm-install.sh || echo -e "${YELLOW}  NVM upgrade failed${NC}"
                rm -f /tmp/nvm-install.sh
            fi
            echo -e "${CYAN}  Upgrading Node.js to latest LTS...${NC}"
            nvm install --lts --reinstall-packages-from=current || echo -e "${YELLOW}  Node LTS upgrade failed${NC}"
            upgraded=1
        fi
    fi

    if command -v bun >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Bun...${NC}"
        retry_network 3 5 "curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh" || echo -e "${YELLOW}  Bun download failed, skipping${NC}"
        if [ -f /tmp/bun-install.sh ]; then
            bash /tmp/bun-install.sh || echo -e "${YELLOW}  Bun upgrade failed${NC}"
            rm -f /tmp/bun-install.sh
            upgraded=1
        fi
    fi

    if command -v npm >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Yarn...${NC}"
        npm upgrade -g yarn || echo -e "${YELLOW}  Yarn upgrade failed${NC}"
        upgraded=1
    fi

    if command -v uv >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading uv...${NC}"
        uv self update || {
            retry_network 3 5 "curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh" || echo -e "${YELLOW}  uv download failed, skipping${NC}"
            if [ -f /tmp/uv-install.sh ]; then
                sh /tmp/uv-install.sh || echo -e "${YELLOW}  uv upgrade failed${NC}"
                rm -f /tmp/uv-install.sh
            fi
        }
        upgraded=1
    fi

    if command -v php >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading PHP...${NC}"
        pkg_update || echo -e "${YELLOW}  Package update failed${NC}"
        pkg_install php-cli php-xml php-mbstring php-curl php-json || echo -e "${YELLOW}  PHP upgrade failed${NC}"
        upgraded=1
    fi

    if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading OpenCode...${NC}"
        npm upgrade -g opencode-ai || echo -e "${YELLOW}  OpenCode upgrade failed${NC}"
        upgraded=1
    fi

    if [ $upgraded -eq 0 ]; then
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} No installed tools found to upgrade. Install tools first (option 5).${NC}"
    else
        echo
        echo -e "${GREEN}  ✓ Upgrade complete${NC}"
    fi
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
    retry_network 3 5 "curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh" || die "OpenCode download failed" 1
    bash /tmp/opencode-install.sh || npm i -g opencode-ai || die "OpenCode install failed" 1
    rm -f /tmp/opencode-install.sh

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
    npm uninstall -g opencode-ai || die "OpenCode uninstall failed" $?
}

# ──────────────
# 🗑️ Option 6b: Remove GSD
# ──────────────
remove_gsd() {
    echo -e "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    read -rp "  Remove GSD? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    if command -v gsd-opencode >/dev/null 2>&1; then
        gsd-opencode uninstall || die "GSD uninstall failed" $?
    else
        echo -e "  ${YELLOW}GSD not found${NC}"
    fi
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
    
    for i in "${!MENU_LABELS[@]}"; do
        local num=$((i + 1))
        echo -e "${BOX_V} ${GREEN}${num}${NC}) ${MENU_EMOJIS[$i]}  ${MENU_LABELS[$i]}"
    done
    echo
    echo -e "${DIM}  Enter -N to remove (e.g. -3 removes Docker)${NC}"
    echo
    
    # ╭──────────────────────────────────────────╮
    # │        Footer                            │
    # ╰──────────────────────────────────────────╯
    echo -e "${CYAN}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${NC}"
    echo -e "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit          ${BOX_V}"
    echo -e "${CYAN}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${NC}"
    
    echo -n -e "${BCYAN}▸ Choice: ${NC}"
}

parse_input() {
    PARSE_INSTALL_IDX=()
    PARSE_REMOVE_IDX=()
    local raw="$1"

    if [[ -z "$raw" || -z "${raw//[[:space:]]/}" ]]; then
        echo -e "${YELLOW}No selection made. Enter numbers (1-8) or 'q' to quit.${NC}"
        return 1
    fi

    local -a tokens
    read -ra tokens <<< "${raw//,/ }"

    local -a candidates=()
    local -a errors=()
    local token
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^-?[1-8]$ ]]; then
            candidates+=("$token")
        else
            errors+=("$token")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        if [[ ${#errors[@]} -eq 1 ]]; then
            echo -e "${RED}Invalid: '${errors[0]}' is not a valid option (1-8)${NC}"
        else
            local error_str
            error_str=$(printf "'%s', " "${errors[@]}")
            error_str="${error_str%, }"
            echo -e "${RED}Invalid: ${error_str} are not valid options (1-8)${NC}"
        fi
        return 1
    fi

    local -A seen
    local -a deduped=()
    for token in "${candidates[@]}"; do
        if [[ -z "${seen[$token]+set}" ]]; then
            seen[$token]=1
            deduped+=("$token")
        fi
    done

    local -a add_indices=()
    local -a rm_indices=()
    local idx
    for token in "${deduped[@]}"; do
        if [[ "$token" == -* ]]; then
            idx=$(( ${token#-} - 1 ))
            rm_indices+=("$idx")
        else
            idx=$(( token - 1 ))
            add_indices+=("$idx")
        fi
    done

    local ridx aidx
    for ridx in "${rm_indices[@]}"; do
        for aidx in "${add_indices[@]}"; do
            if [[ $ridx -eq $aidx ]]; then
                echo -e "${RED}Cannot both install and remove ${MENU_LABELS[$ridx]}${NC}"
                return 1
            fi
        done
    done

    local total=$(( ${#add_indices[@]} + ${#rm_indices[@]} ))
    if [[ $total -gt 1 ]]; then
        for idx in "${add_indices[@]}"; do
            if [[ ${MENU_SINGLE_SELECT[$idx]} -eq 1 ]]; then
                echo -e "${RED}Option $((idx + 1)) (${MENU_LABELS[$idx]}) must be used alone${NC}"
                return 1
            fi
        done
        for idx in "${rm_indices[@]}"; do
            if [[ ${MENU_SINGLE_SELECT[$idx]} -eq 1 ]]; then
                echo -e "${RED}Option $((idx + 1)) (${MENU_LABELS[$idx]}) must be used alone${NC}"
                return 1
            fi
        done
    fi

    for idx in "${rm_indices[@]}"; do
        if [[ -z "${MENU_REMOVE_FN[$idx]}" ]]; then
            echo -e "${RED}Cannot remove ${MENU_LABELS[$idx]} — no remove operation available${NC}"
            return 1
        fi
    done

    PARSE_INSTALL_IDX=("${add_indices[@]}")
    PARSE_REMOVE_IDX=("${rm_indices[@]}")
    return 0
}

# ─────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────
while true; do
    clear
    preflight_status
    show_menu
    read -r choice
    echo
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo -e "${MAGENTA}Goodbye — stay productive! ${EMOJI_HEART}${NC}"
        break
    fi

    if [[ "$choice" == "u" || "$choice" == "U" ]]; then
        upgrade_all
    else
        dispatched=0
        for i in "${!MENU_INSTALL_FN[@]}"; do
            if [[ "$choice" == "$((i + 1))" ]]; then
                "${MENU_INSTALL_FN[$i]}"
                dispatched=1
                break
            fi
        done
        if [[ $dispatched -eq 0 ]]; then
            echo -e "${YELLOW}  Invalid choice, try again.${NC}"
        fi
    fi
    echo
    read -n1 -r -p "  Press any key to continue... " _
done
