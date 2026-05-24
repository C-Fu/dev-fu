#!/usr/bin/env sh
# @name: Install wget
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Installs wget via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v wget >/dev/null 2>&1; then
    printf 'wget already installed: %s\n' "$(wget --version 2>/dev/null | head -1)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y wget ;;
    apk)    _maybe_sudo apk add wget ;;
    dnf)    _maybe_sudo dnf install -y wget ;;
    pacman) _maybe_sudo pacman -S --noconfirm wget ;;
    zypper) _maybe_sudo zypper install -y wget ;;
    brew)   brew install wget ;;
    *)      printf 'wget not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; exit 1 ;;
esac || { printf 'wget install failed\n' >&2; exit 1; }

printf 'wget installed successfully\n'
