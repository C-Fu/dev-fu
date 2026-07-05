#!/usr/bin/env sh
# @name: Install GSD (Rokicool)
# @params:
# @platforms: linux, darwin
# @version: 1.2.0
# @deps: npm
# @timeout: 300
#
# Installs GSD (Rokicool) via npm.
# Requires Node.js and npm to be available on the system.
# Also ensures gsd-sdk (bundled with gsd-opencode) is on PATH.

set -eu

LOCAL_BIN="${HOME:-$HOME}/.local/bin"

_ensure_gsd_sdk_on_path() {
    if command -v gsd-sdk >/dev/null 2>&1; then
        return 0
    fi
    _npm_prefix=$(npm prefix -g 2>/dev/null || true)
    if [ -z "$_npm_prefix" ]; then
        return 1
    fi
    _gsd_sdk_src="${_npm_prefix}/bin/gsd-sdk"
    if [ ! -f "$_gsd_sdk_src" ]; then
        return 1
    fi
    mkdir -p "$LOCAL_BIN"
    ln -sf "$_gsd_sdk_src" "${LOCAL_BIN}/gsd-sdk"
    case ":${PATH}:" in
        *":${LOCAL_BIN}:"*) ;;
        *)
            printf '⚠ %s is not in your PATH.\n' "$LOCAL_BIN"
            printf '  Add it with: export PATH="%s:$PATH"\n' "$LOCAL_BIN"
            ;;
    esac
}

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required. Install Node.js first.\n' >&2
    exit 1
fi

if npm list -g gsd-opencode >/dev/null 2>&1; then
    _ver=$(gsd-opencode --version 2>/dev/null | head -1 || printf 'installed')
    printf 'GSD (Rokicool) already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g gsd-opencode || true
    _ensure_gsd_sdk_on_path
else
    printf 'Installing GSD (Rokicool)...\n'
    if npm install -g gsd-opencode; then
        if npm list -g gsd-opencode >/dev/null 2>&1; then
            printf 'GSD (Rokicool) installed successfully\n'
            _ensure_gsd_sdk_on_path
        else
            printf 'GSD (Rokicool) install failed (not found after npm install)\n' >&2
            exit 1
        fi
    else
        printf 'GSD (Rokicool) install failed\n' >&2
        exit 1
    fi
fi
