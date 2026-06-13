#!/usr/bin/env sh
# @name: Remove all Open GSD tools
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: npm
# @timeout: 300
#
# Removes the full Open GSD suite — gsd-core (.planning/), gsd-pi
# (.gsd/), and gsd-browser (npm -g) — in one go. Documentation:
# https://docs.opengsd.net/ Repository: https://github.com/open-gsd

set -eu

_rc=0

printf '\n=== 1/3: gsd-core ===\n'
printf 'gsd-core is invoked per-project via npx — no global install to remove.\n'
if [ -d .planning ]; then
    printf 'Removing .planning/ directory in current project...\n'
    rm -rf .planning
    printf '.planning/ removed successfully\n'
else
    printf 'No .planning/ directory found in current directory.\n'
fi

printf '\n=== 2/3: gsd-pi ===\n'
printf 'gsd-pi is invoked per-project via npx — no global install to remove.\n'
if [ -d .gsd ]; then
    printf 'Removing .gsd/ directory in current project...\n'
    rm -rf .gsd
    printf '.gsd/ removed successfully\n'
else
    printf 'No .gsd/ directory found in current directory.\n'
fi

printf '\n=== 3/3: gsd-browser ===\n'
if command -v npm >/dev/null 2>&1; then
    if npm list -g @opengsd/gsd-browser >/dev/null 2>&1; then
        printf 'Removing gsd-browser...\n'
        if npm uninstall -g @opengsd/gsd-browser 2>/dev/null; then
            printf 'gsd-browser removed successfully\n'
        else
            printf 'gsd-browser removal failed\n' >&2
            _rc=1
        fi
    else
        printf 'gsd-browser is not installed globally.\n'
    fi
else
    printf 'npm not found — skipping gsd-browser removal.\n' >&2
    _rc=1
fi

if [ "$_rc" = "0" ]; then
    printf '\nAll Open GSD tools removed successfully\n'
else
    printf '\nSome Open GSD removals failed — see messages above\n' >&2
fi
exit "$_rc"
