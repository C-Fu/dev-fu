#!/usr/bin/env sh
# @name: Install Yarn
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 300
#
# Installs Yarn package manager. Uses npm global install as primary method,
# with package manager fallback for systems without npm.

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

if command -v yarn >/dev/null 2>&1; then
    printf 'Yarn already installed: %s\n' "$(yarn --version)"
    exit 0
fi

# Try npm global install first (primary method)
if command -v npm >/dev/null 2>&1; then
    printf 'Installing Yarn via npm...\n'
    npm install -g yarn 2>/dev/null && {
        printf 'Yarn installed successfully\n'
        exit 0
    }
    printf 'npm install failed, trying package manager...\n'
fi

# Fallback to package manager
case "${FLU_PKG_MGR:-apt}" in
    apt)    _pkg_install yarn ;;
    apk)    _pkg_install yarn ;;
    dnf)    _pkg_install yarnpkg ;;
    pacman) _pkg_install yarn ;;
    zypper) _pkg_install yarn ;;
    brew)   brew install yarn ;;
    *)      printf 'No install method available for Yarn\n' >&2; exit 1 ;;
esac

printf 'Yarn installed successfully\n'
