#!/usr/bin/env sh
# @name: Install btop
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Installs btop resource monitor via the system package manager.

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

if command -v btop >/dev/null 2>&1; then
    printf 'btop already installed\n'
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y btop ;;
    apk)    _maybe_sudo apk add btop ;;
    dnf)    _maybe_sudo dnf install -y btop ;;
    pacman) _maybe_sudo pacman -S --noconfirm btop ;;
    zypper) _maybe_sudo zypper install -y btop ;;
    brew)   brew install btop ;;
    *)
        printf 'btop not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'btop install failed\n' >&2; exit 1; }

printf 'btop installed successfully\n'
