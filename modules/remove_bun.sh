#!/usr/bin/env sh
# @name: Remove Bun
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Bun by deleting the ~/.bun directory.

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

if ! command -v bun >/dev/null 2>&1; then
    printf 'Bun is not installed\n'
    exit 0
fi

printf 'Removing Bun...\n'

rm -rf "$HOME/.bun"

# Remove bun from shell rc PATH entries
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rcfile" ]; then
        sed -i.bak '/\.bun\/bin/d' "$rcfile" 2>/dev/null || true
        rm -f "${rcfile}.bak" 2>/dev/null || true
    fi
done

printf 'Bun removed successfully\n'
