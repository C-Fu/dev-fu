#!/usr/bin/env sh
# @name: Remove Yarn
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Yarn package manager via npm uninstall and package manager removal.

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

if ! command -v yarn >/dev/null 2>&1; then
    printf 'Yarn is not installed\n'
    exit 0
fi

printf 'Removing Yarn...\n'

# Remove via npm first
if command -v npm >/dev/null 2>&1; then
    npm uninstall -g yarn 2>/dev/null || true
fi

# Also remove via package manager as fallback
case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_remove yarn 2>/dev/null || true ;;
    apk)    _pkg_remove yarn 2>/dev/null || true ;;
    dnf)    _pkg_remove yarnpkg 2>/dev/null || true ;;
    pacman) _pkg_remove yarn 2>/dev/null || true ;;
    zypper) _pkg_remove yarn 2>/dev/null || true ;;
    brew)   brew uninstall yarn 2>/dev/null || true ;;
esac

printf 'Yarn removed successfully\n'
