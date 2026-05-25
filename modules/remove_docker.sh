#!/usr/bin/env sh
# @name: Remove Docker
# @params:
# @platforms: linux
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Docker completely — stops service, purges packages,
# removes data directories, and removes user from docker group.

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

if ! command -v docker >/dev/null 2>&1; then
    printf 'Docker is not installed\n'
    exit 0
fi

printf 'Removing Docker...\n'

# Stop docker service
if command -v systemctl >/dev/null 2>&1; then
    _maybe_sudo systemctl stop docker 2>/dev/null || true
    _maybe_sudo systemctl disable docker 2>/dev/null || true
fi
if command -v rc-service >/dev/null 2>&1; then
    _maybe_sudo rc-service docker stop 2>/dev/null || true
fi

# Remove docker packages
case "${FLU_PKG_MGR:-apt}" in
    apk)
        _pkg_remove docker docker-cli-compose 2>/dev/null || true
        ;;
    apt)
        _maybe_sudo apt-get purge -y docker.io docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
        _maybe_sudo apt-get autoremove -y 2>/dev/null || true
        ;;
    *)
        _pkg_remove docker docker-ce docker-ce-cli containerd.io 2>/dev/null || true
        ;;
esac

# Remove docker data and config
_maybe_sudo rm -rf /var/lib/docker /etc/docker 2>/dev/null || true
_maybe_sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true

# Remove user from docker group
if [ "${FLU_IS_ROOT:-0}" != "1" ] && [ -n "${USER:-}" ]; then
    if getent group docker >/dev/null 2>&1; then
        _maybe_sudo gpasswd -d "$USER" docker 2>/dev/null || true
    fi
fi

printf 'Docker removed successfully\n'
