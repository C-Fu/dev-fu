#!/usr/bin/env sh
# @name: Remove OpenJDK
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Removes OpenJDK via system package manager.

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

_pkg_remove() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get remove -y "$@" ;;
        apk)    _maybe_sudo apk del "$@" ;;
        dnf)    _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -Rns --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew)   brew uninstall "$@" ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

if ! command -v java >/dev/null 2>&1; then
    printf 'OpenJDK is not installed — nothing to remove.\n'
    exit 0
fi

printf 'Removing OpenJDK...\n'

case "${FLU_PKG_MGR:-apt}" in
    apt)    _maybe_sudo apt-get remove -y default-jdk default-jre 2>/dev/null || true ;;
    apk)    _pkg_remove openjdk21 2>/dev/null || true ;;
    dnf)    _pkg_remove java-21-openjdk-devel 2>/dev/null || true ;;
    pacman) _pkg_remove jdk-openjdk 2>/dev/null || true ;;
    zypper) _pkg_remove java-21-openjdk-devel 2>/dev/null || true ;;
    brew)   _pkg_remove openjdk 2>/dev/null || true ;;
    *)      _pkg_remove default-jdk 2>/dev/null || true ;;
esac

printf 'OpenJDK removed successfully.\n'
