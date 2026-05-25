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
        sudo -n "$@" 2>/dev/null || { printf 'sudo password required\n' >&2; return 1; }
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
