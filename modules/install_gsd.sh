#!/usr/bin/env sh
# @name: Install GSD (Rokicool)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
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

if command -v gsd-opencode >/dev/null 2>&1; then
    _ver=$(gsd-opencode --version 2>/dev/null | head -1 || printf 'installed')
    printf 'GSD (Rokicool) already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g gsd-opencode 2>/dev/null || true
elif npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
    printf 'GSD (Rokicool) already available (via npx)\n'
else
    printf 'Installing GSD (Rokicool)...\n'
    if npx --yes gsd-opencode@latest 2>/dev/null || npm install -g gsd-opencode 2>/dev/null; then
        printf 'GSD (Rokicool) installed successfully\n'
    else
        printf 'GSD (Rokicool) install failed\n' >&2
        exit 1
    fi
fi
