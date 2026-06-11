#!/usr/bin/env sh
# @name: Install Docker
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Docker (containerization platform) via the system package manager
# or the official get.docker.com script. Linux only.

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

if command -v docker >/dev/null 2>&1; then
    printf 'Docker already installed: %s\n' "$(docker --version | cut -d, -f1)"
    exit 0
fi

# Docker is Linux only
if [ "${FLU_OS:-}" = "darwin" ]; then
    printf 'Docker Desktop must be installed manually on macOS\n' >&2
    printf 'Visit: https://docs.docker.com/desktop/setup/install/mac-install/\n' >&2
    exit 1
fi

_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

printf 'Installing Docker...\n'

# Alpine: install docker + docker-compose via apk
if [ "${FLU_PKG_MGR:-}" = "apk" ]; then
    _pkg_install docker docker-cli-compose || { printf 'Docker install failed\n' >&2; exit 1; }
    _maybe_sudo rc-update add docker boot 2>/dev/null || true
    _maybe_sudo service docker start 2>/dev/null || true
else
    # Use official Docker install script for other distros
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh || { printf 'Docker download failed\n' >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/get-docker.sh https://get.docker.com || { printf 'Docker download failed\n' >&2; exit 1; }
    else
        printf 'No download tool available (curl or wget required)\n' >&2
        exit 1
    fi
    _maybe_sudo sh /tmp/get-docker.sh || { rm -f /tmp/get-docker.sh; printf 'Docker install failed\n' >&2; exit 1; }
    rm -f /tmp/get-docker.sh
fi

# Enable and start docker service
if command -v systemctl >/dev/null 2>&1; then
    _maybe_sudo systemctl enable docker 2>/dev/null || true
    _maybe_sudo systemctl start docker 2>/dev/null || true
fi

# Add user to docker group for passwordless access
if [ "${FLU_IS_ROOT:-0}" != "1" ] && [ -n "${USER:-}" ]; then
    if getent group docker >/dev/null 2>&1; then
        _maybe_sudo usermod -aG docker "$USER" 2>/dev/null || true
        printf 'Note: log out and back in for docker group membership to take effect\n'
    fi
fi

printf 'Docker installed successfully\n'
