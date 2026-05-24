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
