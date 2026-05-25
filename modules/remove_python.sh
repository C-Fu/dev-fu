#!/usr/bin/env sh
# @name: Remove Python
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Python 3, pip, pipx, and uv via the system package manager.

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
        pacman) _maybe_sudo pacman -R --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew)   brew uninstall "$@" || true ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python is not installed\n'
    exit 0
fi

printf 'Removing Python + pip + pipx + uv...\n'

# Remove Python and pip
case "${FLU_PKG_MGR:-apt}" in
    apk)
        _pkg_remove python3 py3-pip py3-pipx 2>/dev/null || true
        ;;
    brew)
        brew uninstall python3 2>/dev/null || true
        brew uninstall pipx 2>/dev/null || true
        ;;
    *)
        _pkg_remove python3 python3-pip python3-venv pipx 2>/dev/null || true
        ;;
esac

# Remove uv
if command -v pipx >/dev/null 2>&1; then
    pipx uninstall uv 2>/dev/null || true
fi
if command -v pip3 >/dev/null 2>&1; then
    pip3 uninstall -y uv 2>/dev/null || true
fi
rm -rf "$HOME/.local/bin/uv" "$HOME/.local/share/uv" 2>/dev/null || true

printf 'Python + pip + pipx + uv removed successfully\n'
