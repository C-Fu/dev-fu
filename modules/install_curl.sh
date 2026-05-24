#!/usr/bin/env sh
# @name: Install curl
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Installs curl via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v curl >/dev/null 2>&1; then
    printf 'curl already installed: %s\n' "$(curl --version 2>/dev/null | head -1)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y curl ;;
    apk)    _maybe_sudo apk add curl ;;
    dnf)    _maybe_sudo dnf install -y curl ;;
    pacman) _maybe_sudo pacman -S --noconfirm curl ;;
    zypper) _maybe_sudo zypper install -y curl ;;
    *)      printf 'curl not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; exit 1 ;;
esac || { printf 'curl install failed\n' >&2; exit 1; }

printf 'curl installed successfully\n'
