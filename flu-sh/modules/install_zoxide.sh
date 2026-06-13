#!/usr/bin/env sh
# @name: Install zoxide
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs zoxide (smart cd command with frecency) via GitHub releases.
# Downloads pre-built binary to /usr/local/bin and adds shell init.

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

if command -v zoxide >/dev/null 2>&1; then
    printf 'zoxide already installed: %s\n' "$(zoxide --version 2>/dev/null | head -1)"
    exit 0
fi

printf 'Installing zoxide...\n'

_zo_arch=$(uname -m)
case "$_zo_arch" in
    x86_64)  _zo_arch="x86_64" ;;
    aarch64) _zo_arch="aarch64" ;;
    armv7l)  _zo_arch="armv7" ;;
    *)       printf 'Unsupported architecture: %s\n' "$_zo_arch" >&2; exit 1 ;;
esac

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        if command -v brew >/dev/null 2>&1; then
            brew install zoxide
        else
            printf 'Homebrew required for zoxide on macOS\n' >&2
            exit 1
        fi
        ;;
    linux|Linux)
        _zo_url="https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-${_zo_arch}-unknown-linux-musl.tar.gz"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL -o /tmp/zoxide.tar.gz "$_zo_url"
        else
            wget -qO /tmp/zoxide.tar.gz "$_zo_url"
        fi
        tar -xzf /tmp/zoxide.tar.gz -C /tmp zoxide
        _maybe_sudo mv /tmp/zoxide /usr/local/bin/zoxide
        _maybe_sudo chmod +x /usr/local/bin/zoxide
        rm -f /tmp/zoxide.tar.gz
        ;;
    *)
        printf 'Visit https://github.com/ajeetdsouza/zoxide for manual install\n' >&2
        exit 1
        ;;
esac

for _zo_rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$_zo_rcfile" ] || continue
    if ! grep -q 'zoxide init' "$_zo_rcfile" 2>/dev/null; then
        case "$_zo_rcfile" in
            *.bashrc) printf '\neval "$(zoxide init bash)"\n' >> "$_zo_rcfile" ;;
            *.zshrc)  printf '\neval "$(zoxide init zsh)"\n' >> "$_zo_rcfile" ;;
        esac
    fi
done

_zo_fish_config="$HOME/.config/fish/config.fish"
if [ -f "$_zo_fish_config" ]; then
    if ! grep -q 'zoxide init' "$_zo_fish_config" 2>/dev/null; then
        printf '\nzoxide init fish | source\n' >> "$_zo_fish_config"
    fi
fi

printf 'zoxide installed. Restart your shell or source your RC file to activate.\n'
