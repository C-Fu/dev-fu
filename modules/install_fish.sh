#!/usr/bin/env sh
# @name: Install Fish
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Installs Fish shell via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v fish >/dev/null 2>&1; then
    printf 'Fish already installed: %s\n' "$(fish --version 2>/dev/null)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y fish ;;
    apk)    _maybe_sudo apk add fish ;;
    dnf)    _maybe_sudo dnf install -y fish ;;
    pacman) _maybe_sudo pacman -S --noconfirm fish ;;
    zypper) _maybe_sudo zypper install -y fish ;;
    brew)   brew install fish ;;
    *)
        printf 'Fish not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'Fish install failed\n' >&2; exit 1; }

printf 'Fish installed successfully\n'
