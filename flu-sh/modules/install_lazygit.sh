#!/usr/bin/env sh
# @name: Install lazygit
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs lazygit (TUI git client) via GitHub releases.
# Downloads pre-built Go binary to /usr/local/bin.

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

if command -v lazygit >/dev/null 2>&1; then
    printf 'lazygit already installed: %s\n' "$(lazygit --version 2>/dev/null | head -1)"
    exit 0
fi

printf 'Installing lazygit...\n'

_lg_arch=$(uname -m)
case "$_lg_arch" in
    x86_64)  _lg_arch="x86_64" ;;
    aarch64) _lg_arch="arm64" ;;
    armv7l)  _lg_arch="armv7" ;;
    *)       printf 'Unsupported architecture: %s\n' "$_lg_arch" >&2; exit 1 ;;
esac

_lg_platform=$(uname -s)
case "$_lg_platform" in
    Linux)  _lg_platform="Linux" ;;
    Darwin) _lg_platform="Darwin" ;;
    *)      printf 'Unsupported platform: %s\n' "$_lg_platform" >&2; exit 1 ;;
esac

_lg_url="https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${_lg_platform}_${_lg_arch}.tar.gz"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o /tmp/lazygit.tar.gz "$_lg_url"
else
    wget -qO /tmp/lazygit.tar.gz "$_lg_url"
fi

tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
_maybe_sudo mv /tmp/lazygit /usr/local/bin/lazygit
_maybe_sudo chmod +x /usr/local/bin/lazygit
rm -f /tmp/lazygit.tar.gz

printf 'lazygit installed successfully\n'
