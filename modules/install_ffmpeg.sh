#!/usr/bin/env sh
# @name: Install FFmpeg
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Installs FFmpeg via the system package manager.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v ffmpeg >/dev/null 2>&1; then
    printf 'FFmpeg already installed: %s\n' "$(ffmpeg -version 2>/dev/null | head -1)"
    exit 0
fi

case "${FLU_PKG_MGR:-}" in
    apt)    _maybe_sudo apt-get update && _maybe_sudo apt-get install -y ffmpeg ;;
    apk)    _maybe_sudo apk add ffmpeg ;;
    dnf)    _maybe_sudo dnf install -y ffmpeg ;;
    pacman) _maybe_sudo pacman -S --noconfirm ffmpeg ;;
    zypper) _maybe_sudo zypper install -y ffmpeg ;;
    brew)   brew install ffmpeg ;;
    *)
        printf 'FFmpeg not available for package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
        exit 1
        ;;
esac || { printf 'FFmpeg install failed\n' >&2; exit 1; }

printf 'FFmpeg installed successfully\n'
