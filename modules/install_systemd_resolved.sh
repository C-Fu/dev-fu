#!/usr/bin/env sh
# @name: Systemd-Resolved (LLMNR)
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Installs and enables systemd-resolved for LLMNR/DNS hostname discovery on Linux.
# Requires systemd.

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

_pkg_install() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get install -y "$@" ;;
        apk)    _maybe_sudo apk add "$@" ;;
        dnf)    _maybe_sudo dnf install -y "$@" ;;
        pacman) _maybe_sudo pacman -S --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper install -y "$@" ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

_pkg_update() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get update ;;
        apk)    _maybe_sudo apk update ;;
        dnf)    _maybe_sudo dnf check-update || true ;;
        pacman) _maybe_sudo pacman -Sy ;;
        zypper) _maybe_sudo zypper refresh ;;
    esac
}

if [ "${FLU_OS:-linux}" = "darwin" ]; then
    printf 'macOS uses mDNSResponder for hostname discovery — systemd-resolved is not applicable.\n'
    exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemd-resolved requires systemd and is not available on this system.\n' >&2
    exit 0
fi

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    printf 'systemd-resolved is already running\n'
    printf 'LLMNR hostname resolution is active\n'
    exit 0
fi

if [ -f /usr/lib/systemd/systemd-resolved ]; then
    printf 'systemd-resolved is installed but not running — enabling...\n'
    _maybe_sudo systemctl enable --now systemd-resolved 2>/dev/null || true
    printf 'systemd-resolved enabled\n'
    exit 0
fi

printf 'Installing systemd-resolved...\n'
_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_install systemd-resolved || { printf 'Install failed\n' >&2; exit 1; } ;;
    apk)    printf 'Alpine does not use systemd-resolved\n'; exit 0 ;;
    dnf)    _pkg_install systemd-resolved || { printf 'Install failed\n' >&2; exit 1; } ;;
    pacman) _pkg_install systemd-resolved || { printf 'Install failed\n' >&2; exit 1; } ;;
    zypper) _pkg_install systemd-resolved || { printf 'Install failed\n' >&2; exit 1; } ;;
    *)      _pkg_install systemd-resolved || { printf 'Install failed\n' >&2; exit 1; } ;;
esac

_maybe_sudo systemctl enable --now systemd-resolved 2>/dev/null || printf 'Warning: could not enable systemd-resolved\n' >&2

printf 'systemd-resolved installed and enabled.\n'
printf 'LLMNR hostname resolution is now active.\n'
