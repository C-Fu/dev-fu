#!/usr/bin/env sh
# @name: Install Bun
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Bun (fast JavaScript runtime & package manager) via the official installer.

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

if command -v bun >/dev/null 2>&1; then
    printf 'Bun already installed: %s\n' "$(bun --version)"
    exit 0
fi

printf 'Installing Bun...\n'

if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh || { printf 'Bun download failed\n' >&2; exit 1; }
elif command -v wget >/dev/null 2>&1; then
    wget -qO /tmp/bun-install.sh https://bun.sh/install || { printf 'Bun download failed\n' >&2; exit 1; }
else
    printf 'No download tool available (curl or wget required)\n' >&2
    exit 1
fi

bash /tmp/bun-install.sh || { rm -f /tmp/bun-install.sh; printf 'Bun install failed\n' >&2; exit 1; }
rm -f /tmp/bun-install.sh

# Add bun to PATH for current session
if [ -d "$HOME/.bun/bin" ]; then
    export PATH="$HOME/.bun/bin:$PATH"
fi

printf 'Bun installed successfully\n'
