#!/usr/bin/env sh
# @name: Install VS Code
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 300
#
# Installs Visual Studio Code via the system package manager or direct download.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

# Auto-detect package manager when not provided by flu.sh
if [ -z "${FLU_PKG_MGR:-}" ]; then
    if      command -v apt-get >/dev/null 2>&1; then FLU_PKG_MGR="apt"
    elif    command -v apk     >/dev/null 2>&1; then FLU_PKG_MGR="apk"
    elif    command -v dnf     >/dev/null 2>&1; then FLU_PKG_MGR="dnf"
    elif    command -v pacman  >/dev/null 2>&1; then FLU_PKG_MGR="pacman"
    elif    command -v zypper  >/dev/null 2>&1; then FLU_PKG_MGR="zypper"
    elif    command -v brew    >/dev/null 2>&1; then FLU_PKG_MGR="brew"
    fi
fi

if command -v code >/dev/null 2>&1; then
    printf 'VS Code already installed\n'
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)
        _maybe_sudo apt-get update
        _maybe_sudo apt-get install -y wget gpg apt-transport-https
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | _maybe_sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null
        _maybe_sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        _maybe_sudo apt-get update
        _maybe_sudo apt-get install -y code || { printf 'VS Code install failed\n' >&2; exit 1; }
        ;;
    dnf)
        _maybe_sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        _maybe_sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        _maybe_sudo dnf install -y code || { printf 'VS Code install failed\n' >&2; exit 1; }
        ;;
    pacman)
        _maybe_sudo pacman -S --noconfirm code || { printf 'VS Code install failed\n' >&2; exit 1; }
        ;;
    zypper)
        _maybe_sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        _maybe_sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode
        _maybe_sudo zypper refresh
        _maybe_sudo zypper install -y code || { printf 'VS Code install failed\n' >&2; exit 1; }
        ;;
    apk)
        printf 'VS Code is not available via apk. Install from: https://code.visualstudio.com/download\n' >&2
        exit 1
        ;;
    brew)
        brew install --cask visual-studio-code || { printf 'VS Code install failed\n' >&2; exit 1; }
        ;;
    *)
        printf 'VS Code not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac

printf 'VS Code installed successfully\n'
