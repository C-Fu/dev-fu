#!/usr/bin/env bash
# ============================================================
# Title: setup-fu.sh
# Author: C-Fu
# Description: This script prepares the OS/environment to setup
#              and configure a basic dev environment for
#              Docker, Go, Rust, Node, Bun, Python.
# Compatibility: WSL2, Linux (and LXC), ZSH in MacOS
# For Miiii and U
# ============================================================

# -------------------------
# Colors and Emojis
# -------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

EMOJI_DOCKER="🐳"
EMOJI_PROMPT="✨"
EMOJI_STATUS="🔍"
EMOJI_DEV="🛠️"
EMOJI_GSD="🚀"
EMOJI_GO="🐹"

# -------------------------
# Helpers
# -------------------------
detect_rc_file() { [[ -n "$ZSH_VERSION" ]] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc"; }
append_rc_if_missing() { local rc="$1"; local line="$2"; grep -F -- "$line" "$rc" >/dev/null 2>&1 || printf "%s\n" "$line" >> "$rc"; }

# -------------------------
# Option 1: Install Docker
# -------------------------
install_docker() {
    echo -e "${BLUE}${EMOJI_DOCKER}  Install Docker${NC}"
    read -rp "Proceed to install Docker? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return
    if command -v docker >/dev/null 2>&1; then
        echo "✔ Docker already installed: $(docker --version)"
        return
    fi
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    echo "Docker install finished."
}

# -------------------------
# Option 2: Fancy Prompt
# -------------------------
create_fancy_prompt() {
    local rc_file=$(detect_rc_file)
    local target="$HOME/.fancy-prompt.sh"
    local url="https://raw.githubusercontent.com/jonathan-scholbach/fancy-prompt/refs/heads/master/prompt.sh"

    echo -e "${GREEN}${EMOJI_PROMPT}  Create Fancy Prompt${NC}"
    read -rp "Replace current fancy prompt with remote script? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return

    curl -fsSL "$url" -o "$target" || { echo "Download failed."; return; }
    chmod +x "$target"
    append_rc_if_missing "$rc_file" "source ~/.fancy-prompt.sh"
    source "$target" 2>/dev/null || true
    source "$rc_file" 2>/dev/null || true
    echo "Fancy prompt replaced and sourced."
}

remove_fancy_prompt() {
    local rc_file=$(detect_rc_file)
    echo -e "${RED}   2a) Remove Fancy Prompt${NC}"
    read -rp "Remove fancy prompt? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return
    rm -f "$HOME/.fancy-prompt.sh"
    sed -i.bak '/source ~\/.fancy-prompt.sh/d' "$rc_file"
    unset PROMPT_COMMAND
    export PS1="\u@\h:\w\$ "
    source "$rc_file" 2>/dev/null || true
    echo "Fancy prompt removed."
}

# -------------------------
# Option 4: Status Check
# -------------------------
status_check() {
    echo -e "${YELLOW}${EMOJI_STATUS}  Status Check${NC}"
    echo ">>> Checking developer tools and packages..."

    check_cmd_version() {
        local name="$1"; local cmd="$2"; local flag="$3"
        if command -v "$cmd" >/dev/null 2>&1; then
            ver=$($cmd $flag 2>/dev/null | head -n1)
            printf "✔ %-12s : %s\n" "$name" "$ver"
        else
            printf "✘ %-12s : NOT installed\n" "$name"
        fi
    }

    [[ -s "$HOME/.nvm/nvm.sh" ]] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    check_cmd_version "Docker" "docker" "--version"
    check_cmd_version "Go" "go" "version"
    check_cmd_version "Rustc" "rustc" "--version"
    check_cmd_version "Cargo" "cargo" "--version"
    check_cmd_version "Rustup" "rustup" "--version"
    check_cmd_version "Bun" "bun" "--version"
    check_cmd_version "Unzip" "unzip" "-v"
    if command -v nvm >/dev/null 2>&1; then
        echo "✔ NVM installed: $(nvm --version)"
    else
        echo "✘ NVM NOT installed"
    fi
    check_cmd_version "Node.js" "node" "--version"
    check_cmd_version "Python" "python3" "--version"
    check_cmd_version "pip" "pip3" "--version"
    check_cmd_version "pipx" "pipx" "--version"
    check_cmd_version "uv" "uv" "--version"

#    echo ">>> Checking OpenCode + GSD..."
    if command -v opencode >/dev/null 2>&1; then
        echo "✔ OpenCode detected: $(opencode --version 2>/dev/null || echo 'version unknown')"
    elif npm list -g opencode-ai >/dev/null 2>&1; then
        echo "✔ OpenCode installed (npm global)"
    else
        echo "✘ OpenCode NOT installed"
    fi

# --- GSD detection ---
if command -v gsd-opencode >/dev/null 2>&1; then
    echo "✔ GSD detected (global)"
elif npx --yes gsd-opencode --version >/dev/null 2>&1; then
    echo "✔ GSD available via npx"
else
    echo "✘ GSD NOT available"
fi
    echo ">>> Status check complete."
}

# -------------------------
# Option 5: Install Dev Tools
# -------------------------
install_dev_tools() {
    echo -e "${BLUE}${EMOJI_DEV}  Install Dev Tools (Go, Rust, Bun, Node LTS, Python)${NC}"
    read -rp "Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return

    sudo apt-get update
    sudo apt-get install -y unzip golang-go python3 python3-pip python3-venv pipx

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"

    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts

    pipx install uv
    echo "Dev tools installation complete."
}

# -------------------------
# Option 5a: Uninstall Dev Tool
# -------------------------
uninstall_dev_tool() {
    echo -e "${RED}   5a) Uninstall Dev Tool${NC}"
    read -rp "Enter tool to uninstall (rust, node, bun, python, go, pipx, uv): " tool
    case "$tool" in
        rust) rustup self uninstall -y ;;
        node) nvm uninstall --lts ;;
        bun) rm -rf ~/.bun ;;
        python) sudo apt-get remove -y python3 python3-pip python3-venv ;;
        go) sudo apt-get remove -y golang-go ;;
        pipx) sudo apt-get remove -y pipx ;;
        uv) pipx uninstall uv ;;
        *) echo "Unknown tool." ;;
    esac
}

# -------------------------
# Option 6: OpenCode + GSD
# -------------------------
install_opencode_gsd() {
    echo -e "${BLUE}${EMOJI_GSD}  Install OpenCode and Get-Shit-Done${NC}"
    read -rp "Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    command -v nvm >/dev/null || { echo "NVM missing."; return; }
    command -v node >/dev/null || { echo "Node missing."; return; }

    # Install OpenCode
    curl -fsSL https://opencode.ai/install | bash || npm i -g opencode-ai

    # Install GSD
    npx gsd-opencode@latest

    # Disable mouse reporting permanently
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
    append_rc_if_missing "$(detect_rc_file)" "printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'"
    echo "OpenCode + GSD installed."
}

# -------------------------
# Option 6a: Remove OpenCode
# -------------------------
remove_opencode() {
    echo -e "${RED}   6a) Remove OpenCode${NC}"
    read -rp "Remove OpenCode (global npm package)? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return
    npm uninstall -g opencode-ai || echo "OpenCode not found."
}

# -------------------------
# Option 6b: Remove GSD
# -------------------------
remove_gsd() {
    echo -e "${RED}   6b) Remove GSD${NC}"
    read -rp "Remove GSD using gsd-opencode uninstall? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo "Cancelled." && return
    gsd-opencode uninstall || echo
}

# -------------------------
# Menu display
# -------------------------
show_menu() {
    clear
    echo "=============================================="
    echo "   setup-fu.sh — environment setup utility     "
    echo "=============================================="
    echo -e "1) ${EMOJI_DOCKER}  Install Docker"
    echo -e "2) ${EMOJI_PROMPT}  Create Fancy Prompt"
    echo -e "   ${RED}2a) Remove Fancy Prompt${NC}"
    echo -e "4) ${EMOJI_STATUS}  Status Check (Docker, Go, Rust, Node, Python, Bun, etc.)"
    echo -e "5) ${EMOJI_DEV}  Install Dev Tools (Go, Rust, Bun, Node LTS, Python)"
    echo -e "   ${RED}5a) Uninstall Dev Tool${NC}"
    echo -e "6) ${EMOJI_GSD}  Install OpenCode and Get-Shit-Done"
    echo -e "   ${RED}6a) Remove OpenCode${NC}"
    echo -e "   ${RED}6b) Remove GSD${NC}"
    echo -e "q) Quit"
    echo "----------------------------------------------"
    echo -n "Choose an option: "
}

# -------------------------
# Main loop
# -------------------------
while true; do
    show_menu
    read -r choice
    case "$choice" in
        1) install_docker ;;
        2) create_fancy_prompt ;;
        2a) remove_fancy_prompt ;;
        4) status_check ;;
        5) install_dev_tools ;;
        5a) uninstall_dev_tool ;;
        6) install_opencode_gsd ;;
        6a) remove_opencode ;;
        6b) remove_gsd ;;
        q|Q) echo "Goodbye — stay productive!"; break ;;
        *) echo "Invalid choice, try again." ;;
    esac
    echo
    read -n1 -r -p "Press any key to return to menu..." _
done
