#!/usr/bin/env sh
# @name: Install Zsh
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Installs Zsh shell via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v zsh >/dev/null 2>&1; then
    printf 'Zsh already installed: %s\n' "$(zsh --version 2>/dev/null)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y zsh ;;
    apk)    _maybe_sudo apk add zsh ;;
    dnf)    _maybe_sudo dnf install -y zsh ;;
    pacman) _maybe_sudo pacman -S --noconfirm zsh ;;
    zypper) _maybe_sudo zypper install -y zsh ;;
    brew)   brew install zsh ;;
    *)
        printf 'Zsh not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'Zsh install failed\n' >&2; exit 1; }

printf 'Zsh installed successfully\n'
