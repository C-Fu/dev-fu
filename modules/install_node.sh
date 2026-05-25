#!/usr/bin/env sh
# @name: Install Node.js
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,bash
# @timeout: 600
#
# Installs NVM + Node.js LTS on standard systems.
# Uses native apk packages on Alpine/musl (NVM incompatible with musl libc).

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

_is_musl() {
    [ "${FLU_PKG_MGR:-}" = "apk" ]
}

# Alpine/musl path — native package install
if _is_musl; then
    if command -v node >/dev/null 2>&1; then
        printf 'Node.js already installed: %s\n' "$(node --version)"
        exit 0
    fi

    printf 'Installing Node.js via apk...\n'
    _pkg_install nodejs npm || { printf 'Node.js install failed\n' >&2; exit 1; }
    printf 'Node.js %s installed successfully\n' "$(node --version)"
    exit 0
fi

# Standard path — NVM + Node LTS
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

if command -v nvm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    printf 'NVM + Node already installed: %s\n' "$(node --version)"
    exit 0
fi

if ! command -v nvm >/dev/null 2>&1; then
    printf 'Installing NVM...\n'
    NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$NVM_URL" -o /tmp/nvm-install.sh || { printf 'NVM download failed\n' >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/nvm-install.sh "$NVM_URL" || { printf 'NVM download failed\n' >&2; exit 1; }
    else
        printf 'curl or wget required to download NVM\n' >&2; exit 1
    fi
    bash /tmp/nvm-install.sh || { printf 'NVM install failed\n' >&2; exit 1; }
    rm -f /tmp/nvm-install.sh
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

if ! command -v node >/dev/null 2>&1; then
    printf 'Installing Node.js LTS...\n'
    nvm install --lts || { printf 'Node LTS install failed\n' >&2; exit 1; }
fi

printf 'NVM + Node LTS installed successfully\n'
