#!/usr/bin/env sh
# @name: Install Python
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Python 3, pip, pipx, and uv (fast Python package manager).
# Detected platform info is provided via FLU_* environment variables.

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

_install_uv() {
    command -v uv >/dev/null 2>&1 && return 0

    printf 'Installing uv...\n'

    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh 2>/dev/null
        if [ -f /tmp/uv-install.sh ]; then
            sh /tmp/uv-install.sh && rm -f /tmp/uv-install.sh && return 0
            rm -f /tmp/uv-install.sh
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/uv-install.sh https://astral.sh/uv/install.sh 2>/dev/null
        if [ -f /tmp/uv-install.sh ]; then
            sh /tmp/uv-install.sh && rm -f /tmp/uv-install.sh && return 0
            rm -f /tmp/uv-install.sh
        fi
    fi

    if command -v pipx >/dev/null 2>&1; then
        pipx install uv 2>/dev/null && return 0
    fi

    if command -v pip3 >/dev/null 2>&1; then
        pip3 install uv 2>/dev/null && return 0
    elif command -v pip >/dev/null 2>&1; then
        pip install uv 2>/dev/null && return 0
    fi

    if command -v brew >/dev/null 2>&1; then
        brew install uv 2>/dev/null && return 0
    fi

    printf 'uv install failed — no supported install method available\n' >&2
    return 1
}

# Check if already installed
NEED_PYTHON=0
NEED_PIPX=0
NEED_UV=0
command -v python3 >/dev/null 2>&1 || NEED_PYTHON=1
command -v pipx >/dev/null 2>&1 || NEED_PIPX=1
command -v uv >/dev/null 2>&1 || NEED_UV=1

if [ "$NEED_PYTHON" = "0" ] && [ "$NEED_PIPX" = "0" ] && [ "$NEED_UV" = "0" ]; then
    printf 'Python + pip + pipx + uv already installed\n'
    exit 0
fi

# Update package lists
_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

# Install Python and pip
if [ "$NEED_PYTHON" = "1" ]; then
    printf 'Installing Python + pip...\n'
    if [ "${FLU_PKG_MGR:-}" = "apk" ]; then
        _pkg_install python3 py3-pip || { printf 'Python install failed\n' >&2; exit 1; }
    else
        _pkg_install python3 python3-pip python3-venv || { printf 'Python install failed\n' >&2; exit 1; }
    fi
fi

# Install pipx
if [ "$NEED_PIPX" = "1" ]; then
    printf 'Installing pipx...\n'
    if [ "${FLU_PKG_MGR:-}" = "apk" ]; then
        _pkg_install py3-pipx || { printf 'pipx install failed\n' >&2; exit 1; }
    else
        _pkg_install pipx || { printf 'pipx install failed\n' >&2; exit 1; }
    fi
fi

# Install uv
if [ "$NEED_UV" = "1" ]; then
    _install_uv || { printf 'uv install failed\n' >&2; exit 1; }
fi

printf 'Python + pip + pipx + uv installed successfully\n'
