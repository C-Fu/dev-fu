#!/usr/bin/env sh
# @name: Remove Systemd-Resolved (LLMNR)
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Stops and disables systemd-resolved on Linux.

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
    fi
fi

_pkg_remove() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get remove -y "$@" ;;
        apk)    _maybe_sudo apk del "$@" ;;
        dnf)    _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -Rns --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

if [ "${FLU_OS:-linux}" = "darwin" ]; then
    printf 'macOS does not use systemd-resolved.\n'
    exit 0
fi

if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    if [ ! -f /usr/lib/systemd/systemd-resolved ]; then
        printf 'systemd-resolved is not installed — nothing to remove.\n'
        exit 0
    fi
fi

printf 'Removing systemd-resolved...\n'

_maybe_sudo systemctl stop systemd-resolved 2>/dev/null || true
_maybe_sudo systemctl disable systemd-resolved 2>/dev/null || true

case "${FLU_PKG_MGR:-apt}" in
    apk) printf 'Alpine does not use systemd-resolved\n'; exit 0 ;;
    *)   _pkg_remove systemd-resolved 2>/dev/null || true ;;
esac

printf 'systemd-resolved removed successfully.\n'
