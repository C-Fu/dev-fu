#!/usr/bin/env sh
# @name: Remove PHP + Laravel
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes PHP, Composer, and the Laravel installer.
# PHP via package manager, Laravel via Composer global remove.

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

if ! command -v php >/dev/null 2>&1; then
    printf 'PHP is not installed\n'
    exit 0
fi

printf 'Removing PHP + Laravel...\n'

# Remove Laravel installer via Composer
if command -v composer >/dev/null 2>&1; then
    composer global remove laravel/installer 2>/dev/null || true
fi

# Clean Laravel files
rm -rf "$HOME/.composer/vendor/laravel" 2>/dev/null || true
rm -f "$HOME/.composer/vendor/bin/laravel" 2>/dev/null || true

# Remove PHP packages via package manager
case "${FLU_PKG_MGR:-apt}" in
    apt)
        _pkg_remove php-cli php-xml php-mbstring php-curl php-common php-composer 2>/dev/null || true
        _maybe_sudo apt-get autoremove -y 2>/dev/null || true
        ;;
    apk)
        _pkg_remove php81 php81-mbstring php81-xml php81-curl php81-openssl composer 2>/dev/null || true
        ;;
    dnf)
        _pkg_remove php-cli php-xml php-mbstring php-curl php-json 2>/dev/null || true
        ;;
    pacman)
        _pkg_remove php composer 2>/dev/null || true
        ;;
    zypper)
        _pkg_remove php8 php8-mbstring php8-xml php8-curl php8-openssl 2>/dev/null || true
        ;;
    brew)
        brew uninstall php 2>/dev/null || true
        brew uninstall composer 2>/dev/null || true
        ;;
esac

printf 'PHP + Laravel removed successfully\n'
