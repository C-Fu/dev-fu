#!/usr/bin/env sh
# @name: Install NVM + Node LTS
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs NVM (Node Version Manager) and the latest Node.js LTS.
# On musl-based systems (Alpine), installs Node via apk instead.

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

# musl check
_is_musl() {
    command -v apk >/dev/null 2>&1
}

# ─── musl (Alpine) path: install Node via apk ───
if _is_musl; then
    if command -v node >/dev/null 2>&1; then
        printf 'Node.js already installed: %s\n' "$(node --version)"
        exit 0
    fi

    _pkg_update || { printf 'Package update failed\n' >&2; exit 1; }
    _pkg_install nodejs npm || { printf 'Node.js install failed\n' >&2; exit 1; }

    printf 'Node.js %s installed successfully\n' "$(node --version)"
    exit 0
fi

# ─── glibc path: install NVM + Node LTS ───

# Source NVM if already installed
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

if command -v nvm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    printf 'NVM + Node already installed: %s\n' "$(node --version)"
    exit 0
fi

# Install NVM
if ! command -v nvm >/dev/null 2>&1; then
    printf 'Installing NVM...\n'
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o /tmp/nvm-install.sh || { printf 'NVM download failed\n' >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh || { printf 'NVM download failed\n' >&2; exit 1; }
    else
        printf 'No download tool available (curl or wget required)\n' >&2
        exit 1
    fi

    bash /tmp/nvm-install.sh || { rm -f /tmp/nvm-install.sh; printf 'NVM install failed\n' >&2; exit 1; }
    rm -f /tmp/nvm-install.sh

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

# Install Node LTS
if ! command -v node >/dev/null 2>&1; then
    printf 'Installing Node.js LTS...\n'
    nvm install --lts || { printf 'Node LTS install failed\n' >&2; exit 1; }
    nvm use --lts 2>/dev/null || true
fi

printf 'NVM + Node LTS installed successfully\n'
