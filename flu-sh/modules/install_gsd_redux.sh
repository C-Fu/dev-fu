#!/usr/bin/env sh
# @name: Install GSD (Redux)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 300
#
# Installs GSD (Redux) via npx.
# https://github.com/open-gsd/get-shit-done-redux
# Requires Node.js and npm to be available on the system.

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required. Install Node.js first.\n' >&2
    exit 1
fi

printf 'Installing GSD (Redux)...\n'
if npx @opengsd/get-shit-done-redux@latest 2>/dev/null; then
    printf 'GSD (Redux) installed successfully\n'
else
    printf 'GSD (Redux) install failed\n' >&2
    exit 1
fi
