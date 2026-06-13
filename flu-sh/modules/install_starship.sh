#!/usr/bin/env sh
# @name: Install Starship
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Starship (cross-shell prompt) via the official installer.
# Adds shell init lines to .bashrc and .zshrc.

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

if command -v starship >/dev/null 2>&1; then
    printf 'Starship already installed: %s\n' "$(starship --version 2>/dev/null | head -1)"
    exit 0
fi

printf 'Installing Starship...\n'

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        if command -v brew >/dev/null 2>&1; then
            brew install starship
        else
            printf 'Homebrew required for Starship on macOS\n' >&2
            exit 1
        fi
        ;;
    linux|Linux)
        if command -v curl >/dev/null 2>&1; then
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        elif command -v wget >/dev/null 2>&1; then
            wget -qO- https://starship.rs/install.sh | sh -s -- -y
        else
            printf 'curl or wget required\n' >&2
            exit 1
        fi
        ;;
    *)
        printf 'Visit https://starship.rs for manual install\n' >&2
        exit 1
        ;;
esac

for _ss_rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$_ss_rcfile" ] || continue
    if ! grep -q 'starship init' "$_ss_rcfile" 2>/dev/null; then
        case "$_ss_rcfile" in
            *.bashrc) printf '\neval "$(starship init bash)"\n' >> "$_ss_rcfile" ;;
            *.zshrc)  printf '\neval "$(starship init zsh)"\n' >> "$_ss_rcfile" ;;
        esac
    fi
done

_ss_fish_config="$HOME/.config/fish/config.fish"
if [ -f "$_ss_fish_config" ]; then
    if ! grep -q 'starship init' "$_ss_fish_config" 2>/dev/null; then
        printf '\nstarship init fish | source\n' >> "$_ss_fish_config"
    fi
fi

printf 'Starship installed. Restart your shell or source your RC file to activate.\n'
