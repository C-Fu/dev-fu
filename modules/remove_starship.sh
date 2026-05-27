#!/usr/bin/env sh
# @name: Remove Starship
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes Starship binary, cleans shell init lines from RC files,
# and removes the starship config directory.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v starship >/dev/null 2>&1; then
    printf 'Starship is not installed\n'
    exit 0
fi

printf 'Removing Starship...\n'

case "${FLU_OS:-$(uname -s)}" in
    darwin|Darwin)
        brew uninstall starship 2>/dev/null || true
        ;;
    linux|Linux)
        _maybe_sudo rm -f /usr/local/bin/starship
        ;;
esac

for _sr_rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    [ -f "$_sr_rcfile" ] || continue
    sed -i.bak '/starship init/d' "$_sr_rcfile" 2>/dev/null || true
    sed -i.bak '/# Starship/d' "$_sr_rcfile" 2>/dev/null || true
    rm -f "${_sr_rcfile}.bak" 2>/dev/null || true
done

rm -rf "$HOME/.config/starship" 2>/dev/null || true

printf 'Starship removed successfully. Shell integration lines cleaned from RC files.\n'
