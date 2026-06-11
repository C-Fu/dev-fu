#!/usr/bin/env sh
# @name: Install eza
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs eza (modern ls replacement) via package manager or cargo fallback.

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

if command -v eza >/dev/null 2>&1; then
    printf 'eza already installed: %s\n' "$(eza --version 2>/dev/null | head -1)"
    exit 0
fi

printf 'Installing eza...\n'

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        brew install eza
        ;;
    linux|Linux)
        _eza_pkg_ok=0
        case "${FLU_PKG_MGR:-}" in
            apt)
                _maybe_sudo mkdir -p /etc/apt/keyrings
                _eza_gpg_url="https://raw.githubusercontent.com/eza-community/eza/main/deb.asc"
                if command -v curl >/dev/null 2>&1; then
                    curl -fsSL "$_eza_gpg_url" | _maybe_sudo tee /etc/apt/keyrings/eza.asc >/dev/null
                else
                    wget -qO- "$_eza_gpg_url" | _maybe_sudo tee /etc/apt/keyrings/eza.asc >/dev/null
                fi
                printf 'deb [signed-by=/etc/apt/keyrings/eza.asc] https://deb.gierens.de stable main\n' | _maybe_sudo tee /etc/apt/sources.list.d/eza.list >/dev/null
                _maybe_sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/eza.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
                _pkg_install eza && _eza_pkg_ok=1
                ;;
            pacman)
                _pkg_install eza && _eza_pkg_ok=1
                ;;
            zypper)
                _pkg_install eza && _eza_pkg_ok=1
                ;;
            dnf)
                _pkg_install eza && _eza_pkg_ok=1
                ;;
        esac

        if [ "$_eza_pkg_ok" = "0" ]; then
            if ! command -v cargo >/dev/null 2>&1; then
                printf 'eza requires Rust/cargo for installation on this system. Install Rust first via the menu.\n' >&2
                exit 1
            fi
            printf 'Package manager install unavailable, falling back to cargo...\n'
            cargo install eza
        fi
        ;;
    *)
        printf 'Visit https://github.com/eza-community/eza for manual install\n' >&2
        exit 1
        ;;
esac

printf 'eza installed successfully\n'
