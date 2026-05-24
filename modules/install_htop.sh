#!/usr/bin/env sh
# @name: Install htop
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Installs htop system monitor via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v htop >/dev/null 2>&1; then
    printf 'htop already installed\n'
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y htop ;;
    apk)    _maybe_sudo apk add htop ;;
    dnf)    _maybe_sudo dnf install -y htop ;;
    pacman) _maybe_sudo pacman -S --noconfirm htop ;;
    zypper) _maybe_sudo zypper install -y htop ;;
    brew)   brew install htop ;;
    *)
        printf 'htop not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'htop install failed\n' >&2; exit 1; }

printf 'htop installed successfully\n'
