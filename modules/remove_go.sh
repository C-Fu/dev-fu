#!/usr/bin/env sh
# @name: Remove Go
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes the Go programming language via the system package manager.
# Cleans up GOPATH if set.

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

if ! command -v go >/dev/null 2>&1; then
    printf 'Go is not installed\n'
    exit 0
fi

GO_PKG="golang-go"
if [ "${FLU_PKG_MGR:-}" = "apk" ]; then
    GO_PKG="go"
fi

_pkg_remove "$GO_PKG" || { printf 'Go removal failed\n' >&2; exit 1; }

# Clean up GOPATH if set
if [ -n "${GOPATH:-}" ] && [ -d "$GOPATH" ]; then
    printf 'GOPATH directory (%s) remains — remove manually if desired\n' "$GOPATH"
fi

printf 'Go removed successfully\n'
