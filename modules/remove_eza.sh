#!/usr/bin/env sh
# @name: Remove eza
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes eza via package manager and/or cargo uninstall.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

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

if ! command -v eza >/dev/null 2>&1; then
    printf 'eza is not installed\n'
    exit 0
fi

printf 'Removing eza...\n'

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        brew uninstall eza 2>/dev/null || true
        ;;
    linux|Linux)
        _pkg_remove eza 2>/dev/null || true
        command -v cargo >/dev/null 2>&1 && cargo uninstall eza 2>/dev/null || true
        _maybe_sudo rm -f /usr/local/bin/eza 2>/dev/null || true
        rm -f "$HOME/.cargo/bin/eza" 2>/dev/null || true
        ;;
esac

printf 'eza removed successfully\n'
