#!/usr/bin/env sh
# @name: Remove gsd-browser (Open GSD)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 120
#
# Removes gsd-browser (Open GSD) via npm.
# Documentation: https://docs.opengsd.net/

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm not found. Nothing to remove.\n' >&2
    exit 1
fi

if npm list -g @opengsd/gsd-browser >/dev/null 2>&1; then
    printf 'Removing gsd-browser...\n'
    npm uninstall -g @opengsd/gsd-browser 2>/dev/null || { printf 'Failed to remove gsd-browser\n' >&2; exit 1; }
    printf 'gsd-browser removed successfully\n'
else
    printf 'gsd-browser is not installed globally.\n'
fi
