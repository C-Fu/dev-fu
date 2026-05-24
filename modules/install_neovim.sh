#!/usr/bin/env sh
# @name: Install Neovim
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Installs Neovim via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v nvim >/dev/null 2>&1; then
    printf 'Neovim already installed: %s\n' "$(nvim --version 2>/dev/null | head -1)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y neovim ;;
    apk)    _maybe_sudo apk add neovim ;;
    dnf)    _maybe_sudo dnf install -y neovim ;;
    pacman) _maybe_sudo pacman -S --noconfirm neovim ;;
    zypper) _maybe_sudo zypper install -y neovim ;;
    brew)   brew install neovim ;;
    *)
        printf 'Neovim not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'Neovim install failed\n' >&2; exit 1; }

printf 'Neovim installed successfully\n'
