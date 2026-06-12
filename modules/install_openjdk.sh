#!/usr/bin/env sh
# @name: Install OpenJDK
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Installs OpenJDK (LTS) via system package manager.
# On macOS, installs via Homebrew.

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

if command -v java >/dev/null 2>&1; then
    java_ver=$(java -version 2>&1 | head -1)
    printf 'OpenJDK is already installed: %s\n' "${java_ver}"
    exit 0
fi

printf 'Installing OpenJDK...\n'
_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_install default-jdk || { printf 'Install failed\n' >&2; exit 1; } ;;
    apk)    _pkg_install openjdk21 || { printf 'Install failed\n' >&2; exit 1; } ;;
    dnf)    _pkg_install java-21-openjdk-devel || { printf 'Install failed\n' >&2; exit 1; } ;;
    pacman) _pkg_install jdk-openjdk || { printf 'Install failed\n' >&2; exit 1; } ;;
    zypper) _pkg_install java-21-openjdk-devel || { printf 'Install failed\n' >&2; exit 1; } ;;
    brew)   _pkg_install openjdk || { printf 'Install failed\n' >&2; exit 1; } ;;
    *)      _pkg_install default-jdk || { printf 'Install failed\n' >&2; exit 1; } ;;
esac

java_ver=$(java -version 2>&1 | head -1)
printf 'OpenJDK installed successfully: %s\n' "${java_ver}"
