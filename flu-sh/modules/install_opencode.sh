#!/usr/bin/env sh
# @name: Install OpenCode
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 300
#
# Installs OpenCode via npm.
# Requires Node.js and npm to be available on the system.

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required. Install Node.js first.\n' >&2
    exit 1
fi

if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
    _ver=$(opencode --version 2>/dev/null || printf 'installed')
    printf 'OpenCode already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g opencode-ai 2>/dev/null || true
else
    printf 'Installing OpenCode...\n'
    if npm install -g opencode-ai 2>/dev/null; then
        printf 'OpenCode installed successfully\n'
    else
        printf 'OpenCode install failed\n' >&2
        exit 1
    fi
fi
