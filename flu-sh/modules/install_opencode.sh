#!/usr/bin/env sh
# @name: Install OpenCode
# @params:
# @platforms: linux, darwin
# @version: 1.2.0
# @deps: curl or npm
# @timeout: 300
#
# Installs OpenCode via the official installer (preferred).
# Falls back to npm if the official installer is unavailable or fails.
# The npm opencode-ai wrapper has a buggy postinstall on some ARM64 Linux
# systems (e.g. Raspberry Pi OS with glibc), so the official installer is
# used as the primary path.

set -eu

_OFFICIAL_BIN="$HOME/.opencode/bin/opencode"

_is_installed() {
    if [ -x "$_OFFICIAL_BIN" ] && "$_OFFICIAL_BIN" --version >/dev/null 2>&1; then
        return 0
    fi
    if command -v opencode >/dev/null 2>&1 && opencode --version >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

_get_version() {
    if [ -x "$_OFFICIAL_BIN" ]; then
        "$_OFFICIAL_BIN" --version 2>/dev/null || printf 'installed'
    elif command -v opencode >/dev/null 2>&1; then
        opencode --version 2>/dev/null || printf 'installed'
    else
        printf 'installed'
    fi
}

_install_via_official() {
    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi
    printf 'Installing OpenCode via official installer...\n'
    curl -fsSL https://opencode.ai/install | sh || return 1
    [ -x "$_OFFICIAL_BIN" ] && "$_OFFICIAL_BIN" --version >/dev/null 2>&1
}

_install_via_npm() {
    if ! command -v npm >/dev/null 2>&1 || ! npm --version >/dev/null 2>&1; then
        return 1
    fi
    printf 'Installing OpenCode via npm...\n'
    npm install -g opencode-ai || return 1
    command -v opencode >/dev/null 2>&1 && opencode --version >/dev/null 2>&1
}

if _is_installed; then
    _ver=$(_get_version)
    printf 'OpenCode already installed [%s]\n' "$_ver"
    printf 'Updating via official installer...\n'
    if _install_via_official; then
        printf 'OpenCode updated successfully\n'
        exit 0
    fi
    printf 'Official installer update failed, trying npm...\n'
    if _install_via_npm; then
        printf 'OpenCode updated successfully\n'
        exit 0
    fi
    printf 'OpenCode update failed\n' >&2
    exit 1
fi

if _install_via_official; then
    printf 'OpenCode installed successfully\n'
    exit 0
fi

printf 'Official installer failed, trying npm...\n'
if _install_via_npm; then
    printf 'OpenCode installed successfully\n'
    exit 0
fi

printf 'OpenCode install failed\n' >&2
exit 1
