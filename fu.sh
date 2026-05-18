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

MENU_LABELS=(
    "Status Check"
    "Compare With Latest"
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
MENU_EMOJIS=("$EMOJI_STATUS" "$EMOJI_COMPARE" "$EMOJI_UPGRADE" "$EMOJI_DOCKER" "$EMOJI_PROMPT" "$EMOJI_NETWORK" "$EMOJI_GO" "$EMOJI_RUST" "$EMOJI_PYTHON" "$EMOJI_NODE" "$EMOJI_BUN" "$EMOJI_SPARKLE" "$EMOJI_MOUSE" "$EMOJI_PHP" "$EMOJI_GSD")
MENU_INSTALL_FN=("status_check" "status_check_compare" "upgrade_all" "install_docker" "create_fancy_prompt" "install_avahi" "install_go" "install_rust" "install_python" "install_nvm_node" "install_bun" "install_yarn" "disable_mouse_reporting" "install_php_laravel" "install_opencode_gsd")
MENU_REMOVE_FN=("" "" "" "remove_docker" "remove_fancy_prompt" "remove_avahi" "remove_go" "remove_rust" "remove_python" "remove_nvm_node" "remove_bun" "remove_yarn" "enable_mouse_reporting" "uninstall_php_laravel" "remove_opencode")
MENU_SINGLE_SELECT=(0 0 0 0 0 1 0 0 0 0 0 0 0 0 1)
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
        apt)  sudo apt-get update ;;
        apk)  sudo apk update ;;
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
        apk)  sudo apk add "$@" ;;
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
        apk)  sudo apk del "$@" ;;
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
        apk)  sudo apk del --purge "$@" ;;
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
        apk)  sudo apk autoremove ;;
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
    if [ "$DETECTED_ENV" = "termux" ]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        die "sudo is required but not available. Run from a user with sudo privileges." 1
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
# 🐳 Option 4: Install Docker
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
    retry_network 3 5 "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh" || die "Docker download failed" 1
    sudo sh /tmp/get-docker.sh || die "Docker install failed" 1
    rm -f /tmp/get-docker.sh
    
    echo -e "${GREEN}  ✓ Docker installed successfully${NC}"
}

# 🗑️ Option 4a: Remove Docker
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
    pkg_purge docker.io docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    sudo rm -rf /var/lib/docker /etc/docker
    sudo rm -f /etc/apt/sources.list.d/docker.list
    pkg_update || true
    
    echo -e "${GREEN}  ✓ Docker removed successfully${NC}"
}

# 🌐 Option 6: Install Linux Hostname Discovery (avahi-daemon + systemd-resolved)
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
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

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

# 🗑️ Option 6a: Remove Hostname Discovery (Avahi + systemd-resolved)
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
# ✨ Option 5: Fancy Prompt
# ──────────────
create_fancy_prompt() {
    echo -e "${MAGENTA}${EMOJI_PROMPT}  ${BOLD}Create Fancy Prompt${NC}"
    echo
    
    local rc_file=$(detect_rc_file)
    local target="$HOME/.fancy-prompt.sh"
    local url="https://raw.githubusercontent.com/jonathan-scholbach/fancy-prompt/refs/heads/master/prompt.sh"

    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Replace current fancy prompt? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    retry_network 3 5 "curl -fsSL '$url' -o '$target'" || die "Download failed" 1
    chmod +x "$target"
    append_rc_if_missing "$rc_file" "source ~/.fancy-prompt.sh"
    source "$target" 2>/dev/null || true
    source "$rc_file" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Fancy prompt replaced${NC}"
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
                ver=$(timeout 5 $cmd $flag 2>/dev/null | head -n1 | tr -s ' ')
            else
                ver=$($cmd $flag 2>/dev/null | head -n1 | tr -s ' ')
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
        printf "  ${GREEN}${EMOJI_CHECK}${NC} %-12s : ${GREEN}%s${NC}\n" "GSD" "$gsd_version"
    else
        printf "  ${RED}${EMOJI_CROSS}${NC} %-12s : ${RED}NOT installed${NC}\n" "GSD"
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
        local tag
        tag=$(curl -fsSL --max-time 5 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
            | grep '"tag_name"' | head -1 \
            | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        tag="${tag#v}"
        tag="${tag#bun-v}"
        tag="${tag#php-}"
        echo "$tag"
    }

    _scc_local() {
        local cmd="$1" flag="$2"
        if command -v "$cmd" >/dev/null 2>&1; then
            if command -v timeout >/dev/null 2>&1; then
                timeout 5 "$cmd" $flag 2>/dev/null | head -n1
            else
                "$cmd" $flag 2>/dev/null | head -n1
            fi
        fi
    }

    _scc_ver() {
        echo "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?([._-]?[a-zA-Z0-9]+)*' | head -1
    }

    _scc_row() {
        local name="$1" local_raw="$2" latest="$3"
        local local_ver="" lat="${latest:---}"

        if [[ -z "$local_raw" ]]; then
            printf "  %-13s \033[2m%-22s\033[0m %-16s " "$name" "not installed" "$lat"
            echo -e "${DIM}—${NC}"
            return
        fi

        local_ver=$(_scc_ver "$local_raw")
        printf "  %-13s %-22s %-16s " "$name" "$local_ver" "$lat"

        if [[ -z "$latest" ]]; then
            echo -e "${DIM}?${NC}"
        elif [[ -z "$local_ver" ]]; then
            echo -e "${DIM}?${NC}"
        elif [[ "$local_ver" == "$latest" ]]; then
            echo -e "${GREEN}✓ up to date${NC}"
        else
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
    [[ -s "$HOME/.nvm/nvm.sh" ]] && nvm_local="nvm $(source "$HOME/.nvm/nvm.sh" 2>/dev/null && nvm --version)"
    _scc_row "NVM"      "$nvm_local"                       "$(_scc_gh nvm-sh/nvm)"

    _scc_row "Node.js"  "$(_scc_local node --version)"     "$(curl -fsSL --max-time 5 'https://nodejs.org/dist/index.json' 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/')"
    _scc_row "Python"   "$(_scc_local python3 --version)"  "$(_scc_gh python/cpython)"
    _scc_row "uv"       "$(_scc_local uv --version)"       "$(_scc_gh astral-sh/uv)"
    _scc_row "PHP"      "$(_scc_local php -v)"             "$(_scc_gh php/php-src)"

    local yarn_latest=""
    command -v npm >/dev/null 2>&1 && yarn_latest=$(npm view yarn version 2>/dev/null)
    _scc_row "Yarn"     "$(_scc_local yarn --version)"     "$yarn_latest"

    _scc_row "Composer" "$(_scc_local composer --version)" "$(_scc_gh composer/composer)"
    _scc_row "OpenCode" "$(_scc_local opencode --version)" "$(_scc_gh anomalyco/opencode)"

    local oc_local=""
    command -v openchamber >/dev/null 2>&1 && oc_local=$(timeout 5 openchamber --version 2>/dev/null | head -n1)
    local oc_latest=""
    command -v npm >/dev/null 2>&1 && oc_latest=$(npm view @openchamber/web version 2>/dev/null)
    _scc_row "OpenChamber" "$oc_local" "$oc_latest"

    local gsd_local=""
    command -v gsd-opencode >/dev/null 2>&1 && gsd_local=$(timeout 5 gsd-opencode --version 2>/dev/null | head -n1)
    local gsd_latest=""
    command -v npm >/dev/null 2>&1 && gsd_latest=$(npm view gsd-opencode version 2>/dev/null)
    _scc_row "GSD"      "$gsd_local"                       "$gsd_latest"

    echo -e "  $(printf '%.0s─' {1..70})"
    echo
    echo -e "${GREEN}  ✓ Comparison complete${NC}"
}

# ──────────────
# 🛠️ Option 7: Install Dev Tools
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
    pkg_update || die "package update failed" $?
    local go_pkg="golang-go"
    if command -v apk >/dev/null 2>&1; then go_pkg="go"; fi
    pkg_install $go_pkg || die "Go install failed" $?

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
    pkg_remove $go_pkg || die "Go removal failed" $?
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

    retry_network 3 5 "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh" || die "Rust download failed" 1
    sh /tmp/rustup.sh -y || die "Rust install failed" 1
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

    rustup self uninstall -y || die "Rust uninstall failed" $?
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
    pkg_update || die "package update failed" $?

    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Python + pip...${NC}"
        if command -v apk >/dev/null 2>&1; then
            pkg_install python3 py3-pip || die "Python install failed" $?
        else
            pkg_install python3 python3-pip python3-venv || die "Python install failed" $?
        fi
    fi

    if ! command -v pipx >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing pipx...${NC}"
        if command -v apk >/dev/null 2>&1; then
            pkg_install py3-pipx || die "pipx install failed" $?
        else
            pkg_install pipx || die "pipx install failed" $?
        fi
    fi

    if ! command -v uv >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing uv...${NC}"
        retry_network 3 5 "curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh" || die "uv download failed" 1
        sh /tmp/uv-install.sh || die "uv install failed" 1
        rm -f /tmp/uv-install.sh
        export PATH="$HOME/.local/bin:$PATH"
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

install_nvm_node() {
    echo -e "${CYAN}${EMOJI_NODE}  ${BOLD}Install NVM + Node LTS${NC}"
    echo -e "${DIM}   Node Version Manager with latest LTS${NC}"
    echo

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
        retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh -o /tmp/nvm-install.sh" || die "NVM download failed" 1
        bash /tmp/nvm-install.sh || die "NVM install failed" 1
        rm -f /tmp/nvm-install.sh
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${CYAN}  Installing Node.js LTS...${NC}"
        nvm install --lts || die "Node LTS install failed" 1
    fi

    echo -e "${GREEN}  ✓ NVM + Node LTS installed successfully${NC}"
}

remove_nvm_node() {
    echo -e "${RED}🗑️  ${BOLD}Remove NVM + Node${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove NVM and Node.js? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
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

    retry_network 3 5 "curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh" || die "Bun download failed" 1
    bash /tmp/bun-install.sh || die "Bun install failed" 1
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
    command -v npm >/dev/null 2>&1 || { echo -e "  ${RED}${EMOJI_CROSS} npm missing - install NVM + Node LTS first (option 10)${NC}"; return; }

    echo -e "${BYELLOW}  → This will install: Yarn${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Proceed? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi

    npm install -g yarn || die "Yarn install failed" 1

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
    echo -e "${CYAN}${EMOJI_SPARKLE}  ${BOLD}Disable Mouse Reporting in Terminal${NC}"
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
                apt)  sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
                apk)  sudo apk upgrade docker ;;
                dnf)  sudo dnf upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin ;;
                pacman) sudo pacman -Syu --noconfirm docker ;;
                zypper) sudo zypper update -y docker ;;
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

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        if command -v nvm >/dev/null 2>&1; then
            echo -e "${CYAN}  Upgrading NVM...${NC}"
            retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh -o /tmp/nvm-install.sh" || echo -e "${YELLOW}  NVM download failed, skipping${NC}"
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
        local php_pkgs="php-cli php-xml php-mbstring php-curl php-json"
        if command -v apk >/dev/null 2>&1; then php_pkgs="php-cli php-xml php-mbstring php-curl php-json composer"; fi
        pkg_install $php_pkgs || echo -e "${YELLOW}  PHP upgrade failed${NC}"
        upgraded=1
    fi

    if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
        echo -e "${CYAN}  Upgrading OpenCode...${NC}"
        npm upgrade -g opencode-ai || echo -e "${YELLOW}  OpenCode upgrade failed${NC}"
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
# 🚀 Option 15: OpenCode + GSD
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

    if [[ $need_opencode -eq 0 && $need_gsd -eq 0 && $need_openchamber -eq 0 ]]; then
        echo
        echo -e "${GREEN}  ✓ All components already installed${NC}"
        return
    fi

    if ! command -v nvm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
        echo -e "${YELLOW}  → NVM + Node required — installing first...${NC}"
        if ! command -v nvm >/dev/null 2>&1; then
            echo -e "${CYAN}  Installing NVM...${NC}"
            retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh -o /tmp/nvm-install.sh" || die "NVM download failed" 1
            bash /tmp/nvm-install.sh || die "NVM install failed" 1
            rm -f /tmp/nvm-install.sh
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        fi
        if ! command -v node >/dev/null 2>&1; then
            echo -e "${CYAN}  Installing Node.js LTS...${NC}"
            nvm install --lts || die "Node LTS install failed" 1
        fi
    fi

    command -v npm >/dev/null 2>&1 || { echo -e "  ${RED}${EMOJI_CROSS} npm missing - install NVM + Node LTS first (option 10)${NC}"; return; }

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
        fi
    fi

    if [[ $need_opencode -eq 1 ]]; then
        echo -e "${CYAN}  Installing OpenCode...${NC}"
        retry_network 3 5 "curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh" || true
        if [ -f /tmp/opencode-install.sh ]; then
            bash /tmp/opencode-install.sh || npm i -g opencode-ai || die "OpenCode install failed" 1
            rm -f /tmp/opencode-install.sh
        else
            npm i -g opencode-ai || die "OpenCode install failed" 1
        fi
    fi

    if [[ $need_gsd -eq 1 ]]; then
        echo -e "${CYAN}  Installing GSD...${NC}"
        npx gsd-opencode@latest || die "GSD install failed" 1
    fi

    if [[ $need_openchamber -eq 1 ]]; then
        echo -e "${CYAN}  Installing OpenChamber...${NC}"
        npm i -g @openchamber/web || echo -e "${RED}  ✗ OpenChamber install failed${NC}"
    fi

    echo
    echo -e "${GREEN}  ✓ All components installed successfully${NC}"
}

# ──────────────
# 🗑️ Option 15a: Remove OpenCode
# ──────────────
remove_opencode() {
    echo -e "${RED}🗑️  ${BOLD}Remove OpenCode${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove OpenCode? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi
    npm uninstall -g opencode-ai @openchamber/web || die "OpenCode uninstall failed" $?
}

# ──────────────
# 🗑️ Option 15b: Remove GSD
# ──────────────
remove_gsd() {
    echo -e "${RED}🗑️  ${BOLD}Remove GSD${NC}"
    if [[ "$BATCH_MODE" != "1" ]]; then
        read -rp "  Remove GSD? (y/n): " confirm
        [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
    fi
    if command -v gsd-opencode >/dev/null 2>&1; then
        gsd-opencode uninstall || die "GSD uninstall failed" $?
    else
        echo -e "  ${YELLOW}GSD not found${NC}"
    fi
}

# ──────────────
# 🐘 Option 14: Install PHP + Laravel
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
            sudo apt-get update
            sudo apt-get install -y php-cli php-xml php-mbstring php-curl php-json php-composer
            ;;
        apk)
            echo -e "${CYAN}  Installing PHP via apk...${NC}"
            sudo apk update
            sudo apk add php-cli php-xml php-mbstring php-curl php-json composer
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
# 🗑️ Option 14a: Uninstall PHP + Laravel
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
            sudo apt-get remove -y php-cli php-xml php-mbstring php-curl php-json php-common 2>/dev/null || true
            sudo apt-get autoremove -y
            ;;
        apk)
            sudo apk del php-cli php-xml php-mbstring php-curl php-json composer 2>/dev/null || true
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
    echo -e "${BOX_V}${DIM}  Press ${BOLD}q${NC}${DIM} to quit${NC}"
    echo -e "${CYAN}▉══════════════════${NC}"
    
    echo -n -e "${BCYAN}▸ Choice: ${NC}"
}

parse_input() {
    PARSE_INSTALL_IDX=()
    PARSE_REMOVE_IDX=()
    local raw="$1"

    if [[ -z "$raw" || -z "${raw//[[:space:]]/}" ]]; then
        echo -e "${YELLOW}No selection made. Enter numbers (1-15) or 'q' to quit.${NC}"
        return 1
    fi

    local -a tokens
    read -ra tokens <<< "${raw//,/ }"

    if [[ ${#tokens[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No selection made. Enter numbers (1-15) or 'q' to quit.${NC}"
        return 1
    fi

    local -a candidates=()
    local -a errors=()
    local token
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^-?[1-9]$ ]] || [[ "$token" =~ ^-?1[0-5]$ ]]; then
            candidates+=("$token")
        else
            errors+=("$token")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        if [[ ${#errors[@]} -eq 1 ]]; then
            echo -e "${RED}Invalid: '${errors[0]}' is not a valid option (1-15)${NC}"
        else
            local error_str
            error_str=$(printf "'%s', " "${errors[@]}")
            error_str="${error_str%, }"
            echo -e "${RED}Invalid: ${error_str} are not valid options (1-15)${NC}"
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
