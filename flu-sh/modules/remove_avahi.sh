#!/usr/bin/env sh
# @name: Remove Avahi Daemon (mDNS)
# @params:
# @platforms: linux, darwin
# @version: 1.1.0
# @deps:
# @timeout: 120
#
# Removes Avahi Daemon on Linux.
# On macOS, Bonjour is built-in and cannot be removed.

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

_pkg_remove() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get remove -y "$@" ;;
        apk)    _maybe_sudo apk del "$@" ;;
        dnf)    _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -Rns --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew)   brew uninstall "$@" ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

# macOS: Bonjour cannot be removed
if [ "${FLU_OS:-linux}" = "darwin" ]; then
    printf 'Bonjour (mDNSResponder) is built into macOS and cannot be removed.\n'
    exit 0
fi

# Linux: idempotent guard
if ! command -v avahi-daemon >/dev/null 2>&1; then
    printf 'Avahi is not installed — nothing to remove.\n'
    exit 0
fi

printf 'Removing Hostname Discovery (Avahi)...\n'

# Stop and disable the service
printf 'Stopping Avahi Daemon...\n'
_maybe_sudo systemctl stop avahi-daemon 2>/dev/null || true
_maybe_sudo systemctl disable avahi-daemon 2>/dev/null || true

# Remove avahi packages
printf 'Removing Avahi packages...\n'
case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_remove avahi-daemon avahi-utils 2>/dev/null || true ;;
    apk)    _pkg_remove avahi avahi-tools 2>/dev/null || true ;;
    dnf)    _pkg_remove avahi avahi-tools 2>/dev/null || true ;;
    pacman) _pkg_remove avahi 2>/dev/null || true ;;
    zypper) _pkg_remove avahi avahi-utils 2>/dev/null || true ;;
    *)      _pkg_remove avahi-daemon 2>/dev/null || true ;;
esac

printf 'Hostname Discovery removed successfully.\n'
