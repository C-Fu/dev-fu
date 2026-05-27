#!/usr/bin/env sh
# @name: Remove lazygit
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes lazygit by deleting the binary and state directory.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v lazygit >/dev/null 2>&1; then
    printf 'lazygit is not installed\n'
    exit 0
fi

printf 'Removing lazygit...\n'
_maybe_sudo rm -f /usr/local/bin/lazygit
rm -rf "$HOME/.local/state/lazygit" 2>/dev/null || true

printf 'lazygit removed successfully\n'
