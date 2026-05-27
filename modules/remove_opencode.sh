#!/usr/bin/env sh
# @name: Remove OpenCode
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 120
#
# Removes OpenCode via npm.

set -eu

if ! command -v npm >/dev/null 2>&1; then
    printf 'npm not found. Nothing to remove.\n' >&2
    exit 1
fi

if npm list -g opencode-ai >/dev/null 2>&1; then
    printf 'Removing OpenCode...\n'
    npm uninstall -g opencode-ai 2>/dev/null || { printf 'Failed to remove OpenCode\n' >&2; exit 1; }
    printf 'OpenCode removed successfully\n'
else
    printf 'OpenCode is not installed.\n'
fi
