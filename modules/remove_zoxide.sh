#!/usr/bin/env sh
# @name: Remove zoxide
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes zoxide binary, cleans shell init lines from RC files,
# and removes the zoxide data directory.

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

if ! command -v zoxide >/dev/null 2>&1; then
    printf 'zoxide is not installed\n'
    exit 0
fi

printf 'Removing zoxide...\n'

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        brew uninstall zoxide 2>/dev/null || true
        ;;
    linux|Linux)
        _maybe_sudo rm -f /usr/local/bin/zoxide
        ;;
esac

for _zr_rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    [ -f "$_zr_rcfile" ] || continue
    sed -i.bak '/zoxide init/d' "$_zr_rcfile" 2>/dev/null || true
    rm -f "${_zr_rcfile}.bak" 2>/dev/null || true
done

rm -rf "$HOME/.local/share/zoxide" 2>/dev/null || true

printf 'zoxide removed successfully. Shell integration lines cleaned from RC files.\n'
