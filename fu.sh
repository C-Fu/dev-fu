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
    echo "Try running: bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)" >&2
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
EMOJI_RUST="☢️"
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
EMOJI_MOUSE="🐁"
EMOJI_COMPARE="🔄"
EMOJI_PROMPT_BLUE="💎"
EMOJI_TAILSCALE="🔒"
EMOJI_TOKEN="🔑"

MENU_LABELS=(
    "Status Check"
    "Compare With Latest"
    "Upgrade All Tools"
    "Set GitHub Token"
    "Install Docker"
    "Create Fancy Prompt (Purple-Pink)"
    "Create Fancy Prompt (Shades of Blue)"
    "Install Hostname Discovery (Linux only)"
    "Install Go"
    "Install Rust"
    "Install Python + Pip + UV + Pipx"
    "Install NVM + Node LTS"
    "Install Bun"
    "Install Yarn"
    "Disable Mouse Reporting in Terminal"
    "Install PHP + Laravel"
    "Install Tailscale"
    "Install OpenCode + GSD (Rokicool) + OpenChamber"
)
MENU_EMOJIS=("$EMOJI_STATUS" "$EMOJI_COMPARE" "$EMOJI_UPGRADE" "$EMOJI_TOKEN" "$EMOJI_DOCKER" "$EMOJI_PROMPT" "$EMOJI_PROMPT_BLUE" "$EMOJI_NETWORK" "$EMOJI_GO" "$EMOJI_RUST" "$EMOJI_PYTHON" "$EMOJI_NODE" "$EMOJI_BUN" "$EMOJI_SPARKLE" "$EMOJI_MOUSE" "$EMOJI_PHP" "$EMOJI_TAILSCALE" "$EMOJI_GSD")
MENU_INSTALL_FN=("status_check" "status_check_compare" "upgrade_all" "set_github_token" "install_docker" "create_fancy_prompt" "create_fancy_prompt_blue" "install_avahi" "install_go" "install_rust" "install_python" "install_nvm_node" "install_bun" "install_yarn" "disable_mouse_reporting" "install_php_laravel" "install_tailscale" "install_opencode_gsd")
MENU_REMOVE_FN=("" "" "" "" "remove_docker" "remove_fancy_prompt" "remove_fancy_prompt_blue" "remove_avahi" "remove_go" "remove_rust" "remove_python" "remove_nvm_node" "remove_bun" "remove_yarn" "enable_mouse_reporting" "uninstall_php_laravel" "remove_tailscale" "remove_opencode")
MENU_SINGLE_SELECT=(0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 1)
BATCH_MODE=0

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

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null
        echo "${ID:-linux}"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release 2>/dev/null
        echo "${DISTRIB_ID:-linux}" | tr '[:upper:]' '[:lower:]'
    else
        echo "linux"
    fi
}

detect_wsl() {
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        echo "wsl"
    else
        echo ""
    fi
}

DETECTED_OS="$(detect_platform)"
DETECTED_DISTRO="$(detect_distro)"
DETECTED_WSL="$(detect_wsl)"

detect_environment() {
    if [ -f /dev/.cros_milestone ] || [ -d /opt/google/cros-containers ] || grep -q "chromiumos\|chromeos" /etc/lsb-release 2>/dev/null; then
        echo "chromebook"
    elif [ -n "$TERMUX_VERSION" ] || [ -d /data/data/com.termux ]; then
        echo "termux"
    else
        echo "standard"
    fi
}

DETECTED_ENV="$(detect_environment)"

get_pkg_manager() {
    case "$DETECTED_OS" in
        linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "apt"
            elif command -v apk >/dev/null 2>&1; then
                echo "apk"
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
        apt)  _maybe_sudo apt-get update ;;
        apk)  _maybe_sudo apk update ;;
        dnf)  _maybe_sudo dnf check-update || true ;;
        pacman) _maybe_sudo pacman -Sy ;;
        zypper) _maybe_sudo zypper refresh ;;
        brew) brew update ;;
        *) echo -e "${YELLOW}⚠ No update command for $pm${NC}" >&2 ;;
    esac
}

_maybe_sudo() {
    if [ "$(id -u)" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

pkg_install() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  _maybe_sudo apt-get install -y "$@" ;;
        apk)  _maybe_sudo apk add "$@" ;;
        dnf)  _maybe_sudo dnf install -y "$@" ;;
        pacman) _maybe_sudo pacman -S --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper install -y "$@" ;;
        brew) brew install "$@" ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_remove() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  _maybe_sudo apt-get remove -y "$@" ;;
        apk)  _maybe_sudo apk del "$@" ;;
        dnf)  _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -R --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew) brew uninstall "$@" || true ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_purge() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  _maybe_sudo apt-get purge -y "$@" ;;
        apk)  _maybe_sudo apk del --purge "$@" ;;
        dnf)  _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -Rns --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew) brew uninstall --force "$@" || true ;;
        *) die "Unsupported package manager: $pm" 1 ;;
    esac
}

pkg_autoremove() {
    local pm
    pm="$(get_pkg_manager)"
    case "$pm" in
        apt)  _maybe_sudo apt-get autoremove -y ;;
        apk)  _maybe_sudo apk autoremove ;;
        dnf)  _maybe_sudo dnf autoremove -y ;;
        pacman) _maybe_sudo pacman -Sc --noconfirm || true ;;
        zypper) _maybe_sudo zypper clean || true ;;
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
    if [ "$DETECTED_ENV" = "termux" ]; then
        return 0
    fi
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "${RED}  ✗ sudo is required but not available. Install sudo or run as root.${NC}"
        return 1
    fi
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}🔒 This script requires sudo privileges for system package installation.${NC}"
        if ! sudo -v; then
            echo -e "${RED}  ✗ sudo access is required. Please run with a user that has sudo privileges.${NC}"
            return 1
        fi
    fi
}

# ──────────────
# 📊 System Status Display
# ──────────────
preflight_status() {
    local os_label="${DETECTED_DISTRO}"
    if [ -n "$DETECTED_WSL" ]; then
        os_label="${DETECTED_DISTRO} (WSL2)"
    elif [ "$DETECTED_OS" = "darwin" ]; then
        os_label="macOS"
    elif [ "$DETECTED_OS" = "windows" ]; then
        os_label="Windows"
    fi

    local wan_ip="" lan_ip=""
    wan_ip=$(curl -fsSL --max-time 3 https://api.ipify.org 2>/dev/null || echo "unavailable")
    if [[ "$DETECTED_OS" == "darwin" ]]; then
        lan_ip=$(ipconfig getifaddr en0 2>/dev/null)
    else
        lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "$lan_ip" ]] && lan_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    fi
    [[ -z "$lan_ip" ]] && lan_ip="unavailable"

    echo -e "${CYAN}://─────────────── System Info ────────────────║${NC}"
    echo -e "${BOX_V} ${WHITE}Architecture:${NC} $(uname -m)"
    echo -e "${BOX_V} ${WHITE}OS:${NC} ${os_label}"
    echo -e "${BOX_V} ${WHITE}Package Mgr:${NC} $(get_pkg_manager)"
    echo -e "${BOX_V} ${WHITE}Shell:${NC} ${ZSH_VERSION:-bash}"
    echo -e "${BOX_V} ${WHITE}WAN IP:${NC} ${wan_ip}"
    echo -e "${BOX_V} ${WHITE}LAN IP:${NC} ${lan_ip}"
    echo -e "${BOX_V} ${WHITE}Hostname:${NC} $(hostname 2>/dev/null || echo 'unknown')"
    echo -e "${BOX_V} ${WHITE}User:${NC} $(whoami 2>/dev/null || echo 'unknown') ($(id -u 2>/dev/null || echo '?'):$(id -g 2>/dev/null || echo '?'))"
    echo -e "${CYAN}▉════════════════by═C-Fu════════════════${NC}"
    echo
}

install_uv() {
    command -v uv >/dev/null 2>&1 && return 0

    echo -e "${CYAN}  Installing uv...${NC}"

    if command -v curl >/dev/null 2>&1; then
        retry_network 3 5 "curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh" 2>/dev/null
        if [ -f /tmp/uv-install.sh ]; then
            sh /tmp/uv-install.sh && rm -f /tmp/uv-install.sh && export PATH="$HOME/.local/bin:$PATH" && return 0
            rm -f /tmp/uv-install.sh
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/uv-install.sh https://astral.sh/uv/install.sh 2>/dev/null
        if [ -f /tmp/uv-install.sh ]; then
            sh /tmp/uv-install.sh && rm -f /tmp/uv-install.sh && export PATH="$HOME/.local/bin:$PATH" && return 0
            rm -f /tmp/uv-install.sh
        fi
    fi

    if command -v pipx >/dev/null 2>&1; then
        pipx install uv 2>/dev/null && export PATH="$HOME/.local/bin:$PATH" && return 0
    fi

    if command -v pip3 >/dev/null 2>&1; then
        pip3 install uv 2>/dev/null && export PATH="$HOME/.local/bin:$PATH" && return 0
    elif command -v pip >/dev/null 2>&1; then
        pip install uv 2>/dev/null && export PATH="$HOME/.local/bin:$PATH" && return 0
    fi

    if command -v brew >/dev/null 2>&1; then
        brew install uv 2>/dev/null && return 0
    fi

    if command -v cargo >/dev/null 2>&1; then
        cargo install --locked uv 2>/dev/null && export PATH="$HOME/.cargo/bin:$PATH" && return 0
    fi

    echo -e "${RED}  ✗ uv install failed — no supported install method available${NC}"
    return 1
}

# ──────────────
# 🔑 Option 4: Set GitHub Token
# ──────────────
_GITHUB_TOKEN_FILE="$HOME/.config/dev-fu/github-token"

_github_token_header() {
    if [ -f "$_GITHUB_TOKEN_FILE" ]; then
        local tok
        tok=$(cat "$_GITHUB_TOKEN_FILE" 2>/dev/null)
        [ -n "$tok" ] && echo "-H 'Authorization: token $tok'"
    fi
}

set_github_token() {
    echo -e "${CYAN}${EMOJI_TOKEN}  ${BOLD}Set GitHub Personal Access Token${NC}"
    echo -e "${DIM}   Increases GitHub API rate limit from 60 to 5,000 requests/hr${NC}"
    echo

    if [ -f "$_GITHUB_TOKEN_FILE" ]; then
        local cur
        cur=$(cat "$_GITHUB_TOKEN_FILE" 2>/dev/null)
        if [ -n "$cur" ]; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Token already set (${cur:0:4}****${cur: -4})"
        fi
    fi

    echo -e "${BOLD}  How to create a GitHub Personal Access Token:${NC}"
    echo -e "  1. Go to ${CYAN}https://github.com/settings/tokens${NC}"
    echo -e "  2. Click ${BOLD}Generate new token${NC} (classic)"
    echo -e "  3. Give it a name (e.g. 'dev-fu')"
    echo -e "  4. Select scopes: ${DIM}public_repo${NC} is enough for version checks"
    echo -e "  5. Click ${BOLD}Generate token${NC}"
    echo -e "  6. Copy the token (starts with ghp_)"
    echo

    read -rp "  Paste your token (or press Enter to cancel): " token
    if [ -z "$token" ]; then
        echo -e "${DIM}  Cancelled.${NC}"
        return
    fi

    mkdir -p "$(dirname "$_GITHUB_TOKEN_FILE")"
    echo "$token" > "$_GITHUB_TOKEN_FILE"
    chmod 600 "$_GITHUB_TOKEN_FILE"

    local test_result
    test_result=$(curl -sL -H "Authorization: token $token" "https://api.github.com/rate_limit" 2>/dev/null | grep '"remaining"' | head -1 | grep -oE '[0-9]+')
    if [ -n "$test_result" ]; then
        echo -e "${GREEN}  ✓ Token saved — API rate limit: $test_result requests remaining${NC}"
    else
        echo -e "${YELLOW}  ⚠ Token saved but verification failed — check if the token is valid${NC}"
    fi
}

# ──────────────
# 🐳 Option 5: Install Docker
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi
    
    echo -e "${CYAN}  Downloading Docker install script...${NC}"

    if command -v apk >/dev/null 2>&1; then
        pkg_install docker docker-cli-compose || { echo -e "${RED}  ✗ Docker install failed${NC}"; return 1; }
        _maybe_sudo rc-update add docker boot 2>/dev/null || true
        _maybe_sudo service docker start 2>/dev/null || true
    else
        retry_network 3 5 "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh" || { echo -e "${RED}  ✗ Docker download failed${NC}"; return 1; }
        _maybe_sudo sh /tmp/get-docker.sh || { echo -e "${RED}  ✗ Docker install failed${NC}"; return 1; }
        rm -f /tmp/get-docker.sh
    fi
    
    echo -e "${GREEN}  ✓ Docker installed successfully${NC}"
}

# 🗑️ Option 5a: Remove Docker
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi
    
    echo -e "${CYAN}  Removing Docker...${NC}"
    if command -v apk >/dev/null 2>&1; then
        pkg_purge docker docker-cli-compose || true
    else
        pkg_purge docker.io docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    fi
    _maybe_sudo rm -rf /var/lib/docker /etc/docker
    _maybe_sudo rm -f /etc/apt/sources.list.d/docker.list
    pkg_update || true
    
    echo -e "${GREEN}  ✓ Docker removed successfully${NC}"
}

# 🌐 Option 8: Install Linux Hostname Discovery (avahi-daemon + systemd-resolved)
# ──────────────
install_avahi() {
    echo -e "${CYAN}🌐  ${BOLD}Install Linux Hostname Discovery${NC}"
    echo -e "${DIM}   avahi-daemon (mDNS/NSS) + systemd-resolved (DNS)${NC}"
    echo

    if [ "$DETECTED_OS" != "linux" ]; then
        echo -e "  ${BYELLOW}⚠  This option is only available on Linux.${NC}"
        echo -e "${DIM}  macOS uses mDNSResponder; Windows uses Bonjour/WSL.${NC}"
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "  ${BYELLOW}⚠  This option requires systemd.${NC}"
        echo -e "${DIM}  Not available on this environment (Chromebook container, Termux, etc.).${NC}"
        return 0
    fi

    local already_done=1

    if command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon already installed"
        if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Avahi Daemon is running"
        else
            echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Avahi Daemon is not running - starting..."
            _maybe_sudo systemctl enable avahi-daemon
            _maybe_sudo systemctl start avahi-daemon
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    if ! command -v avahi-daemon >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Avahi Daemon...${NC}"
        pkg_update || { echo -e "${RED}  ✗ Package update failed${NC}"; return 1; }
        pkg_install avahi-daemon avahi-utils || { echo -e "${RED}  ✗ Avahi install failed${NC}"; return 1; }
        _maybe_sudo systemctl enable avahi-daemon || { echo -e "${YELLOW}  ⚠ Could not enable avahi-daemon${NC}"; }
        _maybe_sudo systemctl start avahi-daemon || { echo -e "${YELLOW}  ⚠ Could not start avahi-daemon${NC}"; }
    fi

    if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "${CYAN}  Setting up systemd-resolved...${NC}"
        if [ -x /usr/lib/systemd/systemd-resolved ] || [ -x /lib/systemd/systemd-resolved ]; then
            echo -e "${DIM}  systemd-resolved binary already present — enabling${NC}"
        else
            local resolved_pkg="systemd-resolved"
            if ! apt-cache show systemd-resolved >/dev/null 2>&1; then
                resolved_pkg="systemd"
            fi
            pkg_install "$resolved_pkg" || { echo -e "${RED}  ✗ systemd-resolved install failed${NC}"; return 1; }
        fi
        echo -e "${CYAN}  Enabling systemd-resolved...${NC}"
        _maybe_sudo systemctl enable --now systemd-resolved || { echo -e "${YELLOW}  ⚠ Could not enable systemd-resolved${NC}"; }
    fi

    echo -e "${CYAN}  Swapping DNS to systemd-resolved...${NC}"
    _maybe_sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || { echo -e "${YELLOW}  ⚠ DNS symlink failed${NC}"; }

    echo -e "${GREEN}  ✓ Hostname discovery installed and configured${NC}"
}

# 🗑️ Option 8a: Remove Hostname Discovery (Avahi + systemd-resolved)
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    echo -e "${CYAN}  Restoring default DNS...${NC}"
    if [ -L /etc/resolv.conf ]; then
        _maybe_sudo rm -f /etc/resolv.conf
        echo -e "${CYAN}  Restoring /etc/resolv.conf...${NC}"
        _maybe_sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf && echo "nameserver 8.8.4.4" >> /etc/resolv.conf'
    fi

    echo -e "${CYAN}  Stopping systemd-resolved...${NC}"
    _maybe_sudo systemctl stop systemd-resolved 2>/dev/null || true
    _maybe_sudo systemctl disable systemd-resolved 2>/dev/null || true

    echo -e "${CYAN}  Removing Avahi Daemon...${NC}"
    _maybe_sudo systemctl stop avahi-daemon 2>/dev/null || true
    _maybe_sudo systemctl disable avahi-daemon 2>/dev/null || true
    pkg_purge avahi-daemon avahi-utils || true
    pkg_autoremove || true

    echo -e "${GREEN}  ✓ Hostname discovery removed successfully${NC}"
}

# ──────────────
# ✨ Option 6: Fancy Prompt
# ──────────────
_reset_prompt() {
    local rc_file="$1"
    rm -f "$HOME/.fancy-prompt.sh" "$HOME/.fancy-prompt-blue.sh"
    sed -i.bak '/source ~\/.fancy-prompt.sh/d; /source ~\/.fancy-prompt-blue.sh/d' "$rc_file" 2>/dev/null || true
    unset PROMPT_COMMAND 2>/dev/null || true
    unset NEW_PWD 2>/dev/null || true
    export PS1="\u@\h:\w\$ "
}

_write_prompt_purple() {
    cat > "$1" << 'PROMPT_EOF'
#################################
#            ICONS              #
#################################

declare -A __ICONS=( \
  ["separator"]="" \
  ["local_branch"]="" \
  ["remote_branch"]="" \
  ["merged_branch"]="" \
  ["stashed"]="󰏢" \
)


#################################
#            COLORS             #
#################################

declare -A __THEME=(\
  ["default"]="-1"\
  ["fg"]="253"\
  ["bglighter"]="238"\
  ["bglight"]="237"\
  ["bg"]="236"\
  ["bgdark"]="235"\
  ["bgdarker"]="234"\
  ["violet"]="69"\
  ["selection"]="239"\
  ["subtle"]="238"\
  ["cyan"]="74"\
  ["green"]="28"\
  ["sky"]="38"\
  ["orange"]="215"\
  ["pink"]="169"\
  ["mauve"]="99"\
  ["red"]="203"\
  ["yellow"]="226"\
  ["lightgray"]="252"\
  ["white"]="255"\
)

__bg() {
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[49m\\]"
  else
    echo "\\[\\e[48;5;${color_code}m\\]"
  fi
}

__fg() {
  local color_code=$1
  if [ "-1" = "${color_code}" ]
  then
    echo "\\[\\e[39m\\]"
  else
    echo "\\[\\e[38;5;${color_code}m\\]"
  fi
}

__colorized_separator() {
  local left_color="$1"
  local right_color="$2"
  echo "$(__fg $left_color)$(__bg $right_color)${__ICONS[separator]}"
}

#################################
#             USER              #
#################################

user_text="\u@\h"


#################################
#             PATH             #
#################################

path_text="\w"


#################################
#          GIT BRANCH           #
#################################

__branch_name() {
  git rev-parse --abbrev-ref HEAD 2> /dev/null
}

__remote_branch_name() {
  local branch=$(__branch_name)
  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$branch")

  if [ 0 -eq "$is_only_local_branch" ]; then echo ""; return; fi
  local remote_name

  remote_name=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2> /dev/null | cut -d"/" -f1)
  remote_name=${remote_name:-origin}
  echo "$remote_name"
}

__branch_is_local_only() {
  local param_branch_name="$1"
  local is_only_local_branch

  is_only_local_branch=$(git branch -r 2> /dev/null | grep -c "$param_branch_name")

  if [ 0 -eq "$is_only_local_branch" ]; then return 0; fi
  return 1
}

__branch_is_merged() {
  local branch
  local merged=""

  branch=$(__branch_name)

  merged=$(git branch -r --merged master 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi

  merged=$(git branch -r --merged develop 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; fi

  merged=$(git branch -r --merged main 2> /dev/null | grep "$branch" 2> /dev/null)
  if [ "" != "$merged" ]; then return 0; else return 1; fi
}

__branch_icon() {
  local param_branch_name="$1"

  if $(__branch_is_local_only)
  then
      echo "${__ICONS[local_branch]}"
      return
  fi

  if $(__branch_is_merged)
  then
      echo "${__ICONS[merged_branch]}"
      return
  fi

  echo "${__ICONS[remote_branch]}"
}

__branch_text() {
  local branch_text=""
  if [ "" != "$(__branch_name)" ]; then branch_text="$(__branch_icon) $(__branch_name)"; fi
  echo "${branch_text}"
}


#################################
#         GIT STATUS            #
#################################

__staged() {
  git diff --name-only --cached 2> /dev/null
}

__untracked() {
  git ls-files --others --exclude-standard 2> /dev/null
}

__changed() {
  git ls-files -m 2> /dev/null
}

__stashed() {
  local msg="$(git stash list 2> /dev/null)"
  if [[ "" != "${msg}" ]]; then echo "${__ICONS[stashed]}"; else echo ""; fi
}

__unpushed() {
    local branch_name=$(__branch_name)
    local remote_name=$(__remote_branch_name)
    git log --pretty=oneline "${remote_name}"/"${branch_name}"..HEAD 2> /dev/null
}

__needs_pull() {
  local local_only=$(__branch_is_local_only)
  if [ "0" != "${local_only}" ]
  then
    echo "0"
    return 0
  fi
  local branch_name=$(__branch_name)
  if [ "" != "${branch_name}" ]
  then
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse @{u})" ]; then echo "0"; else echo "1"; fi
  else
		echo "0"
  fi
}

#################################
#             VENV              #
#################################

__venv() {
  if [ "${VIRTUAL_ENV}" ]
  then
    echo $(basename "${VIRTUAL_ENV}")
  else
    echo ""
  fi
}

#################################
#            BLOCKS             #
#################################

__block() {
  local prev_bg="$1"
  local bg="$2"
  local fg="$3"
  local text="$4"

  local color_separator="$(__colorized_separator $prev_bg $bg)"
  local foreground="$(__fg $fg)"
  local color_text="${foreground}${text}"
  if [ "" = "${text}" ]
  then
    echo ${color_text}
  else
    echo " ${color_separator} ${color_text}"
  fi
}

__chain() {
  local blocks=("$@")

  local block
  local chain=""

  local default_background="$(__bg "${__THEME[default]}")"
  local default_fontcolor=$(__fg "${__THEME[default]}")

  local prev_background
  for raw_block in "${blocks[@]}";
  do
    local block_array
    IFS=';' block_array=($raw_block)
    local background="${block_array[0]}"
    local font_color="${block_array[1]}"
    local text="${block_array[2]}"

    if [ -z "$prev_background" ]; then prev_background=$background; fi
    if [ "" != "${text}" ]
    then
      block=$(__block "${prev_background}" "${background}" "${font_color}" "${text}")
      chain+="${block}"
      prev_background="${background}"
    fi
  done

  chain+=" $(__colorized_separator "${prev_background}" "${__THEME[default]}")"

  chain+="${default_background}${default_fontcolor} "

  echo "${chain}"
}


prompt() {
  local user="${__THEME[mauve]};${__THEME[white]};${user_text}"
  local path="${__THEME[violet]};${__THEME[white]};${path_text}"

  local branch="$(__branch_text)"
  local branch_color="${__THEME[subtle]};${__THEME[white]}"
  if [ "0" != "$(__needs_pull)" ]; then branch_color="${__THEME[red]};${__THEME[white]}"; fi
  if [ "" != "$(__unpushed)" ]; then branch_color="${__THEME[green]};${__THEME[white]}"; fi
  if [ "" != "$(__staged)" ]; then branch_color="${__THEME[yellow]};${__THEME[bgdark]}"; fi
  if [ "" != "$(__changed)" ]; then branch_color="${__THEME[orange]};${__THEME[white]}"; fi
  if [ "" != "$(__untracked)" ]; then branch_color="${__THEME[pink]};${__THEME[bgdark]}"; fi
  branch="${branch_color};${branch}"

  local stash="${__THEME[sky]};${__THEME[white]};$(__stashed)"

  local venv=$(__venv)
  if [ "" != "$venv" ]
  then
    venv="${__THEME[lightgray]};${__THEME[bgdark]};${venv}"
  fi

  declare -a chain=( ${user} ${path} "${stash}" "${branch}" "${venv}" )

  PS1=$(__chain "${chain[@]}")
}

PROMPT_COMMAND="prompt"
PROMPT_EOF
}

_write_prompt_blue() {
    cat > "$1" << 'PROMPT_EOF'
#!/bin/sh

bash_prompt_command() {
  local pwdmaxlen=25
  local trunc_symbol=".."
  local dir=${PWD##*/}
  pwdmaxlen=$(( ( pwdmaxlen < ${#dir} ) ? ${#dir} : pwdmaxlen ))
  NEW_PWD=${PWD/#$HOME/\~}
  local pwdoffset=$(( ${#NEW_PWD} - pwdmaxlen ))
  if [ ${pwdoffset} -gt "0" ]
  then
    NEW_PWD=${NEW_PWD:$pwdoffset:$pwdmaxlen}
    NEW_PWD=${trunc_symbol}/${NEW_PWD#*/}
  fi
}

format_font()
{
  local output=$1
  case $# in
  2)
    eval $output="'\[\033[0;${2}m\]'"
    ;;
  3)
    eval $output="'\[\033[0;${2};${3}m\]'"
    ;;
  4)
    eval $output="'\[\033[0;${2};${3};${4}m\]'"
    ;;
  *)
    eval $output="'\[\033[0m\]'"
    ;;
  esac
}

bash_prompt() {
  local      NONE='0'
  local      BOLD='1'
  local       DIM='2'
  local UNDERLINE='4'
  local     BLINK='5'
  local    INVERT='7'
  local    HIDDEN='8'

  local   DEFAULT='9'
  local     BLACK='0'
  local       RED='1'
  local     GREEN='2'
  local    YELLOW='3'
  local      BLUE='4'
  local   MAGENTA='5'
  local      CYAN='6'
  local    L_GRAY='7'
  local    D_GRAY='60'
  local     L_RED='61'
  local   L_GREEN='62'
  local  L_YELLOW='63'
  local    L_BLUE='64'
  local L_MAGENTA='65'
  local    L_CYAN='66'
  local     WHITE='67'

  local     RESET='0'
  local    EFFECT='0'
  local     COLOR='30'
  local        BG='40'

  local NO_FORMAT="\[\033[0m\]"
  local CYAN_BOLD="\[\033[1;38;5;87m\]"
  local BLUE_BOLD="\[\033[1;38;5;74m\]"

  local FONT_COLOR_1=$WHITE
  local BACKGROUND_1=$BLUE
  local TEXTEFFECT_1=$BOLD

  local FONT_COLOR_2=$WHITE
  local BACKGROUND_2=$L_BLUE
  local TEXTEFFECT_2=$BOLD

  local FONT_COLOR_3=$D_GRAY
  local BACKGROUND_3=$WHITE
  local TEXTEFFECT_3=$BOLD

  local PROMT_FORMAT=$BLUE_BOLD

  FC1=$(($FONT_COLOR_1+$COLOR))
  BG1=$(($BACKGROUND_1+$BG))
  FE1=$(($TEXTEFFECT_1+$EFFECT))

  FC2=$(($FONT_COLOR_2+$COLOR))
  BG2=$(($BACKGROUND_2+$BG))
  FE2=$(($TEXTEFFECT_2+$EFFECT))

  FC3=$(($FONT_COLOR_3+$COLOR))
  BG3=$(($BACKGROUND_3+$BG))
  FE3=$(($TEXTEFFECT_3+$EFFECT))

  local TEXT_FORMAT_1
  local TEXT_FORMAT_2
  local TEXT_FORMAT_3
  format_font TEXT_FORMAT_1 $FE1 $FC1 $BG1
  format_font TEXT_FORMAT_2 $FE2 $FC2 $BG2
  format_font TEXT_FORMAT_3 $FC3 $FE3 $BG3

  local PROMT_USER=$"$TEXT_FORMAT_1 \u "
  local PROMT_HOST=$"$TEXT_FORMAT_2 \h "
  local PROMT_PWD=$"$TEXT_FORMAT_3 \${NEW_PWD} "
  local PROMT_INPUT=$"$PROMT_FORMAT "

  TSFC1=$(($BACKGROUND_1+$COLOR))
  TSBG1=$(($BACKGROUND_2+$BG))

  TSFC2=$(($BACKGROUND_2+$COLOR))
  TSBG2=$(($BACKGROUND_3+$BG))

  TSFC3=$(($BACKGROUND_3+$COLOR))
  TSBG3=$(($DEFAULT+$BG))

  local SEPARATOR_FORMAT_1
  local SEPARATOR_FORMAT_2
  local SEPARATOR_FORMAT_3
  format_font SEPARATOR_FORMAT_1 $TSFC1 $TSBG1
  format_font SEPARATOR_FORMAT_2 $TSFC2 $TSBG2
  format_font SEPARATOR_FORMAT_3 $TSFC3 $TSBG3

  local TRIANGLE=$'\uE0B0'
  local SEPARATOR_1=$SEPARATOR_FORMAT_1$TRIANGLE
  local SEPARATOR_2=$SEPARATOR_FORMAT_2$TRIANGLE
  local SEPARATOR_3=$SEPARATOR_FORMAT_3$TRIANGLE

  case $TERM in
  xterm*|rxvt*)
    local TITLEBAR='\[\033]0;\u:${NEW_PWD}\007\]'
    ;;
  *)
    local TITLEBAR=""
    ;;
  esac

  PS1="$TITLEBAR\n${PROMT_USER}${SEPARATOR_1}${PROMT_HOST}${SEPARATOR_2}${PROMT_PWD}${SEPARATOR_3}${PROMT_INPUT}"

  none="$(tput sgr0)"
  trap 'echo -ne "${none}"' DEBUG
}

PROMPT_COMMAND=bash_prompt_command
bash_prompt
unset bash_prompt
PROMPT_EOF
}

create_fancy_prompt() {
    echo -e "${MAGENTA}${EMOJI_PROMPT}  ${BOLD}Create Fancy Prompt (Purple-Pink)${NC}"
    echo

    local rc_file=$(detect_rc_file)
    local target="$HOME/.fancy-prompt.sh"

    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Replace current fancy prompt? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    _reset_prompt "$rc_file"

    _write_prompt_purple "$target"
    chmod +x "$target"
    append_rc_if_missing "$rc_file" "source ~/.fancy-prompt.sh"
    source "$target" 2>/dev/null || true
    source "$rc_file" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Fancy prompt (Purple-Pink) installed${NC}"
    echo -e "${DIM}  Run \`source $rc_file\` or open a new terminal to see the prompt${NC}"
}

remove_fancy_prompt() {
    echo -e "${RED}➜ Remove Fancy Prompt${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove fancy prompt? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    rm -f "$HOME/.fancy-prompt.sh"
    sed -i.bak '/source ~\/.fancy-prompt.sh/d' "$(detect_rc_file)" 2>/dev/null || true
    unset PROMPT_COMMAND
    export PS1="\u@\h:\w\$ "
    echo -e "${GREEN}  ✓ Fancy prompt removed${NC}"
}

create_fancy_prompt_blue() {
    echo -e "${BLUE}${EMOJI_PROMPT_BLUE}  ${BOLD}Create Fancy Prompt (Shades of Blue)${NC}"
    echo

    local rc_file=$(detect_rc_file)
    local target="$HOME/.fancy-prompt-blue.sh"

    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Install blue fancy prompt? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    _reset_prompt "$rc_file"

    _write_prompt_blue "$target"
    chmod +x "$target"
    append_rc_if_missing "$rc_file" "source ~/.fancy-prompt-blue.sh"
    source "$target" 2>/dev/null || true
    source "$rc_file" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Fancy prompt (Shades of Blue) installed${NC}"
    echo -e "${DIM}  Run \`source $rc_file\` or open a new terminal to see the prompt${NC}"
}

remove_fancy_prompt_blue() {
    echo -e "${RED}➜ Remove Blue Fancy Prompt${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove blue fancy prompt? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    rm -f "$HOME/.fancy-prompt-blue.sh"
    sed -i.bak '/source ~\/.fancy-prompt-blue.sh/d' "$(detect_rc_file)" 2>/dev/null || true
    unset PROMPT_COMMAND
    export PS1="\u@\h:\w\$ "
    echo -e "${GREEN}  ✓ Blue fancy prompt removed${NC}"
}

# ──────────────
# 🔍 Option 1: Status Check
# ──────────────
status_check() {
    echo -e "${CYAN}${EMOJI_STATUS}  ${BOLD}Status Check${NC}"
    echo -e "${DIM}   Checking developer tools...${NC}"
    echo

    check_cmd_version() {
        local name="$1"; local cmd="$2"; local flag="$3"
        if command -v "$cmd" >/dev/null 2>&1; then
            if command -v timeout >/dev/null 2>&1; then
                ver=$(echo "y" | timeout 5 $cmd $flag 2>/dev/null | head -n1 | tr -s ' ')
            else
                ver=$(echo "y" | $cmd $flag 2>/dev/null | head -n1 | tr -s ' ')
            fi
            printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "$name" "${ver:-installed}"
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
        local nvm_ver
        nvm_ver=$(nvm --version 2>/dev/null)
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "NVM" "${nvm_ver:-installed}"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "NVM"
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
    if command -v openchamber >/dev/null 2>&1; then
        local oc_ver
        oc_ver=$(openchamber --version 2>/dev/null || echo 'installed')
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "OpenChamber" "$oc_ver"
    elif npm list -g @openchamber/web >/dev/null 2>&1; then
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "OpenChamber" "npm global"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "OpenChamber"
    fi

    if command -v opencode >/dev/null 2>&1; then
        local oc_ver
        oc_ver=$(opencode --version 2>/dev/null || echo 'installed')
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "OpenCode" "$oc_ver"
    elif npm list -g opencode-ai >/dev/null 2>&1; then
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "OpenCode" "npm global"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "OpenCode"
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
        gsd_version=$(npx --yes gsd-opencode --version 2>/dev/null | head -n1)
        [[ -z "$gsd_version" ]] && gsd_version="npx cache"
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
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "GSD" "$gsd_version"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "GSD"
    fi

    if command -v tailscale >/dev/null 2>&1; then
        local ts_ver
        ts_ver=$(tailscale version 2>/dev/null | head -1)
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "Tailscale" "${ts_ver:-installed}"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "Tailscale"
    fi
    
    echo
    echo -e "${GREEN}  ✓ Status check complete${NC}"
}

status_check_compare() {
    echo -e "${CYAN}${EMOJI_COMPARE}  ${BOLD}Compare Local vs Latest Versions${NC}"
    echo -e "${DIM}   Fetching latest versions online...${NC}"
    echo

    [[ -s "$HOME/.nvm/nvm.sh" ]] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    _scc_gh() {
        local repo="$1"
        local tag
        local auth_header=""
        if [ -f "$_GITHUB_TOKEN_FILE" ]; then
            local _tok
            _tok=$(cat "$_GITHUB_TOKEN_FILE" 2>/dev/null)
            [ -n "$_tok" ] && auth_header="-H \"Authorization: token $_tok\""
        fi
        tag=$(eval curl -fsSL --connect-timeout 5 --max-time 10 $auth_header \"https://api.github.com/repos/$repo/releases/latest\" 2>/dev/null \
            | grep '"tag_name"' | head -1 \
            | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if [ -z "$tag" ]; then
            tag=$(eval curl -fsSL --connect-timeout 5 --max-time 10 $auth_header \"https://api.github.com/repos/$repo/tags?per_page=1\" 2>/dev/null \
                | grep '"name"' | head -1 \
                | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
        if [ -z "$tag" ]; then
            case "$repo" in
                nvm-sh/nvm)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/package.json" 2>/dev/null \
                        | grep '"version"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                astral-sh/uv)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://pypi.org/pypi/uv/json" 2>/dev/null \
                        | grep -oE '"version":"[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                anomalyco/opencode)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://registry.npmjs.org/opencode-ai/latest" 2>/dev/null \
                        | grep -oE '"version":"[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                rokicool/gsd-opencode)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://registry.npmjs.org/gsd-opencode/latest" 2>/dev/null \
                        | grep -oE '"version":"[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                moby/moby)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://raw.githubusercontent.com/moby/moby/refs/heads/master/VERSION" 2>/dev/null \
                        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                rust-lang/rust)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://static.rust-lang.org/dist/channel-rust-stable.toml" 2>/dev/null \
                        | grep '^version =' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                oven-sh/bun)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://raw.githubusercontent.com/oven-sh/bun/refs/heads/main/package.json" 2>/dev/null \
                        | grep '"version"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                php/php-src)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://raw.githubusercontent.com/php/php-src/refs/heads/master/main/php_version.h" 2>/dev/null \
                        | grep 'PHP_VERSION "' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                    ;;
                composer/composer)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://getcomposer.org/download/" 2>/dev/null \
                        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                    ;;
                tailscale/tailscale)
                    tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
                        "https://pkgs.tailscale.com/stable/?mode=json" 2>/dev/null \
                        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                    ;;
            esac
        fi
        if [ -z "$tag" ]; then
            local gh_err
            gh_err=$(curl -sL --connect-timeout 5 --max-time 10 -w "%{http_code}" -o /dev/null "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)
            echo "GH-${gh_err:-ERR}:$repo"
            return
        fi
        tag="${tag#v}"
        tag="${tag#docker-v}"
        tag="${tag#bun-v}"
        tag="${tag#php-}"
        echo "$tag"
    }

    _scc_local() {
        local cmd="$1" flag="$2"
        [[ -s "$HOME/.nvm/nvm.sh" ]] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        export PATH="$HOME/.local/bin:$HOME/.npm/bin:$PATH"
        if command -v "$cmd" >/dev/null 2>&1; then
            if command -v timeout >/dev/null 2>&1; then
                echo "y" | timeout 5 "$cmd" $flag 2>/dev/null | head -n1
            else
                echo "y" | "$cmd" $flag 2>/dev/null | head -n1
            fi
            return
        fi
        for p in "$HOME/.nvm/versions/node"/*/bin "$HOME/.local/bin" "$HOME/.npm/bin"; do
            if [ -x "$p/$cmd" ]; then
                if command -v timeout >/dev/null 2>&1; then
                    echo "y" | timeout 5 "$p/$cmd" $flag 2>/dev/null | head -n1
                else
                    echo "y" | "$p/$cmd" $flag 2>/dev/null | head -n1
                fi
                return
            fi
        done
    }

    _scc_ver() {
        echo "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?([._-]?[a-zA-Z0-9]+)*' | head -1
    }

    _scc_row() {
        local name="$1" local_raw="$2" latest="$3"
        local local_ver="" lat="${latest:---}"

        if [[ "$latest" == GH-* ]]; then
            lat="${latest%%:*}"
        fi

        if [[ -z "$local_raw" ]]; then
            local_ver=""
        else
            local_ver=$(_scc_ver "$local_raw")
        fi

        if [[ "$latest" == GH-* ]]; then
            printf "  %-13s \033[2m%-22s\033[0m " "$name" "${local_ver:-not installed}"
            echo -e "${RED}${lat}${NC} ${DIM}(rate limited)${NC}"
        elif [[ -z "$local_raw" ]]; then
            printf "  %-13s \033[2m%-22s\033[0m %-16s " "$name" "not installed" "$lat"
            echo -e "${DIM}—${NC}"
        elif [[ -z "$latest" ]]; then
            printf "  %-13s %-22s %-16s " "$name" "$local_ver" "—"
            echo -e "${DIM}?${NC}"
        elif [[ -z "$local_ver" ]]; then
            printf "  %-13s %-22s %-16s " "$name" "?" "$lat"
            echo -e "${DIM}?${NC}"
        elif [[ "$local_ver" == "$latest" ]]; then
            printf "  %-13s %-22s %-16s " "$name" "$local_ver" "$lat"
            echo -e "${GREEN}✓ up to date${NC}"
        else
            printf "  %-13s %-22s %-16s " "$name" "$local_ver" "$lat"
            echo -e "${YELLOW}⬆ update available${NC}"
        fi
    }

    echo -e "  ${BOLD}Tool           Installed              Latest           Status${NC}"
    echo -e "  $(printf '%.0s─' {1..70})"

    _scc_row "Docker"   "$(_scc_local docker --version)"   "$(_scc_gh moby/moby)"
    _scc_row "Go"       "$(_scc_local go version)"         "$(curl -fsSL --max-time 5 'https://go.dev/dl/?mode=json' 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"go\([^"]*\)".*/\1/')"
    _scc_row "Rust"     "$(_scc_local rustc --version)"    "$(_scc_gh rust-lang/rust)"
    _scc_row "Bun"      "$(_scc_local bun --version)"      "$(_scc_gh oven-sh/bun)"

    local nvm_local=""
    if _is_musl; then
        nvm_local="N/A (Alpine)"
    else
        [[ -s "$HOME/.nvm/nvm.sh" ]] && nvm_local="nvm $(source "$HOME/.nvm/nvm.sh" 2>/dev/null && nvm --version)"
    fi
    _scc_row "NVM"      "$nvm_local"                       "$(_scc_gh nvm-sh/nvm)"

    _scc_row "Node.js"  "$(_scc_local node --version)"     "$(curl -fsSL --max-time 5 'https://nodejs.org/dist/index.json' 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/')"
    _scc_row "npx"      "$(_scc_local npx --version)"      ""
    _scc_row "Python"   "$(_scc_local python3 --version)"  "$(curl -fsSL --max-time 5 'https://endoflife.date/api/python.json' 2>/dev/null | grep -o '"latest":"[^"]*"' | head -1 | sed 's/"latest":"//;s/"//')"
    _scc_row "uv"       "$(_scc_local uv --version)"       "$(_scc_gh astral-sh/uv)"

    local yarn_latest=""
    command -v npm >/dev/null 2>&1 && yarn_latest=$(npm view yarn version 2>/dev/null)
    _scc_row "Yarn"     "$(_scc_local yarn --version)"     "$yarn_latest"

    _scc_row "PHP"      "$(_scc_local php -v)"             "$(_scc_gh php/php-src)"
    _scc_row "Composer" "$(_scc_local composer --version)" "$(_scc_gh composer/composer)"

    local ts_local=""
    ts_local=$(_scc_local tailscale version)
    local ts_latest=""
    ts_latest=$(_scc_gh tailscale/tailscale)
    _scc_row "Tailscale"  "$ts_local"                       "$ts_latest"

    _scc_row "OpenCode" "$(_scc_local opencode --version)" "$(_scc_gh anomalyco/opencode)"

    local oc_local=""
    oc_local=$(_scc_local openchamber --version)
    [[ -z "$oc_local" ]] && npm list -g @openchamber/web >/dev/null 2>&1 && oc_local="npm global"
    local oc_latest=""
    command -v npm >/dev/null 2>&1 && oc_latest=$(npm view @openchamber/web version 2>/dev/null)
    _scc_row "OpenChamber" "$oc_local" "$oc_latest"

    local gsd_local=""
    gsd_local=$(npm list -g gsd-opencode 2>/dev/null | grep -oE 'gsd-opencode@[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ -z "$gsd_local" ]]; then
        gsd_local=$(_scc_ver "$(npx --yes gsd-opencode --version 2>/dev/null | head -1)")
    fi
    local gsd_latest=""
    gsd_latest=$(_scc_gh rokicool/gsd-opencode)
    _scc_row "GSD"      "$gsd_local"                       "$gsd_latest"

    echo -e "  $(printf '%.0s─' {1..70})"
    echo
    echo -e "${GREEN}  ✓ Comparison complete${NC}"
}

# ──────────────
# 🛠️ Option 9: Install Go
# ──────────────
install_go() {
    echo -e "${CYAN}${EMOJI_GO}  ${BOLD}Install Go${NC}"
    echo -e "${DIM}   Go programming language${NC}"
    echo

    if command -v go >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Go already installed: $(go version)"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: Go${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    ensure_sudo
    pkg_update || { echo -e "${RED}  ✗ package update failed${NC}"; return 1; }
    local go_pkg="golang-go"
    if command -v apk >/dev/null 2>&1; then go_pkg="go"; fi
    pkg_install $go_pkg || { echo -e "${RED}  ✗ Go install failed${NC}"; return 1; }

    echo -e "${GREEN}  ✓ Go installed successfully${NC}"
}

remove_go() {
    echo -e "${RED}🗑️  ${BOLD}Remove Go${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Go? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    local go_pkg="golang-go"
    if command -v apk >/dev/null 2>&1; then go_pkg="go"; fi
    pkg_remove $go_pkg || { echo -e "${RED}  ✗ Go removal failed${NC}"; return 1; }
    echo -e "${GREEN}  ✓ Go removed${NC}"
}

install_rust() {
    echo -e "${CYAN}${EMOJI_RUST}  ${BOLD}Install Rust${NC}"
    echo -e "${DIM}   Rust programming language via rustup${NC}"
    echo

    if command -v rustc >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Rust already installed: $(rustc --version)"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: Rust (rustup, rustc, cargo)${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    retry_network 3 5 "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh" || { echo -e "${RED}  ✗ Rust download failed${NC}"; return 1; }
    sh /tmp/rustup.sh -y || { echo -e "${RED}  ✗ Rust install failed${NC}"; return 1; }
    rm -f /tmp/rustup.sh
    source "$HOME/.cargo/env"

    echo -e "${GREEN}  ✓ Rust installed successfully${NC}"
}

remove_rust() {
    echo -e "${RED}🗑️  ${BOLD}Remove Rust${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Rust? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    rustup self uninstall -y || { echo -e "${RED}  ✗ Rust uninstall failed${NC}"; return 1; }
    echo -e "${GREEN}  ✓ Rust removed${NC}"
}

install_python() {
    echo -e "${CYAN}${EMOJI_PYTHON}  ${BOLD}Install Python + Pip + UV + Pipx${NC}"
    echo -e "${DIM}   Python 3 with pip, uv package manager, and pipx${NC}"
    echo

    local need_install=0
    command -v python3 >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} Python will be installed"; need_install=1; }
    command -v pip3 >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} pip will be installed"; need_install=1; }
    command -v uv >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} uv will be installed"; need_install=1; }
    command -v pipx >/dev/null 2>&1 || { echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} pipx will be installed"; need_install=1; }

    if [ $need_install -eq 0 ]; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Python + Pip + UV + Pipx already installed"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: Python 3, pip, uv, pipx${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    ensure_sudo
    pkg_update || { echo -e "${RED}  ✗ package update failed${NC}"; return 1; }

    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Python + pip...${NC}"
        if command -v apk >/dev/null 2>&1; then
            pkg_install python3 py3-pip || { echo -e "${RED}  ✗ Python install failed${NC}"; return 1; }
        else
            pkg_install python3 python3-pip python3-venv || { echo -e "${RED}  ✗ Python install failed${NC}"; return 1; }
        fi
    fi

    if ! command -v pipx >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing pipx...${NC}"
        if command -v apk >/dev/null 2>&1; then
            pkg_install py3-pipx || { echo -e "${RED}  ✗ pipx install failed${NC}"; return 1; }
        else
            pkg_install pipx || { echo -e "${RED}  ✗ pipx install failed${NC}"; return 1; }
        fi
    fi

    if ! command -v uv >/dev/null 2>&1; then
        install_uv || { echo -e "${RED}  ✗ uv install failed${NC}"; return 1; }
        append_rc_if_missing "$(detect_rc_file)" 'export PATH="$HOME/.local/bin:$PATH"'
    fi

    echo -e "${GREEN}  ✓ Python + Pip + UV + Pipx installed successfully${NC}"
}

remove_python() {
    echo -e "${RED}🗑️  ${BOLD}Remove Python + Pip + UV + Pipx${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Python, pip, uv, and pipx? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    pkg_remove python3 python3-pip python3-venv pipx 2>/dev/null || true
    rm -rf "$HOME/.local/bin/uv" "$HOME/.local/share/uv" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Python + Pip + UV + Pipx removed${NC}"
}

_is_musl() {
    command -v apk >/dev/null 2>&1
}

install_nvm_node() {
    echo -e "${CYAN}${EMOJI_NODE}  ${BOLD}Install NVM + Node LTS${NC}"

    if _is_musl; then
        echo -e "${DIM}   Node.js LTS (native Alpine package — NVM skipped on musl)${NC}"
    else
        echo -e "${DIM}   Node Version Manager with latest LTS${NC}"
    fi
    echo

    if _is_musl; then
        if command -v node >/dev/null 2>&1; then
            echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Node.js already installed: $(node --version)"
            return 0
        fi

        echo -e "${BYELLOW}  → This will install: nodejs + npm (Alpine native)${NC}"
        if [[ "$BATCH_MODE" != "1" ]]; then
            read -rp "  Proceed? (y/n): " confirm
            [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
        fi

        echo -e "${CYAN}  Installing Node.js via apk...${NC}"
        pkg_install nodejs npm || { echo -e "${RED}  ✗ Node.js install failed${NC}"; return 1; }

        echo -e "${GREEN}  ✓ Node.js $(node --version) installed successfully${NC}"
        return 0
    fi

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    if command -v nvm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} NVM + Node already installed: $(node --version)"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: NVM + Node.js LTS${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    if ! command -v nvm >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing NVM...${NC}"
        retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o /tmp/nvm-install.sh" || { echo -e "${RED}  ✗ NVM download failed${NC}"; return 1; }
        bash /tmp/nvm-install.sh || { echo -e "${RED}  ✗ NVM install failed${NC}"; return 1; }
        rm -f /tmp/nvm-install.sh
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Node.js LTS...${NC}"
        nvm install --lts || { echo -e "${RED}  ✗ Node LTS install failed${NC}"; return 1; }
    fi

    echo -e "${GREEN}  ✓ NVM + Node LTS installed successfully${NC}"
}

remove_nvm_node() {
    echo -e "${RED}🗑️  ${BOLD}Remove NVM + Node${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove NVM and Node.js? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    if _is_musl; then
        pkg_purge nodejs npm || true
        echo -e "${GREEN}  ✓ Node.js removed${NC}"
        return
    fi

    if command -v nvm >/dev/null 2>&1; then
        nvm uninstall --lts 2>/dev/null || true
    fi
    rm -rf "$HOME/.nvm" 2>/dev/null || true
    echo -e "${GREEN}  ✓ NVM + Node removed${NC}"
}

install_bun() {
    echo -e "${CYAN}${EMOJI_BUN}  ${BOLD}Install Bun${NC}"
    echo -e "${DIM}   Fast JavaScript runtime & package manager${NC}"
    echo

    if command -v bun >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Bun already installed: $(bun --version)"
        return 0
    fi

    echo -e "${BYELLOW}  → This will install: Bun${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    retry_network 3 5 "curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh" || { echo -e "${RED}  ✗ Bun download failed${NC}"; return 1; }
    bash /tmp/bun-install.sh || { echo -e "${RED}  ✗ Bun install failed${NC}"; return 1; }
    rm -f /tmp/bun-install.sh
    export PATH="$HOME/.bun/bin:$PATH"

    echo -e "${GREEN}  ✓ Bun installed successfully${NC}"
}

remove_bun() {
    echo -e "${RED}🗑️  ${BOLD}Remove Bun${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Bun? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    rm -rf "$HOME/.bun"
    echo -e "${GREEN}  ✓ Bun removed${NC}"
}

install_yarn() {
    echo -e "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Install Yarn${NC}"
    echo -e "${DIM}   Fast, reliable dependency management${NC}"
    echo

    if command -v yarn >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Yarn already installed: $(yarn --version)"
        return 0
    fi

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    command -v npm >/dev/null 2>&1 || { echo -e "  ${RED}${EMOJI_CROSS} npm missing - install Node LTS first (option 12)${NC}"; return; }

    echo -e "${BYELLOW}  → This will install: Yarn${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    npm install -g yarn || { echo -e "${RED}  ✗ Yarn install failed${NC}"; return 1; }

    echo -e "${GREEN}  ✓ Yarn installed successfully${NC}"
}

remove_yarn() {
    echo -e "${RED}🗑️  ${BOLD}Remove Yarn${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Yarn? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    npm uninstall -g yarn 2>/dev/null || true
    echo -e "${GREEN}  ✓ Yarn removed${NC}"
}

disable_mouse_reporting() {
    echo -e "${CYAN}${EMOJI_MOUSE}  ${BOLD}Disable Mouse Reporting in Terminal${NC}"
    echo -e "${DIM}   Prevents terminal mouse events from interfering with CLI tools${NC}"
    echo

    local rc_file=$(detect_rc_file)
    local mouse_line="printf '\\e[?1000l\\e[?1002l\\e[?1003l\\e[?1006l'"

    if grep -F -- "$mouse_line" "$rc_file" >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Mouse reporting already disabled in ${rc_file}"
        return 0
    fi

    echo -e "${BYELLOW}  → This will add mouse disable commands to ${rc_file}${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
    append_rc_if_missing "$rc_file" "$mouse_line"

    echo -e "${GREEN}  ✓ Mouse reporting disabled${NC}"
}

enable_mouse_reporting() {
    echo -e "${RED}🗑️  ${BOLD}Re-enable Mouse Reporting${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Re-enable mouse reporting? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    local rc_file=$(detect_rc_file)
    local mouse_line="printf '\\e[?1000l\\e[?1002l\\e[?1003l\\e[?1006l'"
    sed -i.bak "/$(echo "$mouse_line" | sed 's/\[/\\[/g; s/\]/\\]/g')/d" "$rc_file" 2>/dev/null || true

    echo -e "${GREEN}  ✓ Mouse reporting re-enabled${NC}"
}

# ──────────────
# ⬆️ Option 3: Upgrade All Tools
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
            local pm="$(get_pkg_manager)"
            case "$pm" in
                apt)  _maybe_sudo apt-get update && _maybe_sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
                apk)  _maybe_sudo apk upgrade docker ;;
                dnf)  _maybe_sudo dnf upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin ;;
                pacman) _maybe_sudo pacman -Syu --noconfirm docker ;;
                zypper) _maybe_sudo zypper update -y docker ;;
                brew) brew upgrade docker ;;
                *) echo -e "${YELLOW}  Docker upgrade skipped — no supported package manager${NC}" ;;
            esac
        fi
        upgraded=1
    fi

    if command -v rustup >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Rust...${NC}"
        rustup update || echo -e "${YELLOW}  Rust upgrade failed${NC}"
        upgraded=1
    fi

    if _is_musl; then
        if command -v node >/dev/null 2>&1; then
            echo -e "${CYAN}  Upgrading Node.js...${NC}"
            _maybe_sudo apk upgrade nodejs npm 2>/dev/null || echo -e "${YELLOW}  Node.js upgrade failed${NC}"
            upgraded=1
        fi
    elif [ -s "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        if command -v nvm >/dev/null 2>&1; then
            echo -e "${CYAN}  Upgrading NVM...${NC}"
            retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o /tmp/nvm-install.sh" || echo -e "${YELLOW}  NVM download failed, skipping${NC}"
            if [ -f /tmp/nvm-install.sh ]; then
                bash /tmp/nvm-install.sh || echo -e "${YELLOW}  NVM upgrade failed${NC}"
                rm -f /tmp/nvm-install.sh
                . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
                echo -e "  ${GREEN}$(nvm --version 2>/dev/null)${NC}"
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
        uv self update || echo -e "${YELLOW}  uv upgrade failed${NC}"
        upgraded=1
    fi

    if command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Python...${NC}"
        if ! command -v uv >/dev/null 2>&1; then
            install_uv 2>/dev/null || true
        fi
        if command -v uv >/dev/null 2>&1; then
            uv python install --preview 2>/dev/null || uv python install latest 2>/dev/null || echo -e "${YELLOW}  uv python install failed, trying package manager${NC}"
            if uv python list 2>/dev/null | grep -q 'cpython'; then
                upgraded=1
            fi
        fi
        if [ $upgraded -eq 0 ]; then
            pkg_update >/dev/null 2>&1 || true
            local pm="$(get_pkg_manager)"
            case "$pm" in
                apt)  _maybe_sudo apt-get install -y python3 python3-pip python3-venv ;;
                apk)  _maybe_sudo apk upgrade python3 py3-pip ;;
                dnf)  _maybe_sudo dnf upgrade -y python3 python3-pip ;;
                pacman) _maybe_sudo pacman -Syu --noconfirm python python-pip ;;
                zypper) _maybe_sudo zypper update -y python3 python3-pip ;;
                brew) brew upgrade python ;;
            esac
        fi
        upgraded=1
    fi

    if command -v php >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading PHP...${NC}"
        pkg_update || echo -e "${YELLOW}  Package update failed${NC}"
        local php_pkgs="php-cli php-xml php-mbstring php-curl php-json"
        if command -v apk >/dev/null 2>&1; then php_pkgs="php-cli php-xml php-mbstring php-curl php-json composer"; fi
        pkg_install $php_pkgs || echo -e "${YELLOW}  PHP upgrade failed${NC}"
        upgraded=1
    fi

    if command -v tailscale >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading Tailscale...${NC}"
        if [ "$DETECTED_OS" = "macos" ]; then
            brew upgrade tailscale || echo -e "${YELLOW}  Tailscale upgrade failed${NC}"
        elif [ "$DETECTED_OS" = "linux" ]; then
            curl -fsSL https://tailscale.com/install.sh | sh || echo -e "${YELLOW}  Tailscale upgrade failed${NC}"
        fi
        upgraded=1
    fi

    if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading OpenCode...${NC}"
        npm upgrade -g opencode-ai || echo -e "${YELLOW}  OpenCode upgrade failed${NC}"
        upgraded=1
    fi

    if npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
        echo -e "${CYAN}  Upgrading GSD...${NC}"
        npx gsd-opencode@latest || echo -e "${YELLOW}  GSD upgrade failed${NC}"
        upgraded=1
    fi

    if command -v openchamber >/dev/null 2>&1 || npm list -g @openchamber/web >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading OpenChamber...${NC}"
        npm upgrade -g @openchamber/web || echo -e "${YELLOW}  OpenChamber upgrade failed${NC}"
        upgraded=1
    fi

    if [ $upgraded -eq 0 ]; then
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} No installed tools found to upgrade. Install tools first (option 4+).${NC}"
    else
        echo
        echo -e "${GREEN}  ✓ Upgrade complete${NC}"
    fi
}

# ──────────────
# 🔒 Option 17: Install Tailscale
# ──────────────
install_tailscale() {
    echo -e "${CYAN}${EMOJI_TAILSCALE}  ${BOLD}Install Tailscale${NC}"
    echo -e "${DIM}   Mesh VPN — connect devices across networks${NC}"
    echo

    if command -v tailscale >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Tailscale already installed: $(tailscale version 2>/dev/null | head -1)"
        return 0
    fi

    if [[ "$BATCH_MODE" != "1" ]]; then
        echo -e "${BYELLOW}  → This will install Tailscale${NC}"
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    echo -e "${CYAN}  Installing Tailscale...${NC}"

    if [ "$DETECTED_OS" = "macos" ]; then
        brew install tailscale || { echo -e "${RED}  ✗ Tailscale install failed${NC}"; return 1; }
    elif [ "$DETECTED_OS" = "linux" ]; then
        curl -fsSL https://tailscale.com/install.sh | sh || { echo -e "${RED}  ✗ Tailscale install failed${NC}"; return 1; }
    else
        echo -e "${YELLOW}  ⚠ Automatic install not supported on this OS.${NC}"
        echo -e "${DIM}    Visit https://tailscale.com/download to install manually.${NC}"
        return 1
    fi

    echo -e "${GREEN}  ✓ Tailscale installed${NC}"
    echo -e "${DIM}  Run \`tailscale up\` to connect, or \`tailscale login\` to authenticate${NC}"
}

remove_tailscale() {
    echo -e "${RED}➜ Remove Tailscale${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove Tailscale? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    if [ "$DETECTED_OS" = "macos" ]; then
        brew uninstall tailscale || { echo -e "${RED}  ✗ Tailscale removal failed${NC}"; return 1; }
    elif [ "$DETECTED_OS" = "linux" ]; then
        local pm="$(get_pkg_manager)"
        case "$pm" in
            apt)  _maybe_sudo apt-get remove -y tailscale ;;
            dnf)  _maybe_sudo dnf remove -y tailscale ;;
            pacman) _maybe_sudo pacman -Rns --noconfirm tailscale ;;
            apk)  _maybe_sudo apk del tailscale ;;
            zypper) _maybe_sudo zypper remove -y tailscale ;;
            *) echo -e "${YELLOW}  ⚠ Uninstall not supported for $pm${NC}"; return 1 ;;
        esac
    else
        echo -e "${YELLOW}  ⚠ Manual removal required on this OS${NC}"
        return 1
    fi

    echo -e "${GREEN}  ✓ Tailscale removed${NC}"
}

# ──────────────
# 🚀 Option 18: OpenCode + GSD
# ──────────────
install_opencode_gsd() {
    echo -e "${MAGENTA}${EMOJI_GSD}  ${BOLD}Install OpenCode + GSD (Rokicool) + OpenChamber${NC}"
    echo -e "${DIM}   AI-powered development environment${NC}"
    echo

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"

    local need_opencode=0 need_gsd=0 need_openchamber=0

    if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenCode already installed"
    else
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} OpenCode will be installed"
        need_opencode=1
    fi

    if command -v gsd-opencode >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} GSD already installed"
    elif npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} GSD already available"
    else
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} GSD will be installed"
        need_gsd=1
    fi

    if command -v openchamber >/dev/null 2>&1 || npm list -g @openchamber/web >/dev/null 2>&1; then
        echo -e "  ${GREEN}${EMOJI_CHECK}${NC} OpenChamber already installed"
    else
        echo -e "  ${YELLOW}${EMOJI_ARROW}${NC} OpenChamber will be installed"
        need_openchamber=1
    fi

    local install_errors=0

    if [[ $need_opencode -eq 0 && $need_gsd -eq 0 && $need_openchamber -eq 0 ]]; then
        echo
        echo -e "${GREEN}  ✓ All components already installed${NC}"
        return
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${YELLOW}  → Node.js required — installing first...${NC}"
        if _is_musl; then
            pkg_install nodejs npm || { echo -e "${RED}  ✗ Node.js install failed${NC}"; return 1; }
        else
            if ! command -v nvm >/dev/null 2>&1; then
                echo -e "${CYAN}  Installing NVM...${NC}"
                retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o /tmp/nvm-install.sh" || { echo -e "${RED}  ✗ NVM download failed${NC}"; return 1; }
                bash /tmp/nvm-install.sh || { echo -e "${RED}  ✗ NVM install failed${NC}"; return 1; }
                rm -f /tmp/nvm-install.sh
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
            fi
            nvm install --lts || { echo -e "${RED}  ✗ Node LTS install failed${NC}"; return 1; }
        fi
    fi

    command -v npm >/dev/null 2>&1 || { echo -e "  ${RED}${EMOJI_CROSS} npm missing - install Node LTS first (option 12)${NC}"; return; }

    if [[ "$BATCH_MODE" != "1" ]]; then
        echo -e "${BYELLOW}  → This will install the components marked above${NC}"
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    if [[ $need_openchamber -eq 1 ]]; then
        echo -e "${CYAN}  Installing build dependencies for native modules...${NC}"
        local pm="$(get_pkg_manager)"
        case "$pm" in
            apt)  pkg_install build-essential python3-dev make g++ >/dev/null 2>&1 || true ;;
            apk)  pkg_install alpine-sdk python3 make g++ >/dev/null 2>&1 || true ;;
            dnf)  pkg_install gcc-c++ python3-devel make >/dev/null 2>&1 || true ;;
            pacman) pkg_install base-devel python3 >/dev/null 2>&1 || true ;;
            zypper) pkg_install patterns-devel-base-devel_basis python3-devel >/dev/null 2>&1 || true ;;
            brew) brew install python3 >/dev/null 2>&1 || true ;;
        esac
        local py_ver
        py_ver=$(python3 -c 'import sys; v=sys.version_info; print(v.major*100+v.minor)' 2>/dev/null || echo "0")
        if [[ $py_ver -lt 308 ]]; then
            echo -e "${YELLOW}  Python 3.$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || echo '?') detected — node-gyp requires 3.8+${NC}"
            pkg_install python3.9 >/dev/null 2>&1 || pkg_install python3.8 >/dev/null 2>&1 || true
            if command -v python3.9 >/dev/null 2>&1; then
                export npm_config_python="$(command -v python3.9)"
            elif command -v python3.8 >/dev/null 2>&1; then
                export npm_config_python="$(command -v python3.8)"
            fi
        fi
        local py_ok=0
        if [[ -n "$npm_config_python" ]] && "$npm_config_python" -c 'import sys; assert sys.version_info >= (3,8)' 2>/dev/null; then
            py_ok=1
        elif python3 -c 'import sys; assert sys.version_info >= (3,8)' 2>/dev/null; then
            py_ok=1
        fi
        if [[ $py_ok -eq 0 ]]; then
            echo -e "${RED}  ✗ Python 3.8+ not available — skipping OpenChamber${NC}"
            echo -e "${DIM}    OpenChamber requires better-sqlite3 which needs node-gyp ≥ Python 3.8${NC}"
            need_openchamber=0
            install_errors=$((install_errors+1))
        fi
    fi

    if [[ $need_openchamber -eq 1 ]]; then
        local gcc_ok=0
        if command -v g++ >/dev/null 2>&1; then
            echo 'int main(){}' | g++ -std=gnu++20 -x c++ - -o /dev/null 2>/dev/null && gcc_ok=1
        fi
        if [[ $gcc_ok -eq 0 ]]; then
            echo -e "${YELLOW}  g++ does not support C++20 — trying to install newer compiler${NC}"
            case "$pm" in
                apt)
                    if ! grep -q 'buster-backports' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
                        echo "deb http://deb.debian.org/debian buster-backports main" | _maybe_sudo tee /etc/apt/sources.list.d/backports.list >/dev/null 2>&1
                        pkg_update >/dev/null 2>&1 || true
                    fi
                    _maybe_sudo apt-get -t buster-backports install -y g++-10 >/dev/null 2>&1 || true
                    if command -v g++-10 >/dev/null 2>&1; then
                        export CXX=g++-10 CC=gcc-10
                        echo -e "${GREEN}  ✓ Using g++-10 from backports${NC}"
                        gcc_ok=1
                    fi
                    ;;
                dnf)
                    _maybe_sudo dnf install -y gcc-toolset-10-gcc-c++ >/dev/null 2>&1 || true
                    if rpm -q gcc-toolset-10-gcc-c++ >/dev/null 2>&1; then
                        export CXX=g++-10 CC=gcc-10
                        gcc_ok=1
                    fi
                    ;;
            esac
            if [[ $gcc_ok -eq 0 ]]; then
                echo -e "${RED}  ✗ Compiler does not support C++20 — skipping OpenChamber${NC}"
                echo -e "${DIM}    better-sqlite3 requires C++20 support (GCC 10+ or Clang 10+)${NC}"
                echo -e "${DIM}    Install a newer g++ manually and retry${NC}"
                need_openchamber=0
                install_errors=$((install_errors+1))
            fi
        fi
    fi

    if [[ $need_opencode -eq 1 ]]; then
        echo -e "${CYAN}  Installing OpenCode...${NC}"
        retry_network 3 5 "curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh" || true
        if [ -f /tmp/opencode-install.sh ]; then
            bash /tmp/opencode-install.sh || npm i -g opencode-ai || { echo -e "${RED}  ✗ OpenCode install failed${NC}"; install_errors=$((install_errors+1)); }
            rm -f /tmp/opencode-install.sh
        else
            npm i -g opencode-ai || { echo -e "${RED}  ✗ OpenCode install failed${NC}"; install_errors=$((install_errors+1)); }
        fi
    fi

    if [[ $need_gsd -eq 1 ]]; then
        echo -e "${CYAN}  Installing GSD...${NC}"
        npx gsd-opencode@latest || { echo -e "${RED}  ✗ GSD install failed${NC}"; install_errors=$((install_errors+1)); }
    fi

    if [[ $need_openchamber -eq 1 ]]; then
        echo -e "${CYAN}  Installing OpenChamber...${NC}"
        npm i -g @openchamber/web || { echo -e "${RED}  ✗ OpenChamber install failed${NC}"; install_errors=$((install_errors+1)); }
    fi

    echo
    if [[ $install_errors -gt 0 ]]; then
        echo -e "${RED}  ✗ $install_errors component(s) failed to install${NC}"
    else
        echo -e "${GREEN}  ✓ All components installed successfully${NC}"
    fi
}

# ──────────────
# 🗑️ Option 18a: Remove OpenCode
# ──────────────
remove_opencode() {
    echo -e "${RED}🗑️  ${BOLD}Remove OpenCode + GSD + OpenChamber${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove all? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi
    npm uninstall -g opencode-ai @openchamber/web || { echo -e "${RED}  ✗ OpenCode/OpenChamber uninstall failed${NC}"; return 1; }
    if command -v gsd-opencode >/dev/null 2>&1; then
        gsd-opencode uninstall || echo -e "${YELLOW}  ⚠ GSD uninstall failed${NC}"
    fi
}

# ──────────────
# 🐘 Option 16: Install PHP + Laravel
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    local pkg_manager=$(get_pkg_manager)
    case "$pkg_manager" in
        apt)
            echo -e "${CYAN}  Installing PHP via apt...${NC}"
            _maybe_sudo apt-get update
            _maybe_sudo apt-get install -y php-cli php-xml php-mbstring php-curl php-json php-composer
            ;;
        apk)
            echo -e "${CYAN}  Installing PHP via apk...${NC}"
            _maybe_sudo apk update
            _maybe_sudo apk add php-cli php-xml php-mbstring php-curl php-json composer
            ;;
        brew)
            echo -e "${CYAN}  Installing PHP via Homebrew...${NC}"
            brew install php
            ;;
        dnf)
            _maybe_sudo dnf install -y php php-cli php-xml php-mbstring
            ;;
        pacman)
            _maybe_sudo pacman -S --noconfirm php
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
# 🗑️ Option 16a: Uninstall PHP + Laravel
# ──────────────
uninstall_php_laravel() {
    echo -e "${RED}🗑️  ${BOLD}Uninstall PHP + Laravel${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove PHP and Laravel? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    local pkg_manager=$(get_pkg_manager)
    case "$pkg_manager" in
        apt)
            _maybe_sudo apt-get remove -y php-cli php-xml php-mbstring php-curl php-json php-common 2>/dev/null || true
            _maybe_sudo apt-get autoremove -y
            ;;
        apk)
            _maybe_sudo apk del php-cli php-xml php-mbstring php-curl php-json composer 2>/dev/null || true
            ;;
        brew)
            brew uninstall php
            ;;
        dnf)
            _maybe_sudo dnf remove -y php php-cli php-xml php-mbstring
            ;;
        pacman)
            _maybe_sudo pacman -R --noconfirm php
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
    echo -e "${CYAN}://─────────────────────────────║${NC}"
    echo -e "${BOX_V} ${BOLD}${WHITE}Environment Setup Utility${NC}"
    echo -e "${CYAN}▉══════════════════════════${NC}"
    echo
    
    for i in "${!MENU_LABELS[@]}"; do
        local num=$((i + 1))
        local pad=""
        [[ $num -lt 10 ]] && pad=" "
        echo -e "${BOX_V} ${GREEN}${num})${pad} ${MENU_EMOJIS[$i]}  ${MENU_LABELS[$i]}"
    done
    echo
    echo -e "${DIM}  Enter your selected options, split by commas or spaces (1,2 3 4)${NC}"
    echo -e "${DIM}  Enter -N to remove (e.g. -3 removes Docker)${NC}"
    echo
    
    # ╭──────────────────────────────────────────╮
    # │        Footer                            │
    # ╰──────────────────────────────────────────╯
    echo -e "${CYAN}://─────────────────────────║${NC}"
    echo -e "${BOX_V}${DIM}  Press ${BOLD}u${NC}${DIM} to upgrade all${NC}"
    echo -e "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit${NC}"
    echo -e "${CYAN}▉══════════════════${NC}"
    
    echo -n -e "${BCYAN}▸ Choice: ${NC}"
}

parse_input() {
    PARSE_INSTALL_IDX=()
    PARSE_REMOVE_IDX=()
    local raw="$1"

    if [[ -z "$raw" || -z "${raw//[[:space:]]/}" ]]; then
        echo -e "${YELLOW}No selection made. Enter numbers (1-18) or 'q' to quit.${NC}"
        return 1
    fi

    local -a tokens
    read -ra tokens <<< "${raw//,/ }"

    if [[ ${#tokens[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No selection made. Enter numbers (1-18) or 'q' to quit.${NC}"
        return 1
    fi

    local -a candidates=()
    local -a errors=()
    local token
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^-?[1-9]$ ]] || [[ "$token" =~ ^-?1[0-8]$ ]]; then
            candidates+=("$token")
        else
            errors+=("$token")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        if [[ ${#errors[@]} -eq 1 ]]; then
            echo -e "${RED}Invalid: '${errors[0]}' is not a valid option (1-18)${NC}"
        else
            local error_str
            error_str=$(printf "'%s', " "${errors[@]}")
            error_str="${error_str%, }"
            echo -e "${RED}Invalid: ${error_str} are not valid options (1-18)${NC}"
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
                local clabel="${MENU_LABELS[$ridx]#Install }"
                clabel="${clabel#Create }"
                echo -e "${RED}Cannot both install and remove ${clabel}${NC}"
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
            local rlabel="${MENU_LABELS[$idx]#Install }"
            rlabel="${rlabel#Create }"
            echo -e "${RED}Cannot remove ${rlabel} — no remove operation available${NC}"
            return 1
        fi
    done

    PARSE_INSTALL_IDX=("${add_indices[@]}")
    PARSE_REMOVE_IDX=("${rm_indices[@]}")
    return 0
}

show_confirmation_screen() {
    local total=$(( ${#PARSE_INSTALL_IDX[@]} + ${#PARSE_REMOVE_IDX[@]} ))

    if [[ $total -eq 0 ]]; then
        return 1
    fi

    if [[ $total -eq 1 ]]; then
        return 0
    fi

    echo -e "${BOLD}${WHITE}Operations to execute:${NC}"

    local box_inner=54
    local border="${BOX_TL}"
    for ((i=0; i<box_inner; i++)); do border="${border}${BOX_H}"; done
    border="${border}${BOX_TR}"
    echo -e "${CYAN}${border}${NC}"

    local num=1
    for idx in "${PARSE_INSTALL_IDX[@]}"; do
        local label="${MENU_EMOJIS[$idx]}  ${MENU_LABELS[$idx]}"
        local padded="${label}                                                       "
        padded="${padded:0:$((box_inner - 5))}"
        echo -e "${BOX_V} ${GREEN}${num}) ${padded}${NC} ${BOX_V}"
        ((num++))
    done
    for idx in "${PARSE_REMOVE_IDX[@]}"; do
        local label="${MENU_EMOJIS[$idx]}  ${MENU_LABELS[$idx]}"
        local padded="${label}                                                       "
        padded="${padded:0:$((box_inner - 6))}"
        echo -e "${BOX_V} ${RED}-${num}) ${padded}${NC} ${BOX_V}"
        ((num++))
    done

    local bottom="${BOX_BL}"
    for ((i=0; i<box_inner; i++)); do bottom="${bottom}${BOX_H}"; done
    bottom="${bottom}${BOX_BR}"
    echo -e "${CYAN}${bottom}${NC}"

    echo -e "${YELLOW}Run ${total} operations? (y/n)${NC}"
    read -rp "  ▸ " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${DIM}  Cancelled.${NC}"
        return 1
    fi
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
        if parse_input "$choice"; then
            if show_confirmation_screen; then
                BATCH_MODE=1
                for idx in "${PARSE_INSTALL_IDX[@]}"; do
                    "${MENU_INSTALL_FN[$idx]}"
                done
                for idx in "${PARSE_REMOVE_IDX[@]}"; do
                    "${MENU_REMOVE_FN[$idx]}"
                done
                BATCH_MODE=0
            fi
        fi
    fi
    echo
    read -n1 -r -p "  Press any key to continue... " _
done
