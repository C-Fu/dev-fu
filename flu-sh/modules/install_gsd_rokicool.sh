#!/usr/bin/env sh
# @name: Install GSD (Rokicool)
# @params:
# @platforms: linux, darwin
# @version: 1.1.0
# @deps: npm
# @timeout: 300
#
# Installs GSD (Rokicool) via npm.
# Requires Node.js and npm to be available on the system.

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required. Install Node.js first.\n' >&2
    exit 1
fi

if npm list -g gsd-opencode >/dev/null 2>&1; then
    _ver=$(gsd-opencode --version 2>/dev/null | head -1 || printf 'installed')
    printf 'GSD (Rokicool) already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g gsd-opencode || true
else
    printf 'Installing GSD (Rokicool)...\n'
    if npm install -g gsd-opencode; then
        if npm list -g gsd-opencode >/dev/null 2>&1; then
            printf 'GSD (Rokicool) installed successfully\n'
        else
            printf 'GSD (Rokicool) install failed (not found after npm install)\n' >&2
            exit 1
        fi
    else
        printf 'GSD (Rokicool) install failed\n' >&2
        exit 1
    fi
fi
