#!/usr/bin/env sh
# @name: Remove NVM + Node
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 300
#
# Removes NVM (Node Version Manager) and all installed Node.js versions.
# Cleans shell rc files of NVM initialization lines.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

# Auto-detect package manager when not provided by flu.sh (for musl path)
if [ -z "${FLU_PKG_MGR:-}" ]; then
    if      command -v apt-get >/dev/null 2>&1; then FLU_PKG_MGR="apt"
    elif    command -v apk     >/dev/null 2>&1; then FLU_PKG_MGR="apk"
    elif    command -v dnf     >/dev/null 2>&1; then FLU_PKG_MGR="dnf"
    elif    command -v pacman  >/dev/null 2>&1; then FLU_PKG_MGR="pacman"
    elif    command -v zypper  >/dev/null 2>&1; then FLU_PKG_MGR="zypper"
    elif    command -v brew    >/dev/null 2>&1; then FLU_PKG_MGR="brew"
    fi
fi

_pkg_remove() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get remove -y "$@" ;;
        apk)    _maybe_sudo apk del "$@" ;;
        dnf)    _maybe_sudo dnf remove -y "$@" ;;
        pacman) _maybe_sudo pacman -R --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper remove -y "$@" ;;
        brew)   brew uninstall "$@" || true ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

# musl (Alpine) path: Node was installed via apk
_is_musl() {
    command -v apk >/dev/null 2>&1
}

if _is_musl; then
    if ! command -v node >/dev/null 2>&1; then
        printf 'Node.js is not installed\n'
        exit 0
    fi
    _pkg_remove nodejs npm 2>/dev/null || true
    printf 'Node.js removed successfully\n'
    exit 0
fi

# glibc path: NVM
if ! test -d "$HOME/.nvm"; then
    printf 'NVM is not installed\n'
    exit 0
fi

printf 'Removing NVM + Node...\n'

# Source NVM and uninstall LTS if possible
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    . "$HOME/.nvm/nvm.sh" 2>/dev/null || true
    nvm uninstall --lts 2>/dev/null || true
fi

# Remove NVM directory
rm -rf "$HOME/.nvm"

# Remove NVM init lines from shell rc files
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rcfile" ]; then
        sed -i.bak '/NVM_DIR\|nvm\.sh\|nvm\.bash_completion/d' "$rcfile" 2>/dev/null || true
        rm -f "${rcfile}.bak" 2>/dev/null || true
    fi
done

printf 'NVM + Node removed successfully\n'
