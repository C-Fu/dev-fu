#!/usr/bin/env sh
# @name: Avahi Daemon (mDNS)
# @params:
# @platforms: linux, darwin
# @version: 1.1.0
# @deps:
# @timeout: 120
#
# Installs Avahi Daemon for mDNS hostname discovery on Linux.
# On macOS, Bonjour (mDNSResponder) provides this built-in — no-op.
# Requires systemd on Linux.

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

_pkg_install() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get install -y "$@" ;;
        apk)    _maybe_sudo apk add "$@" ;;
        dnf)    _maybe_sudo dnf install -y "$@" ;;
        pacman) _maybe_sudo pacman -S --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper install -y "$@" ;;
        brew)   brew install "$@" ;;
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
        brew)   brew update ;;
    esac
}

# macOS: Bonjour is built-in
if [ "${FLU_OS:-linux}" = "darwin" ]; then
    printf 'Hostname Discovery is built into macOS (Bonjour / mDNSResponder).\n'
    printf 'No installation needed — "hostname.local" resolution is already active.\n'
    exit 0
fi

# Linux: check for systemd requirement
if ! command -v systemctl >/dev/null 2>&1; then
    printf 'Hostname Discovery requires systemd and is not available on this system.\n' >&2
    exit 0
fi

# Idempotent guard: check if already installed
if command -v avahi-daemon >/dev/null 2>&1; then
    printf 'Avahi Daemon is already installed\n'
    avahi_daemon_ver=$(avahi-daemon --version 2>/dev/null | head -1 || printf 'installed')
    printf 'Version: %s\n' "${avahi_daemon_ver}"

    # Ensure it's running
    if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
        printf 'Avahi Daemon is running\n'
    else
        printf 'Avahi Daemon is not running — starting...\n'
        _maybe_sudo systemctl enable --now avahi-daemon 2>/dev/null || true
    fi
    printf 'Hostname Discovery: use hostname.local to reach this machine\n'
    exit 0
fi

# Proceed with installation
printf 'Installing Hostname Discovery (Avahi)...\n'
printf 'This will install: avahi-daemon\n'

# Update package lists
_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

# Install avahi packages — package names vary by distro
case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_install avahi-daemon avahi-utils || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
    apk)    _pkg_install avahi avahi-tools || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
    dnf)    _pkg_install avahi avahi-tools || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
    pacman) _pkg_install avahi || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
    zypper) _pkg_install avahi avahi-utils || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
    *)      _pkg_install avahi-daemon || { printf 'Avahi install failed\n' >&2; exit 1; } ;;
esac

# Enable and start the service
printf 'Enabling and starting Avahi Daemon...\n'
_maybe_sudo systemctl enable --now avahi-daemon 2>/dev/null || printf 'Warning: could not enable avahi-daemon\n' >&2

printf 'Hostname Discovery installed successfully.\n'
printf 'Use: hostname.local to reach this machine from other devices on the network.\n'
