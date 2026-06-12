#!/usr/bin/env sh
# @name: Install OpenChamber
# @params:
# @platforms: linux, darwin
# @version: 1.1.0
# @deps: npm
# @timeout: 300
#
# Installs OpenChamber via npm.
# Requires Node.js and npm to be available on the system.

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required. Install Node.js first.\n' >&2
    exit 1
fi

if command -v openchamber >/dev/null 2>&1 || npm list -g @openchamber/web >/dev/null 2>&1; then
    _ver=$(openchamber --version 2>/dev/null || printf 'installed')
    printf 'OpenChamber already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g @openchamber/web || true
else
    printf 'Installing OpenChamber...\n'
    if npm install -g @openchamber/web; then
        if npm list -g @openchamber/web >/dev/null 2>&1; then
            printf 'OpenChamber installed successfully\n'
        else
            printf 'OpenChamber install failed (not found after npm install)\n' >&2
            exit 1
        fi
    else
        printf 'OpenChamber install failed\n' >&2
        exit 1
    fi
fi
