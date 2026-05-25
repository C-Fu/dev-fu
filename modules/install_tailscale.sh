#!/usr/bin/env sh
# @name: Install Tailscale
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Tailscale (mesh VPN) via the official installer script.

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

if command -v tailscale >/dev/null 2>&1; then
    printf 'Tailscale already installed: %s\n' "$(tailscale version 2>/dev/null | head -1)"
    exit 0
fi

printf 'Installing Tailscale...\n'

if [ "${FLU_OS:-}" = "darwin" ]; then
    # macOS: use Homebrew
    if command -v brew >/dev/null 2>&1; then
        brew install tailscale || { printf 'Tailscale install failed\n' >&2; exit 1; }
    else
        printf 'Homebrew required for Tailscale on macOS\n' >&2
        exit 1
    fi
elif [ "${FLU_OS:-}" = "linux" ] || [ -z "${FLU_OS:-}" ]; then
    # Linux: use official curl-pipe installer
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh || { printf 'Tailscale install failed\n' >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://tailscale.com/install.sh | sh || { printf 'Tailscale install failed\n' >&2; exit 1; }
    else
        printf 'No download tool available (curl or wget required)\n' >&2
        exit 1
    fi
else
    printf 'Automatic install not supported on this OS\n' >&2
    printf 'Visit: https://tailscale.com/download\n' >&2
    exit 1
fi

printf 'Tailscale installed successfully\n'
printf 'Run "tailscale up" to connect, or "tailscale login" to authenticate\n'
