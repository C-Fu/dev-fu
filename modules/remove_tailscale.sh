#!/usr/bin/env sh
# @name: Remove Tailscale
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Tailscale (mesh VPN) — disconnects, removes via package manager,
# and cleans data directories.

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

_pkg_remove() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get remove -y "$@" ;;
        apk)    _maybe_sudo apk del "$@" ;;
        dnf)    _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -R --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew)   brew uninstall "$@" || true ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

if ! command -v tailscale >/dev/null 2>&1; then
    printf 'Tailscale is not installed\n'
    exit 0
fi

printf 'Removing Tailscale...\n'

# Disconnect Tailscale first
_maybe_sudo tailscale down 2>/dev/null || true

# Remove via package manager
if [ "${FLU_OS:-}" = "darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
        brew uninstall tailscale 2>/dev/null || true
    fi
else
    _pkg_remove tailscale 2>/dev/null || true
fi

# Clean Tailscale data
_maybe_sudo rm -rf /var/lib/tailscale 2>/dev/null || true

printf 'Tailscale removed successfully\n'
